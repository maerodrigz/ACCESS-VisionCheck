"""Member media stream: auth, Range/206, and private Supabase redirect."""

from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from starlette.applications import Starlette
from starlette.responses import FileResponse
from starlette.routing import Route
from starlette.testclient import TestClient as StarletteTestClient

from app.api.deps import get_current_user, require_approved
from app.core.security import create_access_token
from app.models.enums import RoleName
from app.services.media_stream_response import file_response_from_bytes
from main import app


@pytest.fixture()
def client() -> TestClient:
    return TestClient(app, base_url="http://127.0.0.1")


def _media(**kwargs):
    base = dict(
        id=42,
        uploaded_by=7,
        file_name="clip.mp4",
        file_type="video",
        file_url="/uploads/videos/clip.mp4",
        media_category="evaluation",
        approval_status=None,
        storage_removed_at=None,
    )
    base.update(kwargs)
    return SimpleNamespace(**base)


def _auth_user() -> SimpleNamespace:
    return SimpleNamespace(
        id=7,
        status="approved",
        is_active=True,
        role=SimpleNamespace(role_name=RoleName.MEMBER),
    )


@pytest.fixture()
def authed_client(client: TestClient):
    user = _auth_user()
    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[require_approved] = lambda: user
    try:
        yield client, user
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(require_approved, None)


def test_file_response_from_bytes_honors_http_range() -> None:
    payload = b"ABCDEFGHIJKLMNOP" * 64

    def endpoint(_request):
        return file_response_from_bytes(
            payload,
            media_type="video/mp4",
            filename="clip.mp4",
            suffix=".mp4",
        )

    mini = Starlette(routes=[Route("/v", endpoint)])
    c = StarletteTestClient(mini)
    full = c.get("/v")
    assert full.status_code == 200
    assert isinstance(
        file_response_from_bytes(payload, media_type="video/mp4", suffix=".mp4"),
        FileResponse,
    )
    ranged = c.get("/v", headers={"Range": "bytes=0-15"})
    assert ranged.status_code == 206
    assert ranged.headers.get("content-range", "").startswith("bytes 0-15/")
    assert ranged.content == b"ABCDEFGHIJKLMNOP"


def test_member_stream_requires_auth(client: TestClient) -> None:
    r = client.get("/api/media/1/stream")
    assert r.status_code in (401, 403)


def test_member_stream_local_video_range_206(authed_client, tmp_path: Path) -> None:
    client, user = authed_client
    blob = tmp_path / "local.mp4"
    blob.write_bytes(b"\x00\x00\x00\x18ftypmp42" + (b"\x00" * 4096))
    media = _media(file_url=str(blob), uploaded_by=user.id)

    with (
        patch("app.api.routes.media.media_crud.get", return_value=media),
        patch(
            "app.api.routes.media.normalize_supabase_storage_url",
            return_value=str(blob),
        ),
        patch("app.services.media_file_bytes.local_media_path", return_value=blob),
    ):
        # Any bearer string is fine while get_current_user is overridden.
        token = create_access_token({"userId": user.id, "role": "member"})
        headers = {"Authorization": f"Bearer {token}"}
        full = client.get("/api/media/42/stream", headers=headers)
        assert full.status_code == 200, full.text
        assert "video" in (full.headers.get("content-type") or "").lower()

        ranged = client.get(
            "/api/media/42/stream",
            headers={**headers, "Range": "bytes=0-15"},
        )
        assert ranged.status_code == 206, ranged.text
        assert ranged.headers.get("content-range", "").startswith("bytes 0-15/")
        assert len(ranged.content) == 16


def test_member_stream_supabase_https_redirects_without_exposing_public_bucket(
    authed_client,
) -> None:
    client, user = authed_client
    signed = "https://example.supabase.co/storage/v1/object/sign/access-media/clip.mp4?token=abc"
    media = _media(
        file_url="supabase-ref:access-media/access-visioncheck/media/1/clip.mp4",
        uploaded_by=user.id,
    )
    token = create_access_token({"userId": user.id, "role": "member"})

    with (
        patch("app.api.routes.media.media_crud.get", return_value=media),
        patch(
            "app.api.routes.media.normalize_supabase_storage_url",
            return_value=signed,
        ),
        patch("app.services.media_file_bytes.local_media_path", return_value=None),
    ):
        r = client.get(
            "/api/media/42/stream",
            headers={"Authorization": f"Bearer {token}"},
            follow_redirects=False,
        )
    assert r.status_code == 307, r.text
    assert r.headers.get("location") == signed


def test_buffered_bytes_fallback_uses_file_response() -> None:
    content = b"0123456789" * 200
    resp = file_response_from_bytes(content, media_type="video/mp4", filename="x.mp4", suffix=".mp4")
    assert isinstance(resp, FileResponse)
    assert Path(resp.path).exists()
