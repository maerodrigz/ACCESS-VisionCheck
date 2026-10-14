import pytest

from app.services.phone_normalize import normalize_ph_mobile


def test_normalize_local_09():
    assert normalize_ph_mobile("09171234567") == "+639171234567"


def test_normalize_with_spaces():
    assert normalize_ph_mobile("09 17 123 4567") == "+639171234567"


def test_normalize_already_e164():
    assert normalize_ph_mobile("+639171234567") == "+639171234567"


def test_normalize_invalid():
    with pytest.raises(ValueError):
        normalize_ph_mobile("12345")
