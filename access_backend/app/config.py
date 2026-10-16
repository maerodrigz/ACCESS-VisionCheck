"""Application settings loaded from environment variables."""

from pathlib import Path
import os

from dotenv import load_dotenv
from pydantic import Field, computed_field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = BACKEND_ROOT / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE),
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    # PostgreSQL — use DB_* names (Windows has USERNAME=YourPCName in env)
    db_host: str = Field(default="localhost", alias="DB_HOST")
    db_port: int = Field(default=5432, alias="DB_PORT")
    db_username: str = Field(default="postgres", alias="DB_USERNAME")
    db_password: str = Field(default="", alias="DB_PASSWORD")
    db_name: str = Field(default="access", alias="DB_NAME")

    database_url_override: str | None = Field(default=None, alias="DATABASE_URL")

    jwt_secret: str = "access_visioncheck_dev_secret"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 10080

    # Bind address (0.0.0.0 = listen on all interfaces for LAN/mobile access)
    api_host: str = Field(default="0.0.0.0", alias="API_HOST")
    api_port: int = Field(default=3001, alias="API_PORT")
    # LAN IP shown to Flutter apps (Admin Web + Android)
    api_public_host: str = Field(default="192.168.137.162", alias="API_PUBLIC_HOST")

    # Comma-separated Host header values (TrustedHostMiddleware). The defaults
    # keep both the current and the previously-used LAN IPs so a laptop that
    # roams between Wi-Fi networks keeps working without re-editing the file.
    allowed_hosts: str = Field(
        default=(
            "192.168.137.162,192.168.137.162:3001,"
            "192.168.0.137,192.168.0.137:3001,"
            "10.0.22.98,10.0.22.98:3001,"
            "localhost,localhost:3001,"
            "127.0.0.1,127.0.0.1:3001"
        ),
        alias="ALLOWED_HOSTS",
    )

    cors_origins: str = Field(
        default=(
            "http://192.168.137.162:3001,"
            "http://192.168.137.162,"
            "http://192.168.0.137:3001,"
            "http://192.168.0.137,"
            "http://10.0.22.98:3001,"
            "http://10.0.22.98,"
            "http://localhost:3001,"
            "http://127.0.0.1:3001,"
            "http://localhost,"
            "http://127.0.0.1"
        ),
        alias="CORS_ORIGINS",
    )
    upload_dir: str = "uploads"
    max_upload_mb: int = 100
    # Practice evaluation uploads (short clips; can exceed 100 MB at higher quality).
    evaluation_max_upload_mb: int = Field(default=350, alias="EVALUATION_MAX_UPLOAD_MB")
    evaluation_max_video_seconds: int = Field(default=30, alias="EVALUATION_MAX_VIDEO_SECONDS")

    # Firebase Storage — photos/videos (optional; mobile can also send cloud_file_url)
    firebase_storage_bucket: str = Field(default="", alias="FIREBASE_STORAGE_BUCKET")
    firebase_service_account_json: str = Field(default="", alias="FIREBASE_SERVICE_ACCOUNT_JSON")
    firebase_storage_enabled: str = Field(default="", alias="FIREBASE_STORAGE_ENABLED")

    # Supabase Storage — canonical photos/videos when enabled
    supabase_url: str = Field(default="", alias="SUPABASE_URL")
    supabase_service_role_key: str = Field(default="", alias="SUPABASE_SERVICE_ROLE_KEY")
    supabase_storage_bucket: str = Field(default="", alias="SUPABASE_STORAGE_BUCKET")
    supabase_storage_enabled: str = Field(default="", alias="SUPABASE_STORAGE_ENABLED")
    supabase_max_upload_mb: int = Field(default=50, alias="SUPABASE_MAX_UPLOAD_MB")
    supabase_service_role_key_file: str = Field(
        default="secrets/supabase-service-role.key",
        alias="SUPABASE_SERVICE_ROLE_KEY_FILE",
    )

    facebook_app_id: str = Field(default="", alias="FACEBOOK_APP_ID")
    facebook_client_token: str = Field(default="", alias="FACEBOOK_CLIENT_TOKEN")
    facebook_page_id: str = Field(default="1202339146306816", alias="FACEBOOK_PAGE_ID")
    facebook_page_access_token: str = Field(default="", alias="FACEBOOK_PAGE_ACCESS_TOKEN")
    # Optional: target album for bulk photo publish (Meta blocks creating albums via API).
    facebook_page_album_id: str = Field(default="", alias="FACEBOOK_PAGE_ALBUM_ID")

    gemini_api_key: str = Field(default="", alias="GEMINI_API_KEY")
    gemini_model: str = Field(default="gemini-3-flash-preview", alias="GEMINI_MODEL")

    # Dedicated AI detector backend: probe (PROBE-DINOv2 @ 1344px cap) or univfd.
    ai_detector_backend: str = Field(default="probe", alias="AI_DETECTOR_BACKEND")
    probe_max_long_edge: int = Field(default=1344, alias="PROBE_MAX_LONG_EDGE")
    probe_checkpoint_path: str = Field(default="", alias="PROBE_CHECKPOINT_PATH")
    probe_low_risk_threshold: float = Field(default=0.30, alias="PROBE_LOW_RISK_THRESHOLD")
    probe_high_risk_threshold: float = Field(default=0.45, alias="PROBE_HIGH_RISK_THRESHOLD")

    max_media_evaluation_workers: int = Field(default=1, alias="MAX_MEDIA_EVALUATION_WORKERS")

    # IANA timezone for practice evaluation daily upload cap (midnight boundary).
    evaluation_daily_timezone: str = Field(default="Asia/Manila", alias="EVALUATION_DAILY_TIMEZONE")

    # Outbound email (SMTP) — registration approve/reject and related alerts
    email_enabled: bool = Field(default=False, alias="EMAIL_ENABLED")
    smtp_host: str = Field(default="", alias="SMTP_HOST")
    smtp_port: int = Field(default=587, alias="SMTP_PORT")
    smtp_username: str = Field(default="", alias="SMTP_USERNAME")
    smtp_password: str = Field(default="", alias="SMTP_PASSWORD")
    smtp_use_tls: bool = Field(default=True, alias="SMTP_USE_TLS")
    email_from: str = Field(default="", alias="EMAIL_FROM")
    email_from_name: str = Field(default="ACCESS VisionCheck", alias="EMAIL_FROM_NAME")
    email_reply_to: str = Field(default="", alias="EMAIL_REPLY_TO")
    email_logo_path: str = Field(default="", alias="EMAIL_LOGO_PATH")

    # Registration SMS OTP (member / requestor mobile signup)
    sms_provider: str = Field(default="log", alias="SMS_PROVIDER")
    semaphore_api_key: str = Field(default="", alias="SEMAPHORE_API_KEY")
    sms_sender_name: str = Field(default="ACCESS", alias="SMS_SENDER_NAME")
    sms_otp_expire_minutes: int = Field(default=10, alias="SMS_OTP_EXPIRE_MINUTES")
    sms_otp_token_minutes: int = Field(default=30, alias="SMS_OTP_TOKEN_MINUTES")
    sms_otp_resend_seconds: int = Field(default=60, alias="SMS_OTP_RESEND_SECONDS")
    sms_otp_max_attempts: int = Field(default=5, alias="SMS_OTP_MAX_ATTEMPTS")

    @model_validator(mode="after")
    def _validate_probe_risk_thresholds(self) -> "Settings":
        low = float(self.probe_low_risk_threshold)
        high = float(self.probe_high_risk_threshold)
        if not (0.0 <= low < high <= 1.0):
            raise ValueError("PROBE_LOW_RISK_THRESHOLD and PROBE_HIGH_RISK_THRESHOLD must satisfy 0 <= LOW < HIGH <= 1")
        return self

    @model_validator(mode="after")
    def _load_supabase_service_role_from_file(self) -> "Settings":
        if (self.supabase_service_role_key or "").strip():
            return self
        rel = (self.supabase_service_role_key_file or "").strip()
        if not rel:
            return self
        path = BACKEND_ROOT / rel
        if not path.is_file():
            return self
        text = path.read_text(encoding="utf-8").strip()
        if text and not text.startswith("#"):
            self.supabase_service_role_key = text
        return self

    @computed_field
    @property
    def database_url(self) -> str:
        if self.database_url_override:
            return self.database_url_override
        return (
            f"postgresql+psycopg://{self.db_username}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def allowed_host_list(self) -> list[str]:
        if self.allowed_hosts.strip() == "*":
            return ["*"]
        return [h.strip() for h in self.allowed_hosts.split(",") if h.strip()]

    @property
    def public_api_url(self) -> str:
        return f"http://{self.api_public_host}:{self.api_port}"


settings = Settings()


def reload_dotenv_file() -> None:
    """Reload access_backend/.env into os.environ (dev: pick up edits without full restart)."""
    if ENV_FILE.is_file():
        load_dotenv(ENV_FILE, override=True)


def facebook_credentials() -> tuple[str, str]:
    """Page ID + access token, re-read from .env each call."""
    reload_dotenv_file()
    page_id = (os.getenv("FACEBOOK_PAGE_ID") or settings.facebook_page_id or "").strip()
    token = (os.getenv("FACEBOOK_PAGE_ACCESS_TOKEN") or settings.facebook_page_access_token or "").strip()
    return page_id, token
