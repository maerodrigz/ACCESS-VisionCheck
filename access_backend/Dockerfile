# ACCESS VisionCheck FastAPI — production image for Render / Docker
#
# Build from the REPOSITORY ROOT (required):
#   docker build -f access_backend/Dockerfile -t access-api .
#
# Render settings:
#   Dockerfile path:  access_backend/Dockerfile
#   Docker context:   .   (repository root)
#
# AI checkpoints are NOT copied into the image (gitignored / dockerignored).
# Mount weights or set PROBE_CHECKPOINT_PATH (and WaveRep paths) at runtime.

FROM python:3.12-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY access_backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Application code only (secrets, .env, uploads, and *.pth/*.ckpt excluded by root .dockerignore)
COPY access_backend /app

ENV PYTHONPATH=/app
ENV APP_ENV=production
ENV API_HOST=0.0.0.0
ENV API_PORT=3001

# Default local/dev publish; Render maps $PORT dynamically.
EXPOSE 3001

# DB-backed liveness (matches GET /api/health). Long start period for cold PyTorch imports.
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD python -c "import os,urllib.request; p=os.environ.get('PORT') or os.environ.get('API_PORT') or '3001'; urllib.request.urlopen(f'http://127.0.0.1:{p}/api/health', timeout=4)" || exit 1

# Bind 0.0.0.0; prefer Render PORT, else API_PORT, else 3001. Reload always off via --no-reload
# (manage.py also forces reload off when APP_ENV=production).
CMD ["sh", "-c", "exec python manage.py runserver --host 0.0.0.0 --port ${PORT:-${API_PORT:-3001}} --no-reload"]
