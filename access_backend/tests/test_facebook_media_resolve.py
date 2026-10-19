"""Facebook publish must resolve Supabase storage refs, not treat them as local paths."""

from app.services.facebook_service import resolve_image_source
from app.services.supabase_storage import supabase_storage_ref


def test_resolve_image_source_supabase_ref_returns_https(monkeypatch):
    ref = supabase_storage_ref("access-media", "access-visioncheck/media/1/photo.jpg")
    signed = "https://example.supabase.co/storage/v1/object/sign/access-media/x?token=abc"

    monkeypatch.setattr(
        "app.services.supabase_storage.normalize_supabase_storage_url",
        lambda _url: signed,
    )

    public_url, local_path = resolve_image_source(ref, "photo")
    assert public_url == signed
    assert local_path is None


def test_resolve_image_source_supabase_ref_falls_back_to_temp_file(monkeypatch, tmp_path):
    ref = supabase_storage_ref("access-media", "access-visioncheck/media/1/photo.jpg")

    monkeypatch.setattr(
        "app.services.supabase_storage.normalize_supabase_storage_url",
        lambda url: url,
    )
    monkeypatch.setattr(
        "app.services.media_file_bytes.read_media_file_bytes",
        lambda _url, timeout=120.0: b"\xff\xd8\xff",
    )

    public_url, local_path = resolve_image_source(ref, "photo")
    assert public_url is None
    assert local_path is not None
    assert local_path.is_file()
    local_path.unlink(missing_ok=True)
