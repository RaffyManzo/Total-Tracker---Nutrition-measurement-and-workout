from __future__ import annotations

import base64
import hashlib
import ipaddress
import json
import os
import re
import sqlite3
import stat
import threading
import time
import urllib.parse
import uuid
from collections import OrderedDict
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterator

from app.security import validate_public_hostname, validate_search_query
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from fastapi import FastAPI, Query, Request
from fastapi.responses import Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp


REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._:-]{1,64}$")
INSTALLATION_ID_RE = re.compile(r"^[a-f0-9-]{36}$")
FOOD_ID_RE = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")
BARCODE_RE = re.compile(r"^\d{6,18}$")
HOST_RE = re.compile(r"^[a-z0-9.-]{1,253}$")
DISALLOWED_QUERY_RE = re.compile(r"[<>{}\[\]\\|^`~]")

MAX_RESPONSE_ITEMS = 20
MAX_PAGE = 20
MAX_QUERY_LENGTH = 80
MAX_RESPONSE_BYTES = 256 * 1024
MAX_REQUEST_TARGET_BYTES = 768
MAX_HEADER_COUNT = 64
MAX_HEADER_BYTES = 16 * 1024
MAX_CLOCK_SKEW_SECONDS = 300
MAX_DB_BYTES = 16 * 1024 * 1024 * 1024


class BusyError(RuntimeError):
    pass


@dataclass(frozen=True)
class Settings:
    db_path: Path
    signing_key: Ed25519PrivateKey
    key_id: str
    allowed_hosts: frozenset[str]
    trusted_proxies: frozenset[str]
    rate_per_minute: int
    burst: int
    max_tracked_clients: int
    max_replay_entries: int
    response_ttl_seconds: int
    max_concurrent_queries: int
    sqlite_timeout_ms: int

    @classmethod
    def load(cls) -> "Settings":
        db_path = _validate_database_file(
            Path(
                os.environ.get(
                    "OPENNUTRITION_DB_PATH",
                    "/data/opennutrition.db",
                )
            )
        )
        key_bytes = _load_signing_seed()
        key_id = os.environ.get(
            "OPENNUTRITION_SIGNING_KEY_ID",
            "primary",
        ).strip()
        if not re.fullmatch(r"[A-Za-z0-9._-]{1,64}", key_id):
            raise RuntimeError("Invalid signing key id")

        hosts = frozenset(
            item.strip().lower().rstrip(".")
            for item in os.environ.get(
                "OPENNUTRITION_ALLOWED_HOSTS",
                "",
            ).split(",")
            if item.strip()
        )
        if not hosts:
            raise RuntimeError("At least one allowed Host is required")
        try:
            hosts = frozenset(validate_public_hostname(host) for host in hosts)
        except ValueError as exc:
            raise RuntimeError("Invalid allowed Host") from exc

        trusted_proxies = frozenset(
            _parse_ip(item.strip())
            for item in os.environ.get(
                "OPENNUTRITION_TRUSTED_PROXY_IPS",
                "",
            ).split(",")
            if item.strip()
        )

        return cls(
            db_path=db_path,
            signing_key=Ed25519PrivateKey.from_private_bytes(key_bytes),
            key_id=key_id,
            allowed_hosts=hosts,
            trusted_proxies=trusted_proxies,
            rate_per_minute=_env_int(
                "OPENNUTRITION_RATE_LIMIT_PER_MINUTE",
                30,
                minimum=1,
                maximum=600,
            ),
            burst=_env_int(
                "OPENNUTRITION_RATE_LIMIT_BURST",
                10,
                minimum=1,
                maximum=100,
            ),
            max_tracked_clients=_env_int(
                "OPENNUTRITION_MAX_TRACKED_CLIENTS",
                50_000,
                minimum=1_000,
                maximum=1_000_000,
            ),
            max_replay_entries=_env_int(
                "OPENNUTRITION_MAX_REPLAY_ENTRIES",
                100_000,
                minimum=1_000,
                maximum=1_000_000,
            ),
            response_ttl_seconds=_env_int(
                "OPENNUTRITION_RESPONSE_TTL_SECONDS",
                120,
                minimum=30,
                maximum=600,
            ),
            max_concurrent_queries=_env_int(
                "OPENNUTRITION_MAX_CONCURRENT_QUERIES",
                16,
                minimum=1,
                maximum=128,
            ),
            sqlite_timeout_ms=_env_int(
                "OPENNUTRITION_SQLITE_TIMEOUT_MS",
                750,
                minimum=100,
                maximum=5_000,
            ),
        )


