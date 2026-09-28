"""Regression tests: authenticity detail must not repeat verdict boilerplate."""

from app.services.ai_authenticity_detector import (
    _build_detail,
    _detail_base,
    _finalize_detection_detail,
)

AUTHENTIC_BASE = "No strong AI-generation indicators detected."


def _assert_single_authentic_base(detail: str) -> None:
    assert detail.count(AUTHENTIC_BASE) == 1, detail


def test_photo_reasons_no_duplicate_base() -> None:
    detail = _build_detail(
        "authentic",
        [
            "Noise is unusually uniform across the frame.",
            "Portrait regions look unnaturally smooth compared to edge detail.",
        ],
        0.28,
    )
    _assert_single_authentic_base(detail)
    assert "Noise is unusually uniform" in detail
    assert "Portrait regions" in detail


def test_photo_reason_embedded_boilerplate_stripped() -> None:
    detail = _build_detail(
        "authentic",
        [
            f"{AUTHENTIC_BASE} Noise is unusually uniform across the frame.",
            "Portrait regions look unnaturally smooth compared to edge detail.",
        ],
        0.28,
    )
    _assert_single_authentic_base(detail)


def test_finalize_repairs_legacy_duplicate_string() -> None:
    messy = (
        f"{AUTHENTIC_BASE} {AUTHENTIC_BASE} "
        "Noise is unusually uniform across the frame. "
        "Portrait regions look unnaturally smooth compared to edge detail."
    )
    detail = _finalize_detection_detail(messy, "authentic", 0.28)
    _assert_single_authentic_base(detail)


def test_suspicious_detail_no_duplicate_prefix() -> None:
    base = _detail_base("suspicious", 0.45)
    messy = f"{base} {base} Unusual frequency patterns common in synthetic images."
    detail = _finalize_detection_detail(messy, "suspicious", 0.45)
    assert detail.count("Possible AI-generated or heavily edited media") == 1
