#!/usr/bin/env python3
"""Safely extract the small allowlist required from the OpenNutrition ZIP."""

from __future__ import annotations

import argparse
import pathlib
import shutil
import sys
import zipfile
from typing import NoReturn

ALLOWED_BASENAMES = {
    "opennutrition_foods.tsv",
    "LICENSE-ODbL.txt",
    "LICENSE-DbCL.txt",
    "README.md",
}
MAX_TOTAL_UNCOMPRESSED_BYTES = 2 * 1024 * 1024 * 1024
MAX_ENTRY_UNCOMPRESSED_BYTES = 2 * 1024 * 1024 * 1024
MAX_COMPRESSION_RATIO = 250


def fail(message: str) -> NoReturn:
    print(f"SAFE_EXTRACT_ERROR={message}", file=sys.stderr)
    raise SystemExit(2)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    archive_path = pathlib.Path(args.archive).resolve()
    output_root = pathlib.Path(args.out).resolve()

    if not archive_path.is_file():
        fail(f"archive missing: {archive_path}")
    if output_root == pathlib.Path(output_root.anchor):
        fail("refusing to use a filesystem root as extraction output")
    if output_root == archive_path.parent:
        fail("refusing to replace the archive parent directory")

    if output_root.exists():
        shutil.rmtree(output_root)
    output_root.mkdir(parents=True)

    seen: set[str] = set()
    total = 0

    try:
        archive = zipfile.ZipFile(archive_path)
    except (OSError, zipfile.BadZipFile) as error:
        fail(f"invalid ZIP archive: {error}")

    with archive:
        for info in archive.infolist():
            normalized = info.filename.replace("\\", "/")
            if info.is_dir():
                continue

            parts = pathlib.PurePosixPath(normalized).parts
            if (
                normalized.startswith("/")
                or normalized.startswith("\\")
                or ".." in parts
            ):
                fail(f"unsafe archive path: {normalized}")

            basename = pathlib.PurePosixPath(normalized).name
            if basename not in ALLOWED_BASENAMES:
                continue
            if basename in seen:
                fail(f"duplicate allowlisted entry: {basename}")
            seen.add(basename)

            if (
                info.file_size < 0
                or info.file_size > MAX_ENTRY_UNCOMPRESSED_BYTES
            ):
                fail(f"entry too large: {basename}")

            total += info.file_size
            if total > MAX_TOTAL_UNCOMPRESSED_BYTES:
                fail("total extracted size exceeds limit")

            compressed = max(1, info.compress_size)
            ratio = info.file_size / compressed
            if (
                info.file_size > 100 * 1024 * 1024
                and ratio > MAX_COMPRESSION_RATIO
            ):
                fail(f"suspicious compression ratio: {basename}")

            target = output_root / basename
            try:
                with (
                    archive.open(info, "r") as source,
                    target.open("xb") as destination,
                ):
                    shutil.copyfileobj(
                        source,
                        destination,
                        length=1024 * 1024,
                    )
            except (OSError, RuntimeError, zipfile.BadZipFile) as error:
                fail(f"cannot extract {basename}: {error}")

    if "opennutrition_foods.tsv" not in seen:
        fail("required TSV missing")

    print(f"SAFE_EXTRACT_OK={output_root}")
    print(f"EXTRACTED_ENTRIES={len(seen)}")
    print(f"EXTRACTED_BYTES={total}")


if __name__ == "__main__":
    main()
