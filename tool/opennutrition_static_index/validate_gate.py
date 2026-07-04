#!/usr/bin/env python3
"""Fail CI when the audited semantic or integrity floor regresses."""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from typing import Any, NoReturn

MAX_SUMMARY_BYTES = 1024 * 1024
SHA256_PATTERN = re.compile(r"^[a-f0-9]{64}$")


def fail(message: str) -> NoReturn:
    print(f"SEMANTIC_GATE_FAILURE={message}", file=sys.stderr)
    raise SystemExit(2)


def read_int(data: dict[str, Any], key: str) -> int:
    value = data.get(key)
    if isinstance(value, bool):
        fail(f"{key} must be an integer")
    try:
        return int(value)
    except (TypeError, ValueError):
        fail(f"{key} is missing or invalid")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", required=True)
    parser.add_argument("--minimum-top1", type=int, default=48)
    parser.add_argument("--minimum-top5", type=int, default=49)
    parser.add_argument("--expected-count", type=int, default=50)
    parser.add_argument(
        "--expected-dataset-version",
        default="2025.1",
    )
    parser.add_argument(
        "--expected-schema-version",
        type=int,
        default=3,
    )
    parser.add_argument(
        "--minimum-records",
        type=int,
        default=300000,
    )
    args = parser.parse_args()

    summary_path = pathlib.Path(args.summary).resolve()
    if not summary_path.is_file():
        fail(f"summary missing: {summary_path}")
    if summary_path.stat().st_size > MAX_SUMMARY_BYTES:
        fail("summary exceeds size limit")

    try:
        decoded = json.loads(summary_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"summary is not valid UTF-8 JSON: {error}")

    if not isinstance(decoded, dict):
        fail("summary root must be an object")

    data: dict[str, Any] = decoded
    count = read_int(data, "benchmarkCount")
    top1 = read_int(data, "strictTop1Pass")
    top5 = read_int(data, "acceptableInTop5")
    verified_shards = read_int(data, "verifiedShards")
    schema_version = read_int(data, "schemaVersion")
    gate_version = read_int(data, "gateVersion")
    unique_records = read_int(data, "uniqueLoadedRecords")
    dataset_version = str(data.get("datasetVersion", ""))
    manifest_sha256 = str(data.get("manifestSha256", "")).lower()

    failures: list[str] = []
    if gate_version != 5:
        failures.append(f"gate version {gate_version} != 5")
    if dataset_version != args.expected_dataset_version:
        failures.append(
            "dataset version "
            f"{dataset_version!r} != {args.expected_dataset_version!r}"
        )
    if schema_version != args.expected_schema_version:
        failures.append(
            f"schema version {schema_version} "
            f"!= {args.expected_schema_version}"
        )
    if not SHA256_PATTERN.fullmatch(manifest_sha256):
        failures.append("manifest SHA-256 is missing or invalid")
    if count != args.expected_count:
        failures.append(
            f"benchmark count {count} != {args.expected_count}"
        )
    if top1 < args.minimum_top1 or top1 > count:
        failures.append(
            f"strict top-1 {top1} outside "
            f"[{args.minimum_top1}, {count}]"
        )
    if top5 < args.minimum_top5 or top5 > count:
        failures.append(
            f"acceptable top-5 {top5} outside "
            f"[{args.minimum_top5}, {count}]"
        )
    if top5 < top1:
        failures.append("acceptable top-5 cannot be lower than top-1")
    if verified_shards <= 0:
        failures.append("no verified shards")
    if unique_records < args.minimum_records:
        failures.append(
            f"unique records {unique_records} < {args.minimum_records}"
        )

    if failures:
        for failure in failures:
            print(
                f"SEMANTIC_GATE_FAILURE={failure}",
                file=sys.stderr,
            )
        raise SystemExit(2)

    print(f"SEMANTIC_GATE_ACCEPTED_TOP1={top1}/{count}")
    print(f"SEMANTIC_GATE_ACCEPTED_TOP5={top5}/{count}")
    print(f"VERIFIED_SHARDS={verified_shards}")
    print(f"UNIQUE_RECORDS={unique_records}")
    print(f"MANIFEST_SHA256={manifest_sha256}")


if __name__ == "__main__":
    main()
