from __future__ import annotations

import ipaddress
import re


CONTROL_RE = re.compile(r"[\x00-\x1f\x7f]")
BIDI_RE = re.compile(r"[\u200e\u200f\u202a-\u202e\u2066-\u2069]")
DISALLOWED_QUERY_RE = re.compile(r"[<>{}\[\]\\|^`~;]")
URL_LIKE_RE = re.compile(r"(?i)(?:https?://|www\.)")

MAX_QUERY_LENGTH = 80
MAX_QUERY_UTF8_BYTES = 160
MAX_QUERY_WORDS = 12


def validate_public_hostname(host: str) -> str:
    clean = host.strip().lower().rstrip(".")
    if (
        not clean
        or len(clean) > 253
        or ".." in clean
        or clean == "localhost"
        or clean.endswith(".localhost")
        or clean.endswith(".local")
        or not re.fullmatch(r"[a-z0-9.-]+", clean)
    ):
        raise ValueError("invalid_host")

    try:
        ipaddress.ip_address(clean.strip("[]"))
    except ValueError:
        pass
    else:
        raise ValueError("invalid_host")

    labels = clean.split(".")
    if len(labels) < 2:
        raise ValueError("invalid_host")
    for label in labels:
        if (
            not 1 <= len(label) <= 63
            or label.startswith("-")
            or label.endswith("-")
            or not re.fullmatch(r"[a-z0-9-]+", label)
        ):
            raise ValueError("invalid_host")
    return clean


def validate_search_query(value: str) -> str:
    raw = value.strip()
    if CONTROL_RE.search(raw) or BIDI_RE.search(raw):
        raise ValueError("invalid_query")
    if (
        DISALLOWED_QUERY_RE.search(raw)
        or URL_LIKE_RE.search(raw)
        or "--" in raw
        or "/*" in raw
        or "*/" in raw
    ):
        raise ValueError("invalid_query")

    clean = " ".join(raw.split())
    if not 2 <= len(clean) <= MAX_QUERY_LENGTH:
        raise ValueError("invalid_query")
    if len(clean.encode("utf-8")) > MAX_QUERY_UTF8_BYTES:
        raise ValueError("invalid_query")

    words = [word for word in clean.split(" ") if word]
    if len(words) > MAX_QUERY_WORDS or any(len(word) > 40 for word in words):
        raise ValueError("invalid_query")
    if not any(character.isalnum() for character in clean):
        raise ValueError("invalid_query")
    return clean
