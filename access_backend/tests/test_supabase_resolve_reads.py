"""Supabase ref resolution for member reads when upload flag is off."""

from __future__ import annotations

import unittest
from unittest.mock import patch

from app.services.supabase_storage import (
    can_resolve_supabase_storage,
    normalize_supabase_storage_url,
)


class SupabaseResolveReadsTest(unittest.TestCase):
    def test_can_resolve_independent_of_upload_flag(self) -> None:
        with patch("app.services.supabase_storage.settings") as mock_settings:
            mock_settings.supabase_url = "https://example.supabase.co"
            mock_settings.supabase_service_role_key = "secret"
            mock_settings.supabase_storage_bucket = "access-media"
            mock_settings.supabase_storage_enabled = ""
            self.assertTrue(can_resolve_supabase_storage())

    def test_ref_resolves_when_credentials_present(self) -> None:
        ref = "supabase-ref:access-media/access-visioncheck/media/1/abc.jpg"
        signed = "https://example.supabase.co/storage/v1/object/sign/access-media/access-visioncheck/media/1/abc.jpg"
        with patch("app.services.supabase_storage.can_resolve_supabase_storage", return_value=True):
            with patch(
                "app.services.supabase_storage._resolve_ref_with_client",
                return_value=signed,
            ):
                out = normalize_supabase_storage_url(ref)
        self.assertTrue(out.startswith("https://"))


if __name__ == "__main__":
    unittest.main()
