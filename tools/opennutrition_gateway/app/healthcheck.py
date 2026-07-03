from __future__ import annotations

import os
import time
import urllib.request
import uuid

host = os.environ["OPENNUTRITION_HEALTHCHECK_HOST"].strip()
request = urllib.request.Request(
    "http://127.0.0.1:8080/v1/health",
    headers={
        "Host": host,
        "Accept": "application/json",
        "X-Request-Id": str(uuid.uuid4()),
        "X-Installation-Id": str(uuid.uuid4()),
        "X-Client-Timestamp": str(int(time.time() * 1000)),
    },
)
with urllib.request.urlopen(request, timeout=2) as response:
    if response.status != 200:
        raise SystemExit(1)
