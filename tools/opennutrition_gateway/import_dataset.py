from __future__ import annotations

import argparse
import csv
import hashlib
import io
import ipaddress
import json
import os
import re
import sqlite3
import sys
import tempfile
import unicodedata
import urllib.parse
import zipfile
from pathlib import Path
from typing import Any, Iterable


MAX_ARCHIVE_BYTES = 2 * 1024 * 1024 * 1024
MAX_UNCOMPRESSED_BYTES = 8 * 1024 * 1024 * 1024
MAX_ZIP_ENTRIES = 16
MAX_COMPRESSION_RATIO = 250
MAX_FIELD_BYTES = 1_000_000
MAX_ROWS = 2_000_000
MAX_INVALID_RATIO = 0.35
MIN_UNIQUE_RATIO = 0.50

ALLOWED_IMAGE_HOSTS = {
    "images.openfoodfacts.org",
    "static.openfoodfacts.org",
}

ID_KEYS = ("id", "external_id", "food_id", "uuid")
NAME_KEYS = ("name", "product_name", "food_name", "title")
BRAND_KEYS = ("brand", "brands", "manufacturer")
BARCODE_KEYS = ("barcode", "ean_13", "ean13", "code")
IMAGE_KEYS = ("image_small_url", "image_front_small_url", "image_url")
NUTRITION_JSON_KEYS = (
    "nutrition_100g",
    "nutrition100g",
    "nutrients",
    "nutriments",
    "nutrition",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a read-only OpenNutrition gateway database.",
    )
    parser.add_argument("--zip", required=True, type=Path)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--dataset-version", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--max-rows", type=int, default=MAX_ROWS)
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_zip(path: Path) -> zipfile.ZipInfo:
    if not path.is_file():
        raise ValueError("Archive not found")
    size = path.stat().st_size
    if size <= 0 or size > MAX_ARCHIVE_BYTES:
        raise ValueError("Archive size outside safe range")

    with zipfile.ZipFile(path) as archive:
        infos = archive.infolist()
        if not 1 <= len(infos) <= MAX_ZIP_ENTRIES:
            raise ValueError("Unexpected ZIP entry count")

        total = 0
        tsv_entries: list[zipfile.ZipInfo] = []
        for info in infos:
            normalized = info.filename.replace("\\", "/")
            parts = [part for part in normalized.split("/") if part]
            if (
                normalized.startswith("/")
                or ".." in parts
                or re.match(r"^[A-Za-z]:", normalized)
            ):
                raise ValueError("Unsafe ZIP path")
            mode = (info.external_attr >> 16) & 0xF000
            if mode == 0xA000:
                raise ValueError("Symlinks are not allowed")
            total += info.file_size
            if total > MAX_UNCOMPRESSED_BYTES:
                raise ValueError("Uncompressed data limit exceeded")
            if info.compress_size > 0:
                ratio = info.file_size / info.compress_size
                if ratio > MAX_COMPRESSION_RATIO:
                    raise ValueError("Suspicious compression ratio")
            if info.filename.lower().endswith(".tsv") and not info.is_dir():
                tsv_entries.append(info)

        if len(tsv_entries) != 1:
            raise ValueError("Expected exactly one TSV file")
        return tsv_entries[0]


def normalize_text(value: Any, maximum: int) -> str:
    text = unicodedata.normalize("NFKC", str(value or ""))
    text = "".join(
        character
        for character in text
        if unicodedata.category(character) not in {"Cc", "Cf", "Cs"}
    ).strip()
    text = " ".join(text.split())
    if len(text) > maximum:
        text = text[:maximum]
    return text


def first_value(row: dict[str, str], keys: Iterable[str]) -> str:
    for key in keys:
        value = normalize_text(row.get(key, ""), 2048)
        if value:
            return value
    return ""


def parse_json_object(value: str) -> dict[str, Any]:
    clean = value.strip()
    if not clean:
        return {}
    try:
        decoded = json.loads(clean)
    except json.JSONDecodeError:
        return {}
    return decoded if isinstance(decoded, dict) else {}


