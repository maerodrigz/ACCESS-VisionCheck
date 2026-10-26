"""Feedback-only color balance and composition insights (no rubric scores)."""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

from app.services.opencv_quality import decode_image

InsightDict = dict[str, str]


def _unavailable_insight(kind: str) -> InsightDict:
    return {
        "status": "unavailable",
        "headline": "Unavailable",
        "feedback": f"{kind} analysis could not be run on this file.",
    }


def _inconclusive_insight(kind: str, feedback: str) -> InsightDict:
    return {
        "status": "inconclusive",
        "headline": "Inconclusive",
        "feedback": feedback,
    }


def analyze_color_balance_bgr(bgr: np.ndarray) -> InsightDict:
    if cv2 is None:
        return _unavailable_insight("Color balance")

    h, w = bgr.shape[:2]
    if h < 16 or w < 16:
        return _inconclusive_insight(
            "Color balance",
            "The image is too small for a reliable color balance read.",
        )

    lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB)
    a_chan = lab[:, :, 1].astype(np.float32)
    b_chan = lab[:, :, 2].astype(np.float32)
    a_dev = float(a_chan.mean() - 128.0)
    b_dev = float(b_chan.mean() - 128.0)

    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    saturation = float(hsv[:, :, 1].mean()) / 255.0
    lightness = float(lab[:, :, 0].mean()) / 255.0

    b, g, r = cv2.split(bgr.astype(np.float32))
    rg = float(r.mean() - g.mean())
    bg = float(b.mean() - g.mean())

    if saturation < 0.07:
        return _inconclusive_insight(
            "Color balance",
            "Low color variation or monochrome lighting makes white balance assessment inconclusive. "
            "This is not treated as poor quality.",
        )
    if lightness < 0.10 or lightness > 0.93:
        return _inconclusive_insight(
            "Color balance",
            "Very dark or bright exposure makes color cast detection inconclusive.",
        )

    warm_lab = (a_dev / 35.0) * 0.35 + (b_dev / 35.0) * 0.65
    warm_rgb = (rg / 40.0) * 0.45 + (-bg / 40.0) * 0.35
    warm_signal = warm_lab * 0.65 + warm_rgb * 0.35

    if abs(warm_signal) < 0.14:
        return {
            "status": "neutral",
            "headline": "Balanced",
            "feedback": "Color channels look reasonably balanced for this scene. "
            "Warm or cool lighting may still be intentional.",
        }

    if 0.14 <= warm_signal < 0.24:
        return {
            "status": "neutral",
            "headline": "Slight tint",
            "feedback": "A mild warm or cool tint is present. This can be normal for indoor or sunset lighting.",
        }

    if warm_signal >= 0.24:
        return {
            "status": "warm_cast",
            "headline": "Warm cast",
            "feedback": "Noticeable warm color cast detected. Consider adjusting white balance if natural colors are intended.",
        }

    if warm_signal <= -0.24:
        return {
            "status": "cool_cast",
            "headline": "Cool cast",
            "feedback": "Noticeable cool color cast detected. Consider adjusting white balance if natural colors are intended.",
        }

    return {
        "status": "neutral",
        "headline": "Balanced",
        "feedback": "No strong color cast detected beyond normal scene lighting.",
    }


