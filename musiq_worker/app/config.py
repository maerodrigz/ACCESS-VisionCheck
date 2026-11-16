"""Worker settings from environment."""

from __future__ import annotations

import os
from functools import lru_cache

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class WorkerSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    worker_host: str = Field(default="0.0.0.0", alias="WORKER_HOST")
    # Cloud hosts set PORT; local/compose may set WORKER_PORT.
    worker_port: int = Field(
        default=8080,
        validation_alias=AliasChoices("PORT", "WORKER_PORT"),
    )
    # Required in non-dev. Empty token rejects all authenticated routes.
    musiq_worker_token: str = Field(default="", alias="MUSIQ_WORKER_TOKEN")
    allow_insecure_empty_token: bool = Field(
        default=False,
        alias="ALLOW_INSECURE_EMPTY_TOKEN",
    )

    max_image_bytes: int = Field(default=15 * 1024 * 1024, alias="MAX_IMAGE_BYTES")
    max_video_bytes: int = Field(default=80 * 1024 * 1024, alias="MAX_VIDEO_BYTES")
    request_timeout_sec: float = Field(default=120.0, alias="REQUEST_TIMEOUT_SEC")
    video_sample_frames: int = Field(default=4, alias="VIDEO_SAMPLE_FRAMES")

    tfhub_cache_dir: str = Field(default="/models/tfhub", alias="TFHUB_CACHE_DIR")
    musiq_handle: str = Field(
        default="https://tfhub.dev/google/musiq/paq2piq/1",
        alias="MUSIQ_HANDLE",
    )
    cuda_visible_devices: str = Field(default="-1", alias="CUDA_VISIBLE_DEVICES")
    preload_musiq: bool = Field(default=True, alias="PRELOAD_MUSIQ")


@lru_cache
def get_settings() -> WorkerSettings:
    return WorkerSettings()


def apply_runtime_env(settings: WorkerSettings | None = None) -> None:
    cfg = settings or get_settings()
    os.environ.setdefault("CUDA_VISIBLE_DEVICES", cfg.cuda_visible_devices)
    os.environ.setdefault("TFHUB_CACHE_DIR", cfg.tfhub_cache_dir)
    # Keep PORT and WORKER_PORT aligned for healthchecks / entrypoint.
    os.environ["PORT"] = str(cfg.worker_port)
    os.environ["WORKER_PORT"] = str(cfg.worker_port)
    os.environ.setdefault("WORKER_HOST", cfg.worker_host)