def flatten_nutrition(row: dict[str, str]) -> dict[str, Any]:
    merged: dict[str, Any] = {}
    for key in NUTRITION_JSON_KEYS:
        raw = row.get(key, "")
        if raw:
            merged.update(parse_json_object(raw))
    merged.update(row)
    return merged


def numeric(
    source: dict[str, Any],
    keys: Iterable[str],
    *,
    maximum: float,
) -> float:
    for key in keys:
        value = source.get(key)
        if isinstance(value, dict):
            value = value.get("value")
        if value in (None, ""):
            continue
        try:
            number = float(str(value).replace(",", "."))
        except ValueError:
            continue
        if 0 <= number <= maximum:
            return number
    return 0.0


def validate_image_url(value: str) -> str:
    clean = normalize_text(value, 2048)
    if not clean:
        return ""
    parsed = urllib.parse.urlsplit(clean)
    if (
        parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.fragment
        or parsed.port not in (None, 443)
    ):
        return ""
    host = parsed.hostname.lower()
    try:
        ipaddress.ip_address(host)
        return ""
    except ValueError:
        pass
    return clean if host in ALLOWED_IMAGE_HOSTS else ""


def record_from_row(
    row: dict[str, str],
    *,
    row_number: int,
) -> tuple[Any, ...] | None:
    external_id = first_value(row, ID_KEYS)
    name = first_value(row, NAME_KEYS)
    if not external_id or not name:
        return None
    if not re.fullmatch(r"[A-Za-z0-9._:-]{1,128}", external_id):
        external_id = hashlib.sha256(
            f"{external_id}|{row_number}".encode("utf-8")
        ).hexdigest()[:32]

    brand = normalize_text(first_value(row, BRAND_KEYS), 160)
    barcode = re.sub(r"\D", "", first_value(row, BARCODE_KEYS))
    if barcode and not re.fullmatch(r"\d{6,18}", barcode):
        barcode = ""

    image_candidates = [
        normalize_text(row.get(key, ""), 2048) for key in IMAGE_KEYS
    ]
    image_candidates = [value for value in image_candidates if value]
    image_small = validate_image_url(image_candidates[0]) if image_candidates else ""
    image = validate_image_url(image_candidates[-1]) if image_candidates else ""

    nutrition = flatten_nutrition(row)
    kcal = numeric(
        nutrition,
        ("energy-kcal_100g", "kcal_100g", "calories_100g", "calories"),
        maximum=900,
    )
    protein = numeric(
        nutrition,
        ("proteins_100g", "protein_100g", "protein"),
        maximum=100,
    )
    carbs = numeric(
        nutrition,
        ("carbohydrates_100g", "carbs_100g", "carbohydrates", "carbs"),
        maximum=100,
    )
    fat = numeric(
        nutrition,
        ("fat_100g", "total_fat_100g", "fat"),
        maximum=100,
    )
    fiber = numeric(
        nutrition,
        ("fiber_100g", "fibre_100g", "fiber"),
        maximum=100,
    )
    sugar = numeric(
        nutrition,
        ("sugars_100g", "sugar_100g", "sugars", "sugar"),
        maximum=100,
    )
    salt = numeric(
        nutrition,
        ("salt_100g", "salt"),
        maximum=100,
    )
    sodium = numeric(
        nutrition,
        ("sodium_100g", "sodium"),
        maximum=100,
    )

    estimated = str(
        row.get("has_estimated_values", row.get("estimated", ""))
    ).lower() in {"1", "true", "yes"}
    from_off = str(
        row.get("from_open_food_facts", row.get("open_food_facts", ""))
    ).lower() in {"1", "true", "yes"}

    search_text = normalize_text(
        f"{name} {brand} {barcode}",
        512,
    ).lower()

    return (
        external_id,
        normalize_text(name, 200),
        brand,
        barcode,
        image,
        image_small,
        kcal,
        protein,
        carbs,
        fat,
        fiber,
        sugar,
        salt,
        sodium,
        int(estimated),
        int(from_off),
        search_text,
    )


