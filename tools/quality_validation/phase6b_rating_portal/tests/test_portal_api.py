"""Local API tests for Phase 6B portal (no MUSIQ worker required)."""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

IMAGES = (
    ROOT.parents[0]
    / "workspace"
    / "phase6a_human_validation"
    / "rater_pack"
    / "images"
)


@pytest.fixture()
def client(tmp_path, monkeypatch):
    if not (IMAGES / "INDVAL-001.jpg").is_file():
        pytest.skip("Phase 6A INDVAL images not present")

    db_path = tmp_path / "test.sqlite3"
    monkeypatch.setenv("DATABASE_PATH", str(db_path))
    monkeypatch.setenv("IMAGES_DIR", str(IMAGES))
    monkeypatch.setenv(
        "EVALUATOR_INVITES",
        "R1:test-invite-r1-aaaaaaaa,R2:test-invite-r2-bbbbbbbb,R3:test-invite-r3-cccccccc",
    )
    monkeypatch.setenv("FACILITATOR_TOKEN", "test-facilitator-token-zzzz")
    monkeypatch.setenv("ALLOW_BOOTSTRAP_WITHOUT_SECRETS", "false")

    from app import config

    config.get_settings.cache_clear()

    import importlib

    import app.main as main_mod

    importlib.reload(main_mod)
    config.get_settings.cache_clear()
    importlib.reload(main_mod)

    with TestClient(main_mod.app) as c:
        yield c


def test_health(client: TestClient):
    r = client.get("/api/health")
    assert r.status_code == 200
    body = r.json()
    assert body["musiq_worker_required"] is False
    assert body["n_images_on_disk"] >= 1


def test_evaluator_isolation_and_autosave(client: TestClient):
    r1 = client.post("/api/auth/exchange", json={"invite_token": "test-invite-r1-aaaaaaaa"})
    assert r1.status_code == 200
    s1 = r1.json()["session_token"]
    assert r1.json()["evaluator_id"] == "R1"

    r2 = client.post("/api/auth/exchange", json={"invite_token": "test-invite-r2-bbbbbbbb"})
    s2 = r2.json()["session_token"]

    # R1 saves a rating
    payload = {
        "media_id": "INDVAL-001",
        "ratings": {"sharpness": 4, "blur": 5},
        "notes": "",
        "mark_complete": False,
    }
    save = client.put(
        "/api/ratings/INDVAL-001",
        json=payload,
        headers={"X-Session-Token": s1},
    )
    assert save.status_code == 200
    assert save.json()["saved"]["ratings"]["sharpness"] == 4

    # R2 must not see R1 ratings
    other = client.get("/api/ratings/INDVAL-001", headers={"X-Session-Token": s2})
    assert other.status_code == 200
    assert other.json()["ratings"] == {}

    # Image requires auth
    naked = client.get("/api/images/INDVAL-001.jpg")
    assert naked.status_code == 401
    img = client.get("/api/images/INDVAL-001.jpg", headers={"X-Session-Token": s1})
    assert img.status_code == 200
    assert img.headers["content-type"].startswith("image/jpeg")


def test_facilitator_export(client: TestClient):
    r1 = client.post("/api/auth/exchange", json={"invite_token": "test-invite-r1-aaaaaaaa"})
    s1 = r1.json()["session_token"]
    client.put(
        "/api/ratings/INDVAL-001",
        json={
            "media_id": "INDVAL-001",
            "ratings": {
                "sharpness": 3,
                "blur": 3,
                "noise": 3,
                "brightness": 3,
                "contrast": 3,
                "blocking_artifacts": 3,
                "ringing_artifacts": 3,
                "overall_visual_quality": 3,
            },
            "mark_complete": True,
        },
        headers={"X-Session-Token": s1},
    )
    bad = client.get("/api/facilitator/export.csv")
    assert bad.status_code in (403, 503)
    ok = client.get(
        "/api/facilitator/export.csv?evaluator_id=R1",
        headers={"X-Facilitator-Token": "test-facilitator-token-zzzz"},
    )
    assert ok.status_code == 200
    text = ok.text
    assert "media_id,rater_id,media_type,sharpness" in text
    assert "INDVAL-001,R1,photo,3" in text


def test_invalid_invite(client: TestClient):
    r = client.post("/api/auth/exchange", json={"invite_token": "not-a-real-token-xxx"})
    assert r.status_code == 401
