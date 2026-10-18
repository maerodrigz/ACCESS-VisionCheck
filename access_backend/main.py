"""
ACCESS VisionCheck API — entry point.

Run:
  python manage.py runserver

Or:
  python main.py
"""

import mimetypes
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.api.routes import api_router
from app.config import settings


@asynccontextmanager
async def _app_lifespan(_app: FastAPI):
    import asyncio

    from app.services.deferred_media_pipeline import reconcile_pending_media_evaluations

    async def _warm_heavy_services() -> None:
        await asyncio.to_thread(reconcile_pending_media_evaluations)

        def _warm_probe_detector() -> None:
            from app.services.dedicated_ai_detector import active_ai_detector_backend

            if active_ai_detector_backend() != "probe":
                return
            from app.services.probe_dino_detector import _get_model

            _get_model()

        def _warm_fcm() -> None:
            from app.services.firebase_admin_app import ensure_firebase_admin_app, is_fcm_configured

            if is_fcm_configured():
                ensure_firebase_admin_app()

        await asyncio.to_thread(_warm_probe_detector)
        await asyncio.to_thread(_warm_fcm)

    # Do not block login/health on PROBE/FCM init (mobile would timeout waiting for startup).
    warm_task = asyncio.create_task(_warm_heavy_services())
    yield
    warm_task.cancel()


app = FastAPI(
    title="ACCESS VisionCheck API",
    description="Backend for Flutter Web Admin (Chrome) and Mobile User (Android)",
    version="1.0.0",
    lifespan=_app_lifespan,
)

# Restrict Host header to configured LAN/local names (see ALLOWED_HOSTS in .env)
app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.allowed_host_list)

# Flutter Web dev server uses random ports (e.g. localhost:52365)
_cors_kwargs: dict = {
    "allow_credentials": True,
    "allow_methods": ["*"],
    "allow_headers": ["*"],
}
if settings.cors_origins.strip() == "*":
    _cors_kwargs["allow_origins"] = ["*"]
else:
    _cors_kwargs["allow_origins"] = settings.cors_origin_list
    _cors_kwargs["allow_origin_regex"] = r"http://(localhost|127\.0\.0\.1):\d+"

app.add_middleware(CORSMiddleware, **_cors_kwargs)


class PrivateNetworkAccessMiddleware(BaseHTTPMiddleware):
    """Chrome: allow Flutter Web on localhost to call LAN API (10.0.x.x:3001)."""

    async def dispatch(self, request: Request, call_next) -> Response:
        if request.method == "OPTIONS" and request.headers.get(
            "access-control-request-private-network"
        ):
            response = Response(status_code=204)
            response.headers["Access-Control-Allow-Private-Network"] = "true"
            origin = request.headers.get("origin")
            if origin:
                response.headers["Access-Control-Allow-Origin"] = origin
                response.headers["Access-Control-Allow-Credentials"] = "true"
                response.headers["Access-Control-Allow-Methods"] = "GET, POST, PATCH, PUT, DELETE, OPTIONS"
                response.headers["Access-Control-Allow-Headers"] = request.headers.get(
                    "access-control-request-headers", "*"
                )
            return response
        response = await call_next(request)
        if request.headers.get("access-control-request-private-network"):
            response.headers["Access-Control-Allow-Private-Network"] = "true"
        return response


app.add_middleware(PrivateNetworkAccessMiddleware)

# Windows often lacks WebP/HEIC mappings — browsers need correct Content-Type for previews.
mimetypes.add_type("image/webp", ".webp")
mimetypes.add_type("image/heic", ".heic")
mimetypes.add_type("image/heif", ".heif")
mimetypes.add_type("video/mp4", ".mp4")

# Uploaded media files
upload_path = Path(settings.upload_dir)
upload_path.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(upload_path)), name="uploads")

app.include_router(api_router)


@app.exception_handler(HTTPException)
async def flutter_compatible_errors(_, exc: HTTPException):
    """Return {error, message} JSON for Flutter ApiClient compatibility."""
    if isinstance(exc.detail, dict):
        return JSONResponse(status_code=exc.status_code, content=exc.detail)
    detail = str(exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": detail,
            "message": detail,
            "detail": detail,
        },
    )


@app.exception_handler(Exception)
async def unhandled_errors(request: Request, exc: Exception):
    """Avoid plain-text 500 bodies that break Flutter JSON parsing."""
    msg = str(exc) or "Internal server error"
    response = JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": msg,
            "message": "Unable to load data",
            "details": msg,
            "detail": msg,
        },
    )
    origin = request.headers.get("origin")
    if origin and (
        settings.cors_origins.strip() == "*"
        or origin in settings.cors_origin_list
        or origin.startswith("http://localhost:")
        or origin.startswith("http://127.0.0.1:")
    ):
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
    return response


@app.get("/")
def root():
    return {
        "name": "ACCESS VisionCheck API",
        "docs": "/docs",
        "health": "/api/health",
        "public_url": settings.public_api_url,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host=settings.api_host, port=settings.api_port, reload=True)
