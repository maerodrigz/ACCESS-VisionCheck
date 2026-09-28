"""Deterministic image quality metrics for media evaluation (same bytes → same scores)."""

from __future__ import annotations

import json
import math
from io import BytesIO
from typing import Any

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    Image = None  # type: ignore


def _soft_score(metric: float) -> int:
    boosted = max(0.0, min(1.0, metric * 0.5 + 0.42))
    if boosted >= 0.80:
        return 5
    if boosted >= 0.64:
        return 4
    if boosted >= 0.46:
        return 3
    if boosted >= 0.28:
        return 2
    return 1


def analyze_bytes(content: bytes) -> dict[str, Any] | None:
    if Image is None or not content:
        return None
    try:
        im = Image.open(BytesIO(content)).convert("RGB")
    except Exception:
        return None
    w, h = im.size
    if w < 1 or h < 1:
        return None

    step_x = max(1, w // 48)
    step_y = max(1, h // 48)
    lum: list[float] = []
    r_vals: list[int] = []
    g_vals: list[int] = []
    b_vals: list[int] = []
    edge_sum = 0.0
    edge_count = 0
    left_edge = 0.0
    right_edge = 0.0
    center_edge = 0.0
    pixels = im.load()

    for y in range(0, h - step_y, step_y):
        for x in range(0, w - step_x, step_x):
            r, g, b = pixels[x, y][:3]
            r_vals.append(r)
            g_vals.append(g)
            b_vals.append(b)
            l = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            lum.append(l)
            if x + step_x < w and y + step_y < h:
                r2, g2, b2 = pixels[x + step_x, y + step_y][:3]
                l2 = (0.299 * r2 + 0.587 * g2 + 0.114 * b2) / 255.0
                diff = abs(l - l2)
                edge_sum += diff
                edge_count += 1
                cx = x / w
                if cx < 0.33:
                    left_edge += diff
                elif cx > 0.66:
                    right_edge += diff
                else:
                    center_edge += diff

    mean_lum = sum(lum) / len(lum) if lum else 0.5
    variance = sum((v - mean_lum) ** 2 for v in lum) / len(lum) if lum else 0.0
    blur_score = (edge_sum / edge_count) if edge_count else 0.0

    def ch_mean(vals: list[int]) -> float:
        return sum(vals) / len(vals) if vals else 0.0

    r_m, g_m, b_m = ch_mean(r_vals), ch_mean(g_vals), ch_mean(b_vals)
    max_c = max(r_m, g_m, b_m)
    min_c = min(r_m, g_m, b_m)
    color_balance = 1 - (max_c - min_c) / max_c if max_c else 1.0
    edge_balance = (
        1 - abs(left_edge - right_edge) / (left_edge + right_edge + 0.001)
        if (left_edge + right_edge) > 0
        else 0.5
    )
    center_ratio = (center_edge / (edge_sum + 0.001)) if edge_sum else 0.5
    subject_clarity = max(0.0, min(1.0, blur_score * 0.55 + center_ratio * 0.45))
    overexposed = sum(1 for v in lum if v > 0.92) / len(lum) if lum else 0.0
    contrast = math.sqrt(variance)

    pixels_count = w * h
    if pixels_count >= 1920 * 1080:
        resolution_score = 1.0
    elif pixels_count >= 1280 * 720:
        resolution_score = 0.85
    elif pixels_count >= 640 * 480:
        resolution_score = 0.65
    else:
        resolution_score = 0.4

    metrics = {
        "blur_score": blur_score,
        "brightness": mean_lum,
        "contrast": contrast,
        "color_balance": color_balance,
        "edge_balance": edge_balance,
        "noise_level": overexposed,
        "subject_clarity": subject_clarity,
        "resolution_score": resolution_score,
        "width": w,
        "height": h,
    }
    return build_evaluation_payload(metrics)


def build_evaluation_payload(m: dict[str, Any]) -> dict[str, Any]:
    criteria = [
        _criterion("Composition and Framing", _soft_score(m["edge_balance"] * 0.6 + m["resolution_score"] * 0.4, 0.35, 0.8)),
        _criterion("Lighting and Exposure", _soft_score(max(0, 1 - abs(m["brightness"] - 0.48) * 2.2 - (0.15 if m["noise_level"] > 0.15 else 0)), 0.3, 0.75)),
        _criterion("Focus and Sharpness", _soft_score(m["blur_score"], 0.28, 0.78)),
        _criterion("Color and White Balance", _soft_score(m["color_balance"] * 0.7 + m["contrast"] * 0.3, 0.32, 0.78)),
        _criterion("Subject Clarity", _soft_score(m["subject_clarity"], 0.3, 0.8)),
        _criterion("Creativity and Storytelling", _soft_score(m["contrast"] * 0.4 + m["edge_balance"] * 0.35 + m["subject_clarity"] * 0.25, 0.32, 0.72)),
        _criterion("Relevance to Event Theme", _soft_score(m["resolution_score"] * 0.35 + m["subject_clarity"] * 0.45 + m["brightness"] * 0.2, 0.35, 0.78)),
        _criterion("Technical Quality", _soft_score(max(0, m["blur_score"] * 0.35 + m["resolution_score"] * 0.35 + m["contrast"] * 0.2 + m["color_balance"] * 0.1 - (0.2 if m["noise_level"] > 0.2 else 0)), 0.3, 0.78)),
        _criterion("Overall Documentation Value", _soft_score(max(0, m["blur_score"] * 0.25 + min(m["brightness"], 0.75) * 0.2 + m["subject_clarity"] * 0.3 + m["resolution_score"] * 0.25), 0.32, 0.8)),
    ]
    overall = round(sum(c["score"] for c in criteria) / len(criteria), 2)
    quality_level = (
        "Excellent" if overall >= 4.5 else "Good" if overall >= 3.5 else "Fair" if overall >= 2.5 else "Needs Improvement"
    )
    recommendation = (
        "Accepted" if overall >= 3.6
        else "Accepted with Suggestions" if overall >= 2.4
        else "For Officer Review"
    )
    strengths = [c["name"] for c in criteria if c["score"] >= 4]
    weaknesses = [c["name"] for c in criteria if c["score"] <= 2]
    feedback = f"Overall documentation quality is {quality_level} ({overall}/5)."
    if strengths:
        feedback += f" Strengths: {', '.join(strengths)}."
    if weaknesses:
        feedback += f" Areas to improve: {', '.join(weaknesses)}."
    feedback += f" Final recommendation: {recommendation}."

    suspicious = (m["noise_level"] > 0.35 and m["blur_score"] < 0.35) or (
        m["contrast"] < 0.08 and m["color_balance"] > 0.95
    )
    ai_detection = {
        "verdict": "suspicious" if suspicious else "authentic",
        "confidence": 0.62 if suspicious else min(0.98, 0.75 + m["blur_score"] * 0.15 + m["contrast"] * 0.1),
        "detail": (
            "Suspicious indicators detected. Officers will review this submission carefully."
            if suspicious
            else "No strong AI-generation artifacts detected from image statistics."
        ),
    }

    by_name = {c["name"]: c["score"] for c in criteria}
    return {
        "criteria": criteria,
        "overall_score": overall,
        "quality_level": quality_level,
        "recommendation": recommendation,
        "ai_feedback": feedback,
        "improvement_suggestions": "; ".join(c["suggestion"] for c in criteria if c["suggestion"]),
        "ai_detection": ai_detection,
        "composition_score": by_name.get("Composition and Framing", 3),
        "lighting_score": by_name.get("Lighting and Exposure", 3),
        "focus_score": by_name.get("Focus and Sharpness", 3),
        "color_score": by_name.get("Color and White Balance", 3),
        "subject_clarity_score": by_name.get("Subject Clarity", 3),
        "creativity_score": by_name.get("Creativity and Storytelling", 3),
        "relevance_score": by_name.get("Relevance to Event Theme", 3),
        "technical_quality_score": by_name.get("Technical Quality", 3),
        "documentation_value_score": by_name.get("Overall Documentation Value", 3),
        "legacy": {
            "sharpness_score": round(by_name.get("Focus and Sharpness", 3) / 5, 3),
            "brightness_score": round(by_name.get("Lighting and Exposure", 3) / 5, 3),
            "contrast_score": round(by_name.get("Color and White Balance", 3) / 5, 3),
            "blur_score": round(by_name.get("Focus and Sharpness", 3) / 5, 3),
            "noise_score": round(1 - by_name.get("Technical Quality", 3) / 5, 3),
            "overall_score": round(overall / 5, 3),
        },
    }


def _criterion(name: str, score: int) -> dict[str, Any]:
    labels = {5: "Excellent", 4: "Good", 3: "Fair", 2: "Needs Improvement", 1: "Poor"}
    return {
        "name": name,
        "score": score,
        "label": labels.get(score, "Fair"),
        "explanation": f"Automated analysis rated {name.lower()} as {labels.get(score, 'Fair').lower()}.",
        "suggestion": "Retake with better light and focus." if score <= 2 else "Maintain this standard for future submissions.",
    }


def parse_client_payload(raw: str | None) -> dict[str, Any] | None:
    if not raw or not raw.strip():
        return None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None
    if not isinstance(data, dict):
        return None
    return data


def legacy_scores_from_payload(payload: dict[str, Any]) -> dict[str, float]:
    legacy = payload.get("legacy")
    if isinstance(legacy, dict):
        return {
            "sharpness_score": float(legacy.get("sharpness_score", 0.6)),
            "brightness_score": float(legacy.get("brightness_score", 0.6)),
            "contrast_score": float(legacy.get("contrast_score", 0.6)),
            "blur_score": float(legacy.get("blur_score", 0.6)),
            "noise_score": float(legacy.get("noise_score", 0.4)),
            "overall_score": float(legacy.get("overall_score", 0.6)),
        }
    criteria = payload.get("criteria")
    if isinstance(criteria, list):
        by_name = {
            c.get("name"): int(c.get("score", 3))
            for c in criteria
            if isinstance(c, dict) and c.get("name")
        }

        def s(primary: str, fallback: str | None = None) -> int:
            if primary in by_name:
                return by_name[primary]
            if fallback and fallback in by_name:
                return by_name[fallback]
            return 3

        sharpness = s("Sharpness", "Focus and Sharpness")
        blur = s("Blur", "Focus and Sharpness")
        noise = s("Noise", "Technical Quality")
        brightness = s("Brightness", "Lighting and Exposure")
        contrast = s("Contrast", "Color and White Balance")
        overall = float(payload.get("overall_score", 3)) / 5.0
        return {
            "sharpness_score": round(sharpness / 5, 3),
            "brightness_score": round(brightness / 5, 3),
            "contrast_score": round(contrast / 5, 3),
            "blur_score": round(blur / 5, 3),
            "noise_score": round(1 - noise / 5, 3),
            "overall_score": round(overall, 3),
        }
    overall = float(payload.get("overall_score", 3)) / 5.0
    return {
        "sharpness_score": float(payload.get("focus_score", 3)) / 5.0,
        "brightness_score": float(payload.get("lighting_score", 3)) / 5.0,
        "contrast_score": float(payload.get("color_score", 3)) / 5.0,
        "blur_score": float(payload.get("focus_score", 3)) / 5.0,
        "noise_score": max(0.0, 1.0 - float(payload.get("technical_quality_score", 3)) / 5.0),
        "overall_score": round(overall, 3),
    }
