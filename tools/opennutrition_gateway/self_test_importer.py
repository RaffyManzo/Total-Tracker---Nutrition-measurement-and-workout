from __future__ import annotations

import argparse
import csv
import hashlib
import sqlite3
import tempfile
import zipfile
from pathlib import Path

from import_dataset import import_dataset


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="opennutrition-self-test-") as raw:
        root = Path(raw)
        tsv = root / "foods.tsv"
        with tsv.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream, delimiter="\t")
            writer.writerow(
                [
                    "id",
                    "name",
                    "brand",
                    "barcode",
                    "nutrition_100g",
                ]
            )
            for index in range(120):
                writer.writerow(
                    [
                        f"self-{index}",
                        f"Safe food {index}",
                        "Test",
                        f"8000000{index:06d}",
                        '{"energy-kcal_100g":100,"proteins_100g":5}',
                    ]
                )

        archive_path = root / "dataset.zip"
        with zipfile.ZipFile(
            archive_path,
            "w",
            compression=zipfile.ZIP_DEFLATED,
        ) as archive:
            archive.write(tsv, "foods.tsv")

        output = root / "opennutrition.db"
        args = argparse.Namespace(
            zip=archive_path,
            sha256=hashlib.sha256(archive_path.read_bytes()).hexdigest(),
            dataset_version="self-test-1",
            output=output,
            max_rows=500,
        )
        import_dataset(args)

        connection = sqlite3.connect(
            f"file:{output.as_posix()}?mode=ro&immutable=1",
            uri=True,
        )
        try:
            rows = connection.execute("SELECT COUNT(*) FROM foods").fetchone()[0]
            version = connection.execute(
                "SELECT value FROM metadata WHERE key='dataset_version'"
            ).fetchone()[0]
            integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
        finally:
            connection.close()

        if rows != 120 or version != "self-test-1" or integrity != "ok":
            raise RuntimeError("Importer self-test failed")

    print("OPENNUTRITION_IMPORTER_SELF_TEST_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