def analyze_composition_framing_bgr(bgr: np.ndarray) -> InsightDict:
    if cv2 is None:
        return _unavailable_insight("Composition")

    h, w = bgr.shape[:2]
    if h < 24 or w < 24:
        return _inconclusive_insight(
            "Composition",
            "The image is too small to estimate subject placement reliably.",
        )

    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    lap = cv2.Laplacian(gray, cv2.CV_64F)
    strength = np.abs(lap)
    threshold = float(np.percentile(strength, 93))
    if threshold < 4.0:
        return _inconclusive_insight(
            "Composition",
            "No clear salient region was detected, so framing feedback is inconclusive.",
        )

    mask = (strength >= threshold).astype(np.uint8)
    active = int(mask.sum())
    if active < max(24, int(0.004 * h * w)):
        return _inconclusive_insight(
            "Composition",
            "Visual detail is too uniform to identify a main subject area for framing hints.",
        )

    ys, xs = np.where(mask > 0)
    x_min, x_max = int(xs.min()), int(xs.max())
    y_min, y_max = int(ys.min()), int(ys.max())
    box_w = (x_max - x_min + 1) / w
    box_h = (y_max - y_min + 1) / h

    margin_x = 0.06
    margin_y = 0.06
    near_left = x_min / w < margin_x
    near_right = (w - 1 - x_max) / w < margin_x
    near_top = y_min / h < margin_y
    near_bottom = (h - 1 - y_max) / h < margin_y
    near_edge = near_left or near_right or near_top or near_bottom

    if near_edge and (box_w >= 0.12 or box_h >= 0.12):
        edges: list[str] = []
        if near_left:
            edges.append("left")
        if near_right:
            edges.append("right")
        if near_top:
            edges.append("top")
        if near_bottom:
            edges.append("bottom")
        edge_text = ", ".join(edges)
        return {
            "status": "edge_proximity",
            "headline": "Check framing",
            "feedback": "The main visual area appears close to the frame edge "
            f"({edge_text}). Consider checking the framing to ensure important details remain visible.",
        }

    cx = ((x_min + x_max) / 2.0) / w
    cy = ((y_min + y_max) / 2.0) / h
    centered = abs(cx - 0.5) <= 0.20 and abs(cy - 0.5) <= 0.20
    if centered:
        return {
            "status": "acceptable",
            "headline": "Centered subject",
            "feedback": "The main visual activity is near the center. Centered framing is acceptable for documentation.",
        }

    return {
        "status": "acceptable",
        "headline": "Acceptable",
        "feedback": "No strong edge-clipping signal was detected. This is a lightweight check, not artistic judgment.",
    }


def analyze_color_balance_bytes(content: bytes) -> InsightDict:
    bgr = decode_image(content)
    if bgr is None:
        return _unavailable_insight("Color balance")
    return analyze_color_balance_bgr(bgr)


def analyze_composition_framing_bytes(content: bytes) -> InsightDict:
    bgr = decode_image(content)
    if bgr is None:
        return _unavailable_insight("Composition")
    return analyze_composition_framing_bgr(bgr)


