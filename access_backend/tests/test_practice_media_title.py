import pytest
from fastapi import HTTPException

from app.services.media_upload_config import (
    PRACTICE_MEDIA_TITLE_MAX_LEN,
    assert_practice_media_title,
    normalize_practice_media_title,
)


def test_normalize_practice_media_title_trims() -> None:
    assert normalize_practice_media_title("  Hello  ") == "Hello"


def test_assert_practice_media_title_requires_non_empty() -> None:
    with pytest.raises(HTTPException) as exc:
        assert_practice_media_title("   ")
    assert exc.value.status_code == 422


def test_assert_practice_media_title_max_length() -> None:
    with pytest.raises(HTTPException) as exc:
        assert_practice_media_title("x" * (PRACTICE_MEDIA_TITLE_MAX_LEN + 1))
    assert exc.value.status_code == 422


def test_assert_practice_media_title_ok() -> None:
    title = "Sunset at the Beach"
    assert assert_practice_media_title(title) == title
