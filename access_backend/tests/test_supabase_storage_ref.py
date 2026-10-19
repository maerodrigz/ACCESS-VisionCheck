"""Compact Supabase refs must fit DB file_url and resolve to HTTPS for clients."""

from app.services import supabase_storage as storage
from app.services.supabase_storage import (
    SUPABASE_STORAGE_REF_PREFIX,
    is_supabase_storage_ref,
    object_path_from_supabase_url,
    resolve_supabase_storage_urls,
    supabase_storage_ref,
)


def test_supabase_storage_ref_is_short():
    ref = supabase_storage_ref(
        "access-media",
        "access-visioncheck/media/42/abc123def456.jpg",
    )
    assert ref.startswith(SUPABASE_STORAGE_REF_PREFIX)
    assert len(ref) < 200
    assert is_supabase_storage_ref(ref)


def test_object_path_from_supabase_ref():
    ref = supabase_storage_ref("access-media", "access-visioncheck/media/1/x.png")
    parsed = object_path_from_supabase_url(ref)
    assert parsed == ("access-media", "access-visioncheck/media/1/x.png")


class _FakeResp:
    def __init__(self, code: int, payload: dict | None = None):
        self.status_code = code
        self.text = ""
        self._payload = payload or {}

    def json(self):
        return self._payload


def test_batch_resolve_probes_private_bucket_once(monkeypatch):
    storage._bucket_is_public.clear()
    heads = {"n": 0}
    posts = {"n": 0}

    class FakeClient:
        def __init__(self, timeout=30):
            self.timeout = timeout

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        def head(self, url, headers=None):
            heads["n"] += 1
            return _FakeResp(400)

        def post(self, url, headers=None, json=None):
            posts["n"] += 1
            return _FakeResp(200, {"signedURL": "/storage/v1/object/sign/access-media/a.jpg?token=t"})

    monkeypatch.setattr(storage, "is_supabase_storage_configured", lambda: True)
    monkeypatch.setattr(storage, "_base_url", lambda: "https://proj.supabase.co")
    monkeypatch.setattr(storage, "_headers", lambda: {})
    monkeypatch.setattr(storage.httpx, "Client", FakeClient)

    refs = [
        supabase_storage_ref("access-media", "access-visioncheck/media/1/a.jpg"),
        supabase_storage_ref("access-media", "access-visioncheck/media/1/b.jpg"),
        "https://cdn.example/plain.jpg",
    ]
    out = resolve_supabase_storage_urls(refs)
    assert heads["n"] == 1
    assert posts["n"] == 2
    assert out[0].startswith("https://proj.supabase.co/storage/v1/object/sign/")
    assert "token=t" in out[0]
    assert out[1].startswith("https://proj.supabase.co/storage/v1/object/sign/")
    assert out[2] == "https://cdn.example/plain.jpg"

    again = resolve_supabase_storage_urls(refs[:2])
    assert heads["n"] == 1
    assert posts["n"] == 4
    assert again[0].startswith("https://proj.supabase.co/")
    storage._bucket_is_public.clear()
