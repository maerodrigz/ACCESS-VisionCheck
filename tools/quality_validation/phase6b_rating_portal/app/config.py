"""Portal configuration. Secrets come from environment only."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_PORTAL_ROOT = Path(__file__).resolve().parents[1]
_DEFAULT_IMAGES = (
    _PORTAL_ROOT.parents[0]
    / "workspace"
    / "phase6a_human_validation"
    / "rater_pack"
    / "images"
)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "ACCESS VisionCheck Phase 6B Rating Portal"
    host: str = "0.0.0.0"
    port: int = 8090
    database_path: str = str(_PORTAL_ROOT / "data" / "ratings.sqlite3")
    images_dir: str = str(_DEFAULT_IMAGES)
    # Comma-separated invite tokens: R1:<token>,R2:<token>,R3:<token>
    evaluator_invites: str = ""
    facilitator_token: str = ""
    # Optional public base URL for invite links in bootstrap output
    public_base_url: str = "http://127.0.0.1:8090"
    cors_origins: str = "*"
    allow_bootstrap_without_secrets: bool = False


@lru_cache
def get_settings() -> Settings:
    return Settings()
