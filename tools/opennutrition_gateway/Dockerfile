FROM python:3.13.5-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN groupadd --system gateway \
    && useradd --system --gid gateway --home-dir /app gateway

WORKDIR /app
COPY requirements.txt .
RUN pip install --requirement requirements.txt \
    && python -m pip check

COPY app ./app
RUN chown -R gateway:gateway /app

USER gateway
EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--no-access-log", "--no-proxy-headers", "--no-server-header", "--timeout-keep-alive", "5", "--limit-concurrency", "64", "--limit-max-requests", "10000"]