def _env_int(
    name: str,
    default: int,
    *,
    minimum: int,
    maximum: int,
) -> int:
    try:
        value = int(os.environ.get(name, str(default)))
    except ValueError as exc:
        raise RuntimeError(f"{name} is not an integer") from exc
    if not minimum <= value <= maximum:
        raise RuntimeError(f"{name} outside safe range")
    return value


def _parse_ip(value: str) -> str:
    try:
        return str(ipaddress.ip_address(value))
    except ValueError as exc:
        raise RuntimeError("Invalid trusted proxy IP") from exc


def _is_ip_literal(host: str) -> bool:
    try:
        ipaddress.ip_address(host.strip("[]"))
        return True
    except ValueError:
        return False


def _validate_database_file(raw_path: Path) -> Path:
    if not raw_path.is_absolute():
        raise RuntimeError("Database path must be absolute")
    if raw_path.is_symlink():
        raise RuntimeError("Database symlinks are not allowed")
    resolved = raw_path.resolve(strict=True)
    info = resolved.stat()
    if not stat.S_ISREG(info.st_mode):
        raise RuntimeError("Database path is not a regular file")
    if info.st_size <= 0 or info.st_size > MAX_DB_BYTES:
        raise RuntimeError("Database size outside safe range")
    if info.st_mode & (stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH):
        raise RuntimeError("Gateway database must be read-only")
    return resolved


def _load_signing_seed() -> bytes:
    key_file = os.environ.get(
        "OPENNUTRITION_SIGNING_KEY_FILE",
        "",
    ).strip()
    raw_key = os.environ.get(
        "OPENNUTRITION_SIGNING_KEY_BASE64",
        "",
    ).strip()

    if key_file:
        path = Path(key_file)
        if not path.is_absolute() or path.is_symlink():
            raise RuntimeError("Signing key file must be an absolute regular file")
        resolved = path.resolve(strict=True)
        info = resolved.stat()
        if not stat.S_ISREG(info.st_mode) or info.st_size > 512:
            raise RuntimeError("Unsafe signing key file")
        if info.st_mode & (stat.S_IRWXG | stat.S_IRWXO):
            raise RuntimeError("Signing key file permissions are too broad")
        raw_key = resolved.read_text(encoding="ascii").strip()

    if not raw_key:
        raise RuntimeError("Missing signing key")
    try:
        key_bytes = base64.b64decode(raw_key, validate=True)
    except Exception as exc:
        raise RuntimeError("Invalid signing key encoding") from exc
    if len(key_bytes) != 32:
        raise RuntimeError("Ed25519 private seed must be 32 bytes")
    return key_bytes


SETTINGS = Settings.load()


class TokenBucketLimiter:
    def __init__(
        self,
        *,
        rate_per_minute: int,
        burst: int,
        maximum_clients: int,
    ) -> None:
        self._rate_per_second = rate_per_minute / 60.0
        self._burst = float(burst)
        self._maximum_clients = maximum_clients
        self._buckets: OrderedDict[str, tuple[float, float]] = OrderedDict()
        self._lock = threading.Lock()

    def allow(self, key: str) -> bool:
        now = time.monotonic()
        with self._lock:
            tokens, updated = self._buckets.pop(
                key,
                (self._burst, now),
            )
            tokens = min(
                self._burst,
                tokens + (now - updated) * self._rate_per_second,
            )
            allowed = tokens >= 1.0
            if allowed:
                tokens -= 1.0
            self._buckets[key] = (tokens, now)
            while len(self._buckets) > self._maximum_clients:
                self._buckets.popitem(last=False)
            return allowed


class ReplayGuard:
    def __init__(self, maximum_entries: int) -> None:
        self._maximum_entries = maximum_entries
        self._entries: OrderedDict[str, float] = OrderedDict()
        self._lock = threading.Lock()

    def accept(self, request_id: str) -> bool:
        now = time.monotonic()
        expiry = now + MAX_CLOCK_SKEW_SECONDS * 2
        with self._lock:
            while self._entries:
                first_key = next(iter(self._entries))
                if self._entries[first_key] > now:
                    break
                self._entries.popitem(last=False)
            if request_id in self._entries:
                return False
            self._entries[request_id] = expiry
            while len(self._entries) > self._maximum_entries:
                self._entries.popitem(last=False)
            return True


