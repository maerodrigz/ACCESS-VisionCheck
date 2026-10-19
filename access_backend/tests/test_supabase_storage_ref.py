"""Compact Supabase refs must fit DB file_url and resolve to HTTPS for clients."""

from app.services.supabase_storage import (
    SUPABASE_STORAGE_REF_PREFIX,
    is_supabase_storage_ref,
    object_path_from_supabase_url,
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
