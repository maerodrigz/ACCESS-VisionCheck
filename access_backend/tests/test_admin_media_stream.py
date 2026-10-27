"""Admin authenticated media stream (disk-backed previews)."""

from __future__ import annotations

import os
import uuid
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import settings
from app.database import SessionLocal
from main import app
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_file import MediaFile
from app.models.user import User


@pytest.fixture()
def client() -> TestClient:
    # TrustedHostMiddleware rejects TestClient default host "testserver".
    return TestClient(app, base_url="http://127.0.0.1")


def _admin_token(client: TestClient) -> str:
    r = client.post(
        "/api/auth/login",
        json={"email": "admin@access.edu", "password": "admin123"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    return body.get("token") or body["access_token"]


def test_admin_stream_requires_auth(client: TestClient) -> None:
    r = client.get("/api/admin/media/1/stream")
    assert r.status_code == 401


def test_admin_stream_missing_media_404(client: TestClient) -> None:
    token = _admin_token(client)
    r = client.get(
        "/api/admin/media/999999999/stream",
        params={"access_token": token},
    )
    assert r.status_code == 404


def test_admin_stream_missing_file_on_disk_404(client: TestClient) -> None:
    if os.environ.get("ACCESS_PYTEST_DB", "").strip() != "access_waverep_test":
        pytest.skip("Isolated DB only")

    db = SessionLocal()
    try:
        member = db.query(User).filter(User.status == "approved").first()
        assert member is not None
        media = MediaFile(
            uploaded_by=member.id,
            file_name="ghost.jpg",
            file_type="photo",
            file_url="/uploads/images/does_not_exist_ghost.jpg",
            media_category=MEDIA_CATEGORY_EVALUATION,
        )
        db.add(media)
        db.commit()
        db.refresh(media)
        media_id = media.id
    finally:
        db.close()

    token = _admin_token(client)
    r = client.get(
        f"/api/admin/media/{media_id}/stream",
        params={"access_token": token},
    )
    assert r.status_code == 404
    assert "unavailable" in r.text.lower() or "not found" in r.text.lower()


def test_admin_stream_serves_disk_file(client: TestClient) -> None:
    if os.environ.get("ACCESS_PYTEST_DB", "").strip() != "access_waverep_test":
        pytest.skip("Isolated DB only")

    upload_root = Path(settings.upload_dir)
    upload_root.mkdir(parents=True, exist_ok=True)
    (upload_root / "images").mkdir(exist_ok=True)
    rel = f"images/stream_test_{uuid.uuid4().hex[:8]}.jpg"
    blob = upload_root / rel
    blob.write_bytes(b"\xff\xd8\xff\xd9")

    db = SessionLocal()
    try:
        member = db.query(User).filter(User.status == "approved").first()
        assert member is not None
        media = MediaFile(
            uploaded_by=member.id,
            file_name="stream_test.jpg",
            file_type="photo",
            file_url=f"/uploads/{rel}",
            media_category=MEDIA_CATEGORY_EVALUATION,
        )
        db.add(media)
        db.commit()
        db.refresh(media)
        media_id = media.id
    finally:
        db.close()

    token = _admin_token(client)
    ok = client.get(
        f"/api/admin/media/{media_id}/stream",
        params={"access_token": token},
    )
    assert ok.status_code == 200
    assert ok.headers.get("content-type", "").startswith("image/")
    assert len(ok.content) >= 4

    from app.core.security import hash_password
    from app.models.enums import RoleName
    from app.models.role import Role

    db = SessionLocal()
    try:
        role = db.query(Role).filter(Role.role_name == RoleName.MEMBER).first()
        assert role is not None
        email = f"stream_nonadmin_{uuid.uuid4().hex[:8]}@example.com"
        non_admin = User(
            email=email,
            fullname="Stream Non Admin",
            password=hash_password("stream-test-only"),
            role_id=role.id,
            status="approved",
        )
        db.add(non_admin)
        db.commit()
    finally:
        db.close()

    member_token = client.post(
        "/api/auth/login",
        json={"email": email, "password": "stream-test-only"},
    )
    assert member_token.status_code == 200, member_token.text
    mt = member_token.json().get("token") or member_token.json().get("access_token")
    denied = client.get(
        f"/api/admin/media/{media_id}/stream",
        params={"access_token": mt},
    )
    assert denied.status_code == 403

    blob.unlink(missing_ok=True)


def test_admin_stream_serves_root_and_replacement_by_media_id(client: TestClient) -> None:
    """Each chain media row streams via its own media_id (original vs replacement)."""
    if os.environ.get("ACCESS_PYTEST_DB", "").strip() != "access_waverep_test":
        pytest.skip("Isolated DB only")

    upload_root = Path(settings.upload_dir)
    upload_root.mkdir(parents=True, exist_ok=True)
    (upload_root / "images").mkdir(exist_ok=True)
    tag = uuid.uuid4().hex[:8]
    root_rel = f"images/root_stream_{tag}.jpg"
    rep_rel = f"images/rep_stream_{tag}.jpg"
    (upload_root / root_rel).write_bytes(b"\xff\xd8\xff\xd9root")
    (upload_root / rep_rel).write_bytes(b"\xff\xd8\xff\xd9repl")

    db = SessionLocal()
    try:
        member = db.query(User).filter(User.status == "approved").first()
        assert member is not None
        root = MediaFile(
            uploaded_by=member.id,
            file_name="root.jpg",
            file_type="photo",
            file_url=f"/uploads/{root_rel}",
            media_category=MEDIA_CATEGORY_EVALUATION,
        )
        db.add(root)
        db.flush()
        rep = MediaFile(
            uploaded_by=member.id,
            file_name="replacement.jpg",
            file_type="photo",
            file_url=f"/uploads/{rep_rel}",
            media_category=MEDIA_CATEGORY_EVALUATION,
            replaces_media_id=root.id,
        )
        db.add(rep)
        db.commit()
        db.refresh(root)
        db.refresh(rep)
        root_id, rep_id = root.id, rep.id
    finally:
        db.close()

    token = _admin_token(client)
    for mid, needle in ((root_id, b"root"), (rep_id, b"repl")):
        r = client.get(
            f"/api/admin/media/{mid}/stream",
            params={"access_token": token},
        )
        assert r.status_code == 200, (mid, r.text)
        assert needle in r.content

    (upload_root / root_rel).unlink(missing_ok=True)
    (upload_root / rep_rel).unlink(missing_ok=True)