LIMITER = TokenBucketLimiter(
    rate_per_minute=SETTINGS.rate_per_minute,
    burst=SETTINGS.burst,
    maximum_clients=SETTINGS.max_tracked_clients,
)
REPLAY_GUARD = ReplayGuard(SETTINGS.max_replay_entries)
QUERY_SLOTS = threading.BoundedSemaphore(SETTINGS.max_concurrent_queries)


class SecurityMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)

    async def dispatch(self, request: Request, call_next):
        if request.method not in {"GET", "HEAD"}:
            return _secured_error(405, "method_not_allowed")

        raw_headers = request.scope.get("headers", [])
        if len(raw_headers) > MAX_HEADER_COUNT:
            return _secured_error(431, "headers_too_large")
        header_bytes = sum(len(name) + len(value) for name, value in raw_headers)
        if header_bytes > MAX_HEADER_BYTES:
            return _secured_error(431, "headers_too_large")

        protected = {
            b"host",
            b"x-request-id",
            b"x-installation-id",
            b"x-client-timestamp",
            b"x-forwarded-for",
        }
        counts: dict[bytes, int] = {}
        for raw_name, _ in raw_headers:
            name = raw_name.lower()
            if name in protected:
                counts[name] = counts.get(name, 0) + 1
        if any(value != 1 for key, value in counts.items() if key != b"x-forwarded-for"):
            return _secured_error(400, "duplicate_security_header")
        if counts.get(b"host", 0) != 1:
            return _secured_error(400, "invalid_host")
        if counts.get(b"x-forwarded-for", 0) > 1:
            return _secured_error(400, "invalid_forwarded_for")

        target_size = len(request.scope.get("raw_path", b"")) + len(
            request.scope.get("query_string", b"")
        )
        if target_size > MAX_REQUEST_TARGET_BYTES:
            return _secured_error(414, "request_target_too_large")

        content_length = request.headers.get("content-length")
        if content_length not in {None, "", "0"}:
            return _secured_error(413, "body_not_allowed")
        if request.headers.get("transfer-encoding"):
            return _secured_error(400, "transfer_encoding_not_allowed")

        raw_host = request.headers.get("host", "").strip().lower()
        host = raw_host[:-1] if raw_host.endswith(".") else raw_host
        if host.count(":") > 1:
            return _secured_error(400, "invalid_host")
        host_name = host.split(":", 1)[0]
        if host_name not in SETTINGS.allowed_hosts:
            return _secured_error(400, "invalid_host")

        request_id = request.headers.get("x-request-id", "")
        if not REQUEST_ID_RE.fullmatch(request_id):
            return _secured_error(400, "invalid_request_id")
        if not REPLAY_GUARD.accept(request_id):
            return _secured_error(409, "replayed_request")
        request.state.request_id = request_id

        installation_id = request.headers.get("x-installation-id", "")
        if not INSTALLATION_ID_RE.fullmatch(installation_id):
            return _secured_error(400, "invalid_installation_id")

        try:
            client_timestamp = int(
                request.headers.get("x-client-timestamp", "")
            )
        except ValueError:
            return _secured_error(400, "invalid_client_timestamp")
        now_ms = int(time.time() * 1000)
        if abs(now_ms - client_timestamp) > MAX_CLOCK_SKEW_SECONDS * 1000:
            return _secured_error(400, "stale_client_timestamp")

        client_ip = _client_ip(request)
        rate_key = hashlib.sha256(
            f"{client_ip}|{installation_id}".encode("utf-8")
        ).hexdigest()
        if not LIMITER.allow(rate_key):
            response = _secured_error(429, "rate_limited")
            response.headers["Retry-After"] = "60"
            return response

        try:
            response = await call_next(request)
        except Exception:
            response = _unsigned_error(503, "service_unavailable")
        return _security_headers(response)


def _client_ip(request: Request) -> str:
    direct = request.client.host if request.client else ""
    try:
        direct_ip = str(ipaddress.ip_address(direct))
    except ValueError:
        return "unknown"

    if direct_ip not in SETTINGS.trusted_proxies:
        return direct_ip

    forwarded = request.headers.get("x-forwarded-for", "").strip()
    if not forwarded or "," in forwarded:
        return direct_ip
    try:
        return str(ipaddress.ip_address(forwarded))
    except ValueError:
        return direct_ip


