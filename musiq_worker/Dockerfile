# ACCESS VisionCheck MUSIQ + OpenCV worker (Linux).
#
# Local (optional):
#   docker build -t access-musiq-worker -f musiq_worker/Dockerfile musiq_worker
#
# Remote cloud build (preferred when the laptop has no Docker):
#   fly deploy --remote-only --config musiq_worker/fly.toml
#   or GitHub Actions: .github/workflows/musiq-worker-fly.yml
#
# Model: TF Hub google/musiq/paq2piq/1 (Apache 2.0 label). See docs/LICENSE_NOTES.md.
# Context must be the musiq_worker/ directory (Fly/build uses this Dockerfile's folder).

FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    CUDA_VISIBLE_DEVICES=-1 \
    TFHUB_CACHE_DIR=/models/tfhub \
    PRELOAD_MUSIQ=true \
    WORKER_HOST=0.0.0.0 \
    WORKER_PORT=8080 \
    PORT=8080 \
    ALLOW_INSECURE_EMPTY_TOKEN=false

RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        libgl1 \
        libglib2.0-0 \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY entrypoint.sh ./entrypoint.sh

RUN mkdir -p /models/tfhub /tmp/musiq_worker \
    && useradd --create-home --uid 10001 worker \
    && chown -R worker:worker /app /models /tmp/musiq_worker \
    && chmod +x /app/entrypoint.sh

USER worker

# Platforms may remap this; entrypoint honors $PORT at runtime.
EXPOSE 8080

# Liveness only (MUSIQ may still be loading). Use /ready for full readiness probes.
HEALTHCHECK --interval=30s --timeout=5s --start-period=300s --retries=5 \
  CMD curl -fsS "http://127.0.0.1:${PORT:-8080}/health" || exit 1

CMD ["/app/entrypoint.sh"]
