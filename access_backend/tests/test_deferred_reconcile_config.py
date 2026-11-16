"""Deferred pipeline startup reconcile configuration."""

from unittest.mock import patch

from app.config import settings
from app.services import deferred_media_pipeline as dep


def test_reconcile_skipped_when_disabled(monkeypatch) -> None:
    monkeypatch.setattr(settings, "deferred_reconcile_on_startup", False)
    assert dep.reconcile_pending_media_evaluations() == 0
