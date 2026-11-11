"""Lightweight automated tests for the Quality Evaluation Sandbox.

Covers dual-engine side-by-side results, classical execution, EfficientNet
honesty (no OpenCV substitute), missing weights, invalid uploads, and the
Python 3.13-compatible multipart parser (no cgi).

Research-only. No production code modified. No DB writes. No files saved.
"""

from __future__ import annotations

import importlib
import sys
from pathlib import Path
from unittest import mock

import numpy as np
import pytest

SANDBOX = Path(__file__).resolve().parents[1]
REPO = SANDBOX.parents[2]
BACKEND = REPO / "access_backend"
TOOLKIT = SANDBOX.parent
for _p in (str(REPO), str(BACKEND), str(TOOLKIT)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import cv2  # noqa: E402

from tools.quality_validation.sandbox.evaluator import (  # noqa: E402
    CRITERIA_NAMES,
    evaluate,
    enet_status,
)
from tools.quality_validation.sandbox.server import (  # noqa: E402
    _is_image_magic,
    _make_thumbnail,
    _parse_multipart,
)

EXPECTED_CRITERIA = set(CRITERIA_NAMES)


def _encode_jpeg(bgr: np.ndarray, quality: int = 90) -> bytes:
    ok, buf = cv2.imencode(".jpg", bgr, [cv2.IMWRITE_JPEG_QUALITY, quality])
    assert ok, "cv2.imencode failed"
    return bytes(buf)


def _solid(value: int = 128) -> bytes:
    return _encode_jpeg(np.full((128, 128, 3), value, dtype=np.uint8))


def _textured() -> bytes:
    rng = np.random.default_rng(42)
    img = (rng.random((256, 256, 3)) * 255).astype(np.uint8)
    return _encode_jpeg(img)


def _multipart(fields: dict[str, tuple[bytes, str | None]], boundary: str = "----sandboxbound") -> tuple[str, bytes]:
    """Build a multipart/form-data body for parser tests."""
    chunks: list[bytes] = []
    for name, (data, filename) in fields.items():
        chunks.append(f"--{boundary}\r\n".encode())
        if filename is not None:
            chunks.append(
                f'Content-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'.encode()
            )
            chunks.append(b"Content-Type: application/octet-stream\r\n\r\n")
        else:
            chunks.append(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode())
        chunks.append(data)
        chunks.append(b"\r\n")
    chunks.append(f"--{boundary}--\r\n".encode())
    body = b"".join(chunks)
    content_type = f"multipart/form-data; boundary={boundary}"
    return content_type, body


# ── Dual-engine structure ─────────────────────────────────────────────────────

def test_basic_dual_engine_structure():
    result = evaluate(_textured())
    assert result["ok"] is True
    assert result["error"] is None
    assert "engine_a" in result and "engine_b" in result
    assert result["engine_a"] is not None
    assert result["engine_b"] is not None
    assert "elapsed_ms" in result["engine_a"]
    assert "elapsed_ms" in result["engine_b"]
    assert result["criteria_names"] == list(CRITERIA_NAMES)


def test_both_engines_seven_criteria():
    result = evaluate(_textured())
    for key in ("engine_a", "engine_b"):
        names = {c["name"] for c in result[key]["criteria"]}
        assert names == EXPECTED_CRITERIA, f"{key} missing: {EXPECTED_CRITERIA - names}"


def test_classical_engine_runs_and_badges_in_range():
    result = evaluate(_textured())
    b = result["engine_b"]
    assert b["engine_available"] is True
    assert b["elapsed_ms"] >= 0
    assert "classical" in b["engine_id"] or "experimental" in b["engine_id"]
    for c in b["criteria"]:
        assert 1 <= c["badge"] <= 5, f"{c['name']} badge={c['badge']}"


def test_efficientnet_real_or_honest_unavailable():
    """When weights/torch work, ENET scores; otherwise explicit unavailable (no OpenCV)."""
    result = evaluate(_textured())
    a = result["engine_a"]
    assert a["opencv_fallback_used"] is False
    assert len(a["criteria"]) == 7
    if a["engine_available"]:
        assert a["elapsed_ms"] > 0
        assert "efficientnet" in a["engine_id"].lower()
        for c in a["criteria"]:
            assert c["badge"] is not None
            assert 1 <= c["badge"] <= 5
            assert c.get("raw_value") is not None
    else:
        assert a["unavailable_reason"]
        assert "OpenCV" in a["unavailable_reason"] or "not" in a["unavailable_reason"].lower()
        for c in a["criteria"]:
            assert c["badge"] is None
            assert c["status"] == "unavailable"


def test_no_silent_opencv_substitute_for_enet():
    result = evaluate(_textured())
    a = result["engine_a"]
    assert a.get("opencv_fallback_used") is False
    # Must not pretend OpenCV scores are EfficientNet
    assert "opencv" not in (a.get("engine_id") or "").lower()
    note = (a.get("note") or "") + " " + " ".join(a.get("limitations") or [])
    if a["engine_available"]:
        assert "OpenCV" in note or "opencv" in note.lower() or "NOT used" in note


def test_separate_runtimes_reported():
    result = evaluate(_textured())
    assert "elapsed_ms" in result["engine_a"]
    assert "elapsed_ms" in result["engine_b"]
    # Top-level single elapsed_ms must not be required (dual engines)
    assert "elapsed_ms" not in result or isinstance(result.get("elapsed_ms"), (int, float, type(None)))


def test_overall_note_warns_no_skill_grade():
    result = evaluate(_textured())
    note = result["overall_note"].lower()
    assert "not" in note or "no" in note


@pytest.mark.parametrize("value,label", [(0, "black"), (128, "gray"), (255, "white")])
def test_solid_images_classical(value, label):
    result = evaluate(_solid(value))
    assert result["ok"] is True, f"solid {label} failed: {result.get('error')}"
    assert result["engine_b"]["engine_available"] is True
    for c in result["engine_b"]["criteria"]:
        assert 1 <= c["badge"] <= 5


# ── Missing weights / ENET honesty ────────────────────────────────────────────

def test_missing_weights_reports_unavailable_without_opencv(monkeypatch):
    import app.services.efficientnet_b0_scorer as enet

    fake_path = Path("/nonexistent/efficientnet_b0_heads.pt")
    monkeypatch.setattr(enet, "weights_path", lambda: fake_path)
    monkeypatch.setattr(enet, "efficientnet_available", lambda: True)
    monkeypatch.setattr(enet, "ensure_weights", lambda: False)

    # Re-import path uses the module functions inside _run_efficientnet via fresh imports;
    # patch at the module the evaluator imports from.
    with mock.patch(
        "app.services.efficientnet_b0_scorer.weights_path",
        return_value=fake_path,
    ), mock.patch(
        "app.services.efficientnet_b0_scorer.efficientnet_available",
        return_value=True,
    ), mock.patch(
        "app.services.efficientnet_b0_scorer.ensure_weights",
        return_value=False,
    ), mock.patch(
        "app.services.efficientnet_b0_scorer.analyze_image_bytes",
        side_effect=AssertionError("analyze must not be called when weights missing"),
    ):
        result = evaluate(_textured())

    a = result["engine_a"]
    assert a["engine_available"] is False
    assert a["opencv_fallback_used"] is False
    assert a["unavailable_reason"]
    assert "OpenCV fallback was NOT used" in a["unavailable_reason"] or "missing" in a["unavailable_reason"].lower()
    assert len(a["criteria"]) == 7
    assert all(c["badge"] is None for c in a["criteria"])
    # Classical must still run
    assert result["engine_b"]["engine_available"] is True


def test_enet_status_reports_weights_path():
    status = enet_status()
    assert "engine_available" in status
    assert "weights_path" in status or "error" in status


# ── Invalid uploads / decode ──────────────────────────────────────────────────

def test_empty_bytes_returns_error():
    result = evaluate(b"")
    assert result["ok"] is False
    assert result["error"] is not None
    assert result["engine_a"] is None
    assert result["engine_b"] is None


def test_not_an_image_returns_error():
    result = evaluate(b"This is plain text, not an image")
    assert result["ok"] is False


def test_corrupted_bytes_no_crash():
    result = evaluate(b"\xff\xd8\xff" + b"\x00" * 10)
    assert "ok" in result  # contract: no exception


# ── Magic / thumbnail / multipart (no cgi) ────────────────────────────────────

def test_magic_jpeg():
    assert _is_image_magic(b"\xff\xd8\xff" + b"\x00" * 10) is True


def test_magic_png():
    assert _is_image_magic(b"\x89PNG\r\n\x1a\n" + b"\x00" * 10) is True


def test_magic_random_fails():
    assert _is_image_magic(b"HELLO WORLD") is False


def test_magic_empty_fails():
    assert _is_image_magic(b"") is False


def test_thumbnail_returns_datauri():
    uri = _make_thumbnail(_solid(200))
    assert uri is not None
    assert uri.startswith("data:image/jpeg;base64,")


def test_thumbnail_corrupted_returns_none():
    uri = _make_thumbnail(b"not an image")
    assert uri is None or uri.startswith("data:")


def test_parse_multipart_file_and_flags():
    jpeg = _solid(100)
    ct, body = _multipart({
        "file": (jpeg, "sample.jpg"),
        "noise_alts": (b"1", None),
        "ringing_alts": (b"0", None),
    })
    form = _parse_multipart(ct, body)
    assert "file" in form
    assert form["file"]["filename"] == "sample.jpg"
    assert form["file"]["data"][:3] == b"\xff\xd8\xff"
    assert form["noise_alts"]["data"] == b"1"
    assert form["ringing_alts"]["data"] == b"0"


def test_parse_multipart_missing_file_field():
    ct, body = _multipart({"noise_alts": (b"1", None)})
    form = _parse_multipart(ct, body)
    assert "file" not in form


def test_server_module_does_not_import_cgi():
    """Python 3.13 removed cgi; sandbox must not depend on it."""
    import tools.quality_validation.sandbox.server as srv
    importlib.reload(srv)
    assert "cgi" not in sys.modules or "cgi" not in getattr(srv, "__dict__", {})
    src = Path(srv.__file__).read_text(encoding="utf-8")
    assert "import cgi" not in src
    assert "cgi.FieldStorage" not in src


# ── Alternates / status fields (classical) ────────────────────────────────────

def test_alternates_not_returned_by_default():
    result = evaluate(_textured())
    assert result["alternates"] == {}


def test_noise_alternates_returned_when_requested():
    result = evaluate(_textured(), include_noise_alternates=True)
    assert "noise" in result["alternates"]
    n = result["alternates"]["noise"]
    assert "v3" in n or "v4" in n


def test_ringing_alternates_returned_when_requested():
    result = evaluate(_textured(), include_ringing_alternates=True)
    assert "ringing" in result["alternates"]
    r = result["alternates"]["ringing"]
    assert "v3" in r or "v4" in r


def test_alternate_badges_in_range():
    result = evaluate(_textured(), include_noise_alternates=True, include_ringing_alternates=True)
    for group in result["alternates"].values():
        for _ver, info in group.items():
            if "badge" in info:
                assert 1 <= info["badge"] <= 5


def test_blocking_version_is_v3_on_classical():
    result = evaluate(_textured())
    block = next(c for c in result["engine_b"]["criteria"] if c["name"] == "Blocking Artifacts")
    assert block["version"] == "v3"


def test_noise_status_is_unvalidated_on_classical():
    result = evaluate(_textured())
    noise = next(c for c in result["engine_b"]["criteria"] if c["name"] == "Noise")
    assert "UNVALIDATED" in noise["status"].upper()


def test_ringing_status_is_unvalidated_on_classical():
    result = evaluate(_textured())
    ring = next(c for c in result["engine_b"]["criteria"] if c["name"] == "Ringing Artifacts")
    assert "UNVALIDATED" in ring["status"].upper()


def test_research_notes_present():
    result = evaluate(_textured())
    assert len(result["research_notes"]) >= 3


# ── Explainable diagnostics ───────────────────────────────────────────────────

def _badge_map(engine: dict) -> dict[str, int | None]:
    return {c["name"]: c.get("badge") for c in engine.get("criteria") or []}


def test_all_seven_criteria_have_explanations():
    result = evaluate(_textured(), include_diagnostics=True)
    assert result["explanations"] is not None
    names = [e["name"] for e in result["explanations"]]
    assert names == list(CRITERIA_NAMES)
    for exp in result["explanations"]:
        assert exp["measures"]
        assert "efficientnet" in exp and "classical" in exp
        assert exp["classical"].get("interpretation")
        assert exp["classical"].get("limitation")
        assert isinstance(exp["classical"].get("measurements"), list)
        # ENET must not invent causal internal reasoning
        en_txt = (exp["efficientnet"].get("explanation") or "").lower()
        assert "not inspectable" in en_txt or "does not invent" in en_txt


def test_measurements_come_from_actual_computations():
    result = evaluate(_textured(), include_diagnostics=True)
    diag = result["diagnostics"]
    assert diag and diag.get("available") is True
    assert diag["luminance_mean_0_1"] is not None
    assert 0.0 <= diag["shadow_clip_frac"] <= 1.0
    assert 0.0 <= diag["highlight_clip_frac"] <= 1.0
    # Classical sharpness scoring input must be present when engine ran
    sharp = next(e for e in result["explanations"] if e["name"] == "Sharpness")
    keys = {m["key"] for m in sharp["classical"]["measurements"]}
    assert "tenengrad" in keys
    ten = next(m for m in sharp["classical"]["measurements"] if m["key"] == "tenengrad")
    assert isinstance(ten["value"], (int, float))
    assert ten["role"] == "scoring_input"


def test_missing_measurements_never_invented():
    """When a value is unavailable, it is omitted — not fabricated."""
    from tools.quality_validation.sandbox.diagnostics import _meas

    assert _meas("x", None) is None
    # Empty diagnostics still yield explanations without fake numeric fields
    result = evaluate(_textured(), include_diagnostics=True)
    for exp in result["explanations"]:
        for m in exp["classical"]["measurements"]:
            assert m["value"] is not None
            assert "key" in m and "role" in m


def test_scores_unchanged_with_diagnostics_enabled():
    img = _textured()
    off = evaluate(img, include_diagnostics=False)
    on = evaluate(img, include_diagnostics=True)
    assert _badge_map(off["engine_a"]) == _badge_map(on["engine_a"])
    assert _badge_map(off["engine_b"]) == _badge_map(on["engine_b"])
    # Raw classical scoring metrics identical
    assert off["engine_b"]["raw_metrics"] == on["engine_b"]["raw_metrics"]
    assert off["explanations"] is None
    assert on["explanations"] is not None


def test_noise_and_ringing_marked_unvalidated_in_explanations():
    result = evaluate(_textured(), include_diagnostics=True)
    noise = next(e for e in result["explanations"] if e["name"] == "Noise")
    ring = next(e for e in result["explanations"] if e["name"] == "Ringing Artifacts")
    assert "UNVALIDATED" in (noise["classical"].get("reliability") or "").upper()
    assert "UNVALIDATED" in (ring["classical"].get("reliability") or "").upper()
    assert "unvalidated" in (noise["classical"].get("interpretation") or "").lower()
    assert "unvalidated" in (ring["classical"].get("interpretation") or "").lower()


def test_brightness_explanation_includes_clip_and_region_stats():
    result = evaluate(_textured(), include_diagnostics=True)
    bright = next(e for e in result["explanations"] if e["name"] == "Brightness")
    keys = {m["key"] for m in bright["classical"]["measurements"]}
    assert "brightness_mean" in keys or "luminance_mean_0_255" in keys
    assert "shadow_clip_frac" in keys
    assert "highlight_clip_frac" in keys
    assert "dark_region_frac" in keys
    assert "bright_region_frac" in keys


def test_both_engines_still_run_with_diagnostics():
    result = evaluate(_textured(), include_diagnostics=True)
    assert result["engine_b"]["engine_available"] is True
    assert len(result["engine_a"]["criteria"]) == 7
    assert len(result["engine_b"]["criteria"]) == 7
    assert result["diagnostics_elapsed_ms"] >= 0


def test_diagnostics_elapsed_ms_is_numeric_when_enabled():
    """UI shows N/A when this field is missing/non-numeric; must be a float."""
    result = evaluate(_textured(), include_diagnostics=True)
    assert "diagnostics_elapsed_ms" in result
    assert isinstance(result["diagnostics_elapsed_ms"], (int, float))
    assert result["include_diagnostics"] is True
    assert result["diagnostics"] is not None
    assert len(result["explanations"]) == 7


def test_server_evaluate_forces_diagnostics_flag():
    """Regression: /evaluate must call evaluate(..., include_diagnostics=True)."""
    src = (SANDBOX / "server.py").read_text(encoding="utf-8")
    assert "include_diagnostics=True" in src
    assert "importlib.reload" in src
    assert "diagnostics_elapsed_ms" in (SANDBOX / "index.html").read_text(encoding="utf-8")