def _aggregate_color_insights(frames: list[InsightDict]) -> InsightDict:
    usable = [f for f in frames if f.get("status") not in ("unavailable",)]
    if not usable:
        return _unavailable_insight("Color balance")
    if len(usable) < 2:
        return _inconclusive_insight(
            "Color balance",
            "Too few usable video frames for a stable color balance summary.",
        )

    statuses = [str(f.get("status") or "") for f in usable]
    inconclusive_ratio = statuses.count("inconclusive") / len(statuses)
    if inconclusive_ratio >= 0.6:
        return _inconclusive_insight(
            "Color balance",
            "Frame-to-frame lighting variation makes color balance feedback inconclusive for this clip.",
        )

    warm = statuses.count("warm_cast")
    cool = statuses.count("cool_cast")
    neutral = statuses.count("neutral")

    if warm >= max(2, len(usable) // 2):
        return {
            "status": "warm_cast",
            "headline": "Warm cast",
            "feedback": "Noticeable warm color cast detected across sampled frames. "
            "Consider adjusting white balance if natural colors are intended.",
        }
    if cool >= max(2, len(usable) // 2):
        return {
            "status": "cool_cast",
            "headline": "Cool cast",
            "feedback": "Noticeable cool color cast detected across sampled frames. "
            "Consider adjusting white balance if natural colors are intended.",
        }
    if neutral >= len(usable) * 0.5:
        return usable[0] if usable[0].get("status") == "neutral" else {
            "status": "neutral",
            "headline": "Balanced",
            "feedback": "Sampled frames look reasonably balanced overall. Scene lighting may still add intentional tint.",
        }
    return _inconclusive_insight(
        "Color balance",
        "Mixed color cues across frames; no single cast summary is reported.",
    )


def _aggregate_composition_insights(frames: list[InsightDict]) -> InsightDict:
    usable = [f for f in frames if f.get("status") != "unavailable"]
    if not usable:
        return _unavailable_insight("Composition")
    if len(usable) < 2:
        return _inconclusive_insight(
            "Composition",
            "Too few usable video frames for a stable framing summary.",
        )

    if any(f.get("status") == "edge_proximity" for f in usable):
        sample = next(f for f in usable if f.get("status") == "edge_proximity")
        return {
            "status": "edge_proximity",
            "headline": "Check framing",
            "feedback": sample.get("feedback")
            or "A sampled frame shows the main visual area close to an edge. Review framing before submitting.",
        }

    inconclusive_ratio = sum(1 for f in usable if f.get("status") == "inconclusive") / len(usable)
    if inconclusive_ratio >= 0.75:
        return _inconclusive_insight(
            "Composition",
            "Sampled frames did not provide a consistent subject region for framing feedback.",
        )

    return {
        "status": "acceptable",
        "headline": "Acceptable",
        "feedback": "No consistent edge-clipping pattern across sampled frames. This is a lightweight check, not artistic judgment.",
    }


def build_photo_supplementary_insights(content: bytes) -> dict[str, Any] | None:
    if not content:
        return None
    color = analyze_color_balance_bytes(content)
    composition = analyze_composition_framing_bytes(content)
    return _pack_insights(color, composition, media_type="photo", frames_analyzed=1)


def build_video_supplementary_insights(
    frame_bytes_list: list[bytes],
    *,
    video_content: bytes | None = None,
    video_ext: str = ".mp4",
) -> dict[str, Any] | None:
    if not frame_bytes_list:
        return None
    color_frames: list[InsightDict] = []
    comp_frames: list[InsightDict] = []
    decoded = 0
    for raw in frame_bytes_list:
        bgr = decode_image(raw)
        if bgr is None:
            continue
        decoded += 1
        color_frames.append(analyze_color_balance_bgr(bgr))
        comp_frames.append(analyze_composition_framing_bgr(bgr))

    if decoded == 0:
        return None

    if decoded < 2:
        bgr0 = decode_image(frame_bytes_list[0])
        color = analyze_color_balance_bgr(bgr0) if bgr0 is not None else _unavailable_insight("Color balance")
        composition = analyze_composition_framing_bgr(bgr0) if bgr0 is not None else _unavailable_insight("Composition")
    else:
        color = _aggregate_color_insights(color_frames)
        composition = _aggregate_composition_insights(comp_frames)

    motion: InsightDict | None = None
    if video_content:
        from app.services.video_motion_stability_insights import analyze_video_motion_stability_bytes

        motion = analyze_video_motion_stability_bytes(video_content, video_ext)

    return _pack_insights(
        color,
        composition,
        media_type="video",
        frames_analyzed=decoded,
        motion_stability=motion,
    )


def _pack_insights(
    color: InsightDict,
    composition: InsightDict,
    *,
    media_type: str,
    frames_analyzed: int,
    motion_stability: InsightDict | None = None,
) -> dict[str, Any] | None:
    motion = motion_stability
    if (
        color.get("status") == "unavailable"
        and composition.get("status") == "unavailable"
        and (motion is None or motion.get("status") == "unavailable")
    ):
        return None
    payload: dict[str, Any] = {
        "color_balance": color,
        "composition_framing": composition,
        "media_type": media_type,
        "frames_analyzed": frames_analyzed,
        "feedback_only": True,
    }
    if motion is not None and motion.get("status") != "unavailable":
        payload["motion_stability"] = motion
    return payload
