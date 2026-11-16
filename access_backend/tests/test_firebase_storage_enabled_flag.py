"""Firebase Storage opt-out via FIREBASE_STORAGE_ENABLED=false."""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

from app.services import firebase_storage


def test_firebase_storage_respects_explicit_disable_even_with_service_account(tmp_path: Path):
    sa = tmp_path / "fake-sa.json"
    sa.write_text("{}", encoding="utf-8")
    with patch.object(
        firebase_storage.settings,
        "firebase_storage_bucket",
        "some-bucket",
    ), patch.object(
        firebase_storage.settings,
        "firebase_service_account_json",
        str(sa),
    ), patch.object(
        firebase_storage.settings,
        "firebase_storage_enabled",
        "false",
    ):
        assert firebase_storage.is_firebase_storage_configured() is False