def _security_headers(response: Response) -> Response:
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Content-Security-Policy"] = "default-src 'none'"
    response.headers["Permissions-Policy"] = (
        "camera=(), microphone=(), geolocation=()"
    )
    response.headers["Strict-Transport-Security"] = (
        "max-age=63072000; includeSubDomains; preload"
    )
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Cross-Origin-Resource-Policy"] = "same-site"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Server"] = ""
    return response


def _unsigned_error(status: int, code: str) -> Response:
    body = json.dumps(
        {"error": code},
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return Response(
        content=body,
        status_code=status,
        media_type="application/json",
    )


def _secured_error(status: int, code: str) -> Response:
    return _security_headers(_unsigned_error(status, code))


app = FastAPI(
    title="Total Tracker OpenNutrition Gateway",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)
app.add_middleware(SecurityMiddleware)


def _database() -> sqlite3.Connection:
    quoted = urllib.parse.quote(SETTINGS.db_path.as_posix(), safe="/:")
    uri = f"file:{quoted}?mode=ro&immutable=1"
    connection = sqlite3.connect(
        uri,
        uri=True,
        timeout=SETTINGS.sqlite_timeout_ms / 1000.0,
        check_same_thread=False,
    )
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA query_only = ON")
    connection.execute("PRAGMA trusted_schema = OFF")
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute(
        f"PRAGMA busy_timeout = {SETTINGS.sqlite_timeout_ms}"
    )
    deadline = time.monotonic() + SETTINGS.sqlite_timeout_ms / 1000.0
    connection.set_progress_handler(
        lambda: 1 if time.monotonic() > deadline else 0,
        1000,
    )
    return connection


@contextmanager
def _query_slot() -> Iterator[None]:
    if not QUERY_SLOTS.acquire(blocking=False):
        raise BusyError("query capacity reached")
    try:
        yield
    finally:
        QUERY_SLOTS.release()


def _normalize_query(value: str) -> str:
    return validate_search_query(value)


def _fts_expression(query: str) -> str:
    tokens = re.findall(r"[\wÀ-ÖØ-öø-ÿ]+", query, flags=re.UNICODE)
    tokens = [token[:32] for token in tokens[:8] if len(token) >= 2]
    if not tokens:
        raise ValueError("invalid_query")
    return " AND ".join(
        f'"{token.replace(chr(34), "")}"*' for token in tokens
    )


def _dataset_version(connection: sqlite3.Connection) -> str:
    row = connection.execute(
        "SELECT value FROM metadata WHERE key = 'dataset_version'"
    ).fetchone()
    if row is None:
        raise RuntimeError("dataset unavailable")
    value = str(row["value"])
    if not value or len(value) > 80:
        raise RuntimeError("invalid dataset version")
    return value


def _row_to_item(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "externalId": str(row["external_id"]),
        "name": str(row["name"]),
        "brand": str(row["brand"] or ""),
        "barcode": str(row["barcode"] or ""),
        "imageUrl": str(row["image_url"] or ""),
        "imageSmallUrl": str(row["image_small_url"] or ""),
        "kcal100g": float(row["kcal_100g"] or 0),
        "protein100g": float(row["protein_100g"] or 0),
        "carbs100g": float(row["carbs_100g"] or 0),
        "fat100g": float(row["fat_100g"] or 0),
        "fiber100g": float(row["fiber_100g"] or 0),
        "sugar100g": float(row["sugar_100g"] or 0),
        "salt100g": float(row["salt_100g"] or 0),
        "sodium100g": float(row["sodium_100g"] or 0),
        "estimated": bool(row["estimated"]),
        "fromOpenFoodFacts": bool(row["from_open_food_facts"]),
    }


def _signed_json(
    *,
    request_id: str,
    payload: dict[str, Any],
    status_code: int = 200,
) -> Response:
    now = datetime.now(timezone.utc)
    envelope = {
        "schemaVersion": 1,
        "requestId": request_id,
        "issuedAt": now.isoformat().replace("+00:00", "Z"),
        "expiresAt": (
            now + timedelta(seconds=SETTINGS.response_ttl_seconds)
        ).isoformat().replace("+00:00", "Z"),
        **payload,
    }
    body = json.dumps(
        envelope,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
        allow_nan=False,
    ).encode("utf-8")
    if len(body) > MAX_RESPONSE_BYTES:
        return _secured_error(500, "response_limit_exceeded")

    signature = SETTINGS.signing_key.sign(body)
    response = Response(
        content=body,
        status_code=status_code,
        media_type="application/json",
        headers={
            "X-OpenNutrition-Signature": base64.b64encode(
                signature
            ).decode("ascii"),
            "X-OpenNutrition-Key-Id": SETTINGS.key_id,
        },
    )
    return _security_headers(response)


@app.get("/v1/health")
def health(request: Request) -> Response:
    try:
        with _query_slot(), _database() as connection:
            dataset_version = _dataset_version(connection)
            connection.execute("SELECT 1 FROM foods LIMIT 1").fetchone()
        return _signed_json(
            request_id=request.state.request_id,
            payload={
                "status": "ok",
                "datasetVersion": dataset_version,
            },
        )
    except BusyError:
        return _secured_error(503, "busy")
    except Exception:
        return _secured_error(503, "service_unavailable")


@app.get("/v1/search")
def search(
    request: Request,
    q: str = Query(min_length=2, max_length=MAX_QUERY_LENGTH),
    page: int = Query(default=1, ge=1, le=MAX_PAGE),
    limit: int = Query(default=20, ge=1, le=MAX_RESPONSE_ITEMS),
) -> Response:
    try:
        clean = _normalize_query(q)
        expression = _fts_expression(clean)
        offset = (page - 1) * limit
        fetch_limit = limit + 1

        with _query_slot(), _database() as connection:
            dataset_version = _dataset_version(connection)
            rows = connection.execute(
                """
                SELECT
                    f.external_id,
                    f.name,
                    f.brand,
                    f.barcode,
                    f.image_url,
                    f.image_small_url,
                    f.kcal_100g,
                    f.protein_100g,
                    f.carbs_100g,
                    f.fat_100g,
                    f.fiber_100g,
                    f.sugar_100g,
                    f.salt_100g,
                    f.sodium_100g,
                    f.estimated,
                    f.from_open_food_facts,
                    bm25(foods_fts, 8.0, 4.0, 2.0) AS rank
                FROM foods_fts
                JOIN foods AS f ON f.id = foods_fts.rowid
                WHERE foods_fts MATCH ?
                ORDER BY rank ASC, f.name COLLATE NOCASE ASC
                LIMIT ? OFFSET ?
                """,
                (expression, fetch_limit, offset),
            ).fetchall()

        has_next = len(rows) > limit
        items = [_row_to_item(row) for row in rows[:limit]]
        return _signed_json(
            request_id=request.state.request_id,
            payload={
                "datasetVersion": dataset_version,
                "page": page,
                "hasNext": has_next,
                "items": items,
            },
        )
    except ValueError:
        return _secured_error(400, "invalid_query")
    except BusyError:
        return _secured_error(503, "busy")
    except sqlite3.OperationalError:
        return _secured_error(503, "query_timeout")
    except Exception:
        return _secured_error(503, "service_unavailable")


@app.get("/v1/foods/{external_id}")
def food_by_id(request: Request, external_id: str) -> Response:
    if not FOOD_ID_RE.fullmatch(external_id):
        return _secured_error(400, "invalid_id")
    try:
        with _query_slot(), _database() as connection:
            dataset_version = _dataset_version(connection)
            row = connection.execute(
                """
                SELECT * FROM foods
                WHERE external_id = ?
                LIMIT 1
                """,
                (external_id,),
            ).fetchone()
        if row is None:
            return _secured_error(404, "not_found")
        return _signed_json(
            request_id=request.state.request_id,
            payload={
                "datasetVersion": dataset_version,
                "food": _row_to_item(row),
            },
        )
    except BusyError:
        return _secured_error(503, "busy")
    except sqlite3.OperationalError:
        return _secured_error(503, "query_timeout")
    except Exception:
        return _secured_error(503, "service_unavailable")


@app.get("/v1/barcodes/{barcode}")
def food_by_barcode(request: Request, barcode: str) -> Response:
    if not BARCODE_RE.fullmatch(barcode):
        return _secured_error(400, "invalid_barcode")
    try:
        with _query_slot(), _database() as connection:
            dataset_version = _dataset_version(connection)
            row = connection.execute(
                """
                SELECT * FROM foods
                WHERE barcode = ?
                LIMIT 1
                """,
                (barcode,),
            ).fetchone()
        if row is None:
            return _secured_error(404, "not_found")
        return _signed_json(
            request_id=request.state.request_id,
            payload={
                "datasetVersion": dataset_version,
                "food": _row_to_item(row),
            },
        )
    except BusyError:
        return _secured_error(503, "busy")
    except sqlite3.OperationalError:
        return _secured_error(503, "query_timeout")
    except Exception:
        return _secured_error(503, "service_unavailable")
