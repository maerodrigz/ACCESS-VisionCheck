"""Production Settings / path-safety guards (no threshold or model changes)."""

from __future__ import annotations

from pathlib import Path

import pytest
from pydantic import ValidationError

from app.config import Settings
from app.services import media_file_bytes

_STRONG_JWT = "unit-test-jwt-secret-not-for-production-use-01"


def _prod_kwargs(**extra):
    base = dict(
        _env_file=None,
        APP_ENV="production",
        AUTH_LOCKOUT_ENABLED=True,
        JWT_SECRET=_STRONG_JWT,
        SMS_PROVIDER="textbee",
        EMAIL_ENABLED=True,
        DB_PASSWORD="unit-test-db-password",
        CORS_ORIGINS="https://admin.example.com",
        ALLOWED_HOSTS="api.example.com,127.0.0.1",
    )
    base.update(extra)
    return base


def test_production_refuses_wildcard_cors():
    with pytest.raises(ValidationError) as exc:
        Settings(**_prod_kwargs(CORS_ORIGINS="*"))
    assert "CORS_ORIGINS" in str(exc.value)


def test_production_refuses_wildcard_hosts():
    with pytest.raises(ValidationError) as exc:
        Settings(**_prod_kwargs(ALLOWED_HOSTS="*"))
    assert "ALLOWED_HOSTS" in str(exc.value)


def test_production_refuses_sms_log_provider():
    with pytest.raises(ValidationError) as exc:
        Settings(**_prod_kwargs(SMS_PROVIDER="log"))
    assert "SMS_PROVIDER=log" in str(exc.value)


def test_production_refuses_email_disabled():
    with pytest.raises(ValidationError) as exc:
        Settings(**_prod_kwargs(EMAIL_ENABLED=False))
    assert "EMAIL_ENABLED=false" in str(exc.value)


def test_local_media_path_rejects_traversal(tmp_path, monkeypatch):
    upload = tmp_path / "uploads"
    upload.mkdir()
    secret = tmp_path / "secret.txt"
    secret.write_text("nope", encoding="utf-8")
    (upload / "ok.jpg").write_bytes(b"img")

    monkeypatch.setattr(media_file_bytes.settings, "upload_dir", str(upload))

    assert media_file_bytes.local_media_path("/uploads/ok.jpg") is not None
    assert media_file_bytes.local_media_path("/uploads/../secret.txt") is None
    assert media_file_bytes.local_media_path("https://evil.example/uploads/../secret.txt") is None
