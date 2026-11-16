"""Render/Heroku PORT env must drive bind port when --port is omitted."""

from __future__ import annotations

from pathlib import Path

from manage import _resolve_bind_port


def test_cli_port_wins_over_env(monkeypatch):
    monkeypatch.setenv("PORT", "9999")
    assert _resolve_bind_port(3001) == 3001


def test_port_env_used_when_cli_omitted(monkeypatch):
    monkeypatch.setenv("PORT", "10000")
    assert _resolve_bind_port(None) == 10000


def test_falls_back_to_settings_api_port(monkeypatch):
    monkeypatch.delenv("PORT", raising=False)
    from app.config import settings

    assert _resolve_bind_port(None) == int(settings.api_port)


def test_manage_py_documents_port_helpers():
    src = Path(__file__).resolve().parents[1] / "manage.py"
    text = src.read_text(encoding="utf-8")
    assert "--no-reload" in text
    assert "_resolve_bind_port" in text
