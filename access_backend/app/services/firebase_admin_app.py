"""Shared Firebase Admin SDK init for FCM push and optional Storage."""

from __future__ import annotations

from pathlib import Path

from app.config import settings

_FIREBASE_APP = None


def _service_account_path() -> Path | None:
    sa = (settings.firebase_service_account_json or "").strip()
    if not sa:
        return None
    path = Path(sa)
    return path if path.is_file() else None


def is_firebase_admin_configured() -> bool:
    """True when Admin SDK can start (service account file or ADC + storage flag)."""
    if _service_account_path() is not None:
        return True
    return bool((settings.firebase_storage_enabled or "").strip().lower() in ("1", "true", "yes"))


def is_fcm_configured() -> bool:
    """Push only needs Admin credentials; Storage UI / Blaze upgrade not required."""
    return is_firebase_admin_configured()


def ensure_firebase_admin_app():
    global _FIREBASE_APP
    if _FIREBASE_APP is not None:
        return _FIREBASE_APP
    if not is_firebase_admin_configured():
        return None

    import firebase_admin
    from firebase_admin import credentials

    try:
        _FIREBASE_APP = firebase_admin.get_app()
        return _FIREBASE_APP
    except ValueError:
        pass

    sa_path = _service_account_path()
    if sa_path is not None:
        cred = credentials.Certificate(str(sa_path))
    else:
        cred = credentials.ApplicationDefault()

    bucket = (settings.firebase_storage_bucket or "").strip()
    if bucket:
        _FIREBASE_APP = firebase_admin.initialize_app(cred, {"storageBucket": bucket})
    else:
        _FIREBASE_APP = firebase_admin.initialize_app(cred)
    return _FIREBASE_APP
