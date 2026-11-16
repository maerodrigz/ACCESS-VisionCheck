#!/bin/sh
# Cloud platforms inject PORT (Fly, Cloud Run, Railway, Render).
# Always bind 0.0.0.0 so the platform proxy can reach the process.
set -eu
HOST="${WORKER_HOST:-0.0.0.0}"
PORT="${PORT:-${WORKER_PORT:-8080}}"
echo "musiq-worker starting host=${HOST} port=${PORT} preload=${PRELOAD_MUSIQ:-true}"
exec uvicorn app.main:app --host "${HOST}" --port "${PORT}"