def create_schema(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        PRAGMA journal_mode = OFF;
        PRAGMA synchronous = OFF;
        PRAGMA temp_store = MEMORY;
        PRAGMA trusted_schema = OFF;

        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        ) WITHOUT ROWID;

        CREATE TABLE foods (
            id INTEGER PRIMARY KEY,
            external_id TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            brand TEXT NOT NULL DEFAULT '',
            barcode TEXT NOT NULL DEFAULT '',
            image_url TEXT NOT NULL DEFAULT '',
            image_small_url TEXT NOT NULL DEFAULT '',
            kcal_100g REAL NOT NULL DEFAULT 0 CHECK(kcal_100g BETWEEN 0 AND 900),
            protein_100g REAL NOT NULL DEFAULT 0 CHECK(protein_100g BETWEEN 0 AND 100),
            carbs_100g REAL NOT NULL DEFAULT 0 CHECK(carbs_100g BETWEEN 0 AND 100),
            fat_100g REAL NOT NULL DEFAULT 0 CHECK(fat_100g BETWEEN 0 AND 100),
            fiber_100g REAL NOT NULL DEFAULT 0 CHECK(fiber_100g BETWEEN 0 AND 100),
            sugar_100g REAL NOT NULL DEFAULT 0 CHECK(sugar_100g BETWEEN 0 AND 100),
            salt_100g REAL NOT NULL DEFAULT 0 CHECK(salt_100g BETWEEN 0 AND 100),
            sodium_100g REAL NOT NULL DEFAULT 0 CHECK(sodium_100g BETWEEN 0 AND 100),
            estimated INTEGER NOT NULL DEFAULT 0 CHECK(estimated IN (0,1)),
            from_open_food_facts INTEGER NOT NULL DEFAULT 0 CHECK(from_open_food_facts IN (0,1)),
            search_text TEXT NOT NULL
        );

        CREATE UNIQUE INDEX foods_external_id_idx ON foods(external_id);
        CREATE INDEX foods_barcode_idx ON foods(barcode) WHERE barcode <> '';

        CREATE VIRTUAL TABLE foods_fts USING fts5(
            name,
            brand,
            search_text,
            content='foods',
            content_rowid='id',
            tokenize='unicode61 remove_diacritics 2'
        );

        CREATE TRIGGER foods_ai AFTER INSERT ON foods BEGIN
          INSERT INTO foods_fts(rowid, name, brand, search_text)
          VALUES (new.id, new.name, new.brand, new.search_text);
        END;
        """
    )


def import_dataset(args: argparse.Namespace) -> None:
    expected = args.sha256.strip().lower()
    if not re.fullmatch(r"[a-f0-9]{64}", expected):
        raise ValueError("Invalid expected SHA-256")
    actual = sha256_file(args.zip)
    if actual != expected:
        raise ValueError(f"SHA-256 mismatch: {actual}")

    archive_path = args.zip.resolve(strict=True)
    if args.zip.is_symlink():
        raise ValueError("Archive symlinks are not allowed")
    tsv_info = validate_zip(archive_path)

    output_parent = args.output.parent.resolve()
    output_parent.mkdir(parents=True, exist_ok=True)
    output_path = output_parent / args.output.name
    if output_path.is_symlink():
        raise ValueError("Output symlinks are not allowed")

    dataset_version = normalize_text(args.dataset_version, 80)
    if not dataset_version:
        raise ValueError("Dataset version is required")

    with tempfile.TemporaryDirectory(
        prefix="opennutrition-gateway-",
        dir=output_parent,
    ) as temporary:
        temporary_db = Path(temporary) / "database.sqlite"
        connection = sqlite3.connect(temporary_db)
        try:
            create_schema(connection)
            connection.execute(
                "INSERT INTO metadata(key, value) VALUES (?, ?)",
                ("dataset_version", dataset_version),
            )
            connection.execute(
                "INSERT INTO metadata(key, value) VALUES (?, ?)",
                ("archive_sha256", actual),
            )

            csv.field_size_limit(MAX_FIELD_BYTES)
            valid = 0
            invalid = 0
            batch: list[tuple[Any, ...]] = []

            with zipfile.ZipFile(archive_path) as archive:
                with archive.open(tsv_info, "r") as raw:
                    text_stream = io.TextIOWrapper(
                        raw,
                        encoding="utf-8-sig",
                        errors="strict",
                        newline="",
                    )
                    reader = csv.DictReader(
                        text_stream,
                        delimiter="\t",
                        quotechar='"',
                    )
                    if not reader.fieldnames or len(reader.fieldnames) > 512:
                        raise ValueError("Unsafe or missing TSV header")
                    normalized_fields = [
                        normalize_text(field, 128).lower()
                        for field in reader.fieldnames
                    ]
                    if (
                        any(not field for field in normalized_fields)
                        or len(set(normalized_fields)) != len(normalized_fields)
                        or not set(normalized_fields).intersection(ID_KEYS)
                        or not set(normalized_fields).intersection(NAME_KEYS)
                    ):
                        raise ValueError("Unexpected or duplicate TSV header")
                    reader.fieldnames = normalized_fields

                    for row_number, row in enumerate(reader, start=2):
                        if None in row:
                            raise ValueError("TSV row contains excess columns")
                        if row_number > args.max_rows + 1:
                            raise ValueError("Row limit exceeded")
                        record = record_from_row(
                            row,
                            row_number=row_number,
                        )
                        if record is None:
                            invalid += 1
                            continue
                        batch.append(record)
                        valid += 1

                        if len(batch) >= 1000:
                            connection.executemany(
                                """
                                INSERT OR IGNORE INTO foods(
                                    external_id, name, brand, barcode,
                                    image_url, image_small_url,
                                    kcal_100g, protein_100g, carbs_100g,
                                    fat_100g, fiber_100g, sugar_100g,
                                    salt_100g, sodium_100g, estimated,
                                    from_open_food_facts, search_text
                                ) VALUES (
                                    ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?
                                )
                                """,
                                batch,
                            )
                            connection.commit()
                            batch.clear()

            if batch:
                connection.executemany(
                    """
                    INSERT OR IGNORE INTO foods(
                        external_id, name, brand, barcode,
                        image_url, image_small_url,
                        kcal_100g, protein_100g, carbs_100g,
                        fat_100g, fiber_100g, sugar_100g,
                        salt_100g, sodium_100g, estimated,
                        from_open_food_facts, search_text
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                    """,
                    batch,
                )
                connection.commit()

            total = valid + invalid
            inserted = int(
                connection.execute("SELECT COUNT(*) FROM foods").fetchone()[0]
            )
            fts_rows = int(
                connection.execute("SELECT COUNT(*) FROM foods_fts").fetchone()[0]
            )
            if valid < 100 or inserted < 100:
                raise ValueError("Too few valid unique records")
            if total and invalid / total > MAX_INVALID_RATIO:
                raise ValueError("Invalid-row ratio too high")
            if inserted / valid < MIN_UNIQUE_RATIO:
                raise ValueError("Duplicate-record ratio too high")
            if fts_rows != inserted:
                raise ValueError("FTS index is incomplete")

            metadata = {
                "valid_records": str(valid),
                "invalid_records": str(invalid),
                "inserted_records": str(inserted),
                "schema_version": "1",
            }
            connection.executemany(
                "INSERT INTO metadata(key, value) VALUES (?, ?)",
                metadata.items(),
            )
            connection.execute("PRAGMA optimize")
            integrity = connection.execute(
                "PRAGMA integrity_check"
            ).fetchone()[0]
            if integrity != "ok":
                raise ValueError("SQLite integrity check failed")
            connection.execute(
                "INSERT INTO foods_fts(foods_fts) VALUES('integrity-check')"
            )
            connection.commit()
        finally:
            connection.close()

        # Su Windows os.fsync può fallire su un handle aperto in sola
        # lettura. Usiamo un handle binario scrivibile, eseguiamo flush e
        # quindi fsync prima della sostituzione atomica del database.
        with temporary_db.open("r+b") as database_file:
            database_file.flush()
            os.fsync(database_file.fileno())
        os.chmod(temporary_db, 0o444)
        os.replace(temporary_db, output_path)
        try:
            directory_fd = os.open(output_parent, os.O_RDONLY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        except OSError:
            pass


def main() -> int:
    try:
        args = parse_args()
        if not 1 <= args.max_rows <= MAX_ROWS:
            raise ValueError("Unsafe max-rows value")
        import_dataset(args)
        print(f"CREATED={args.output}")
        return 0
    except Exception as exc:
        print(f"ERROR={exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
