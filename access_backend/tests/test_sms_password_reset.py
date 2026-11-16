"""Unit tests for SMS password reset helpers (no live TextBee / no DB mutation of prod)."""

from __future__ import annotations

import hashlib

import pytest

from app.config import settings
from app.crud.sms_otp_common import generate_otp_code, hash_otp
from app.services.phone_normalize import normalize_ph_mobile
from app.services import sms_rate_limit


def test_otp_code_is_six_digits():
    for _ in range(20):
        code = generate_otp_code()
        assert code.isdigit() and len(code) == 6


def test_otp_hash_is_stable_and_not_plaintext():
    code = "123456"
    h1 = hash_otp(code)
    h2 = hash_otp(code)
    assert h1 == h2
    assert h1 != code
    pepper = settings.jwt_secret or "access_otp_pepper"
    assert h1 == hashlib.sha256(f"{pepper}:{code}".encode()).hexdigest()


def test_ph_normalize_for_reset():
    assert normalize_ph_mobile("09811284867") == "+639811284867"


def test_rate_limit_blocks_after_limit():
    sms_rate_limit.reset_for_tests()
    key = "test-ip-limit"
    for _ in range(3):
        sms_rate_limit.check_and_record(key=key, limit=3, window_s=3600.0)
    with pytest.raises(ValueError, match="Too many"):
        sms_rate_limit.check_and_record(key=key, limit=3, window_s=3600.0)
    sms_rate_limit.reset_for_tests()
