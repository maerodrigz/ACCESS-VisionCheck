"""Server-side Gemini narrative generation (API key never sent to clients)."""

from __future__ import annotations

import json
import logging
import re
import urllib.error
import urllib.request
from typing import Any

from app.config import settings
from app.services.overall_quality_band import (
    overall_percent_from_five_point,
    overall_quality_label_from_percent,
)

logger = logging.getLogger(__name__)

# Soft allowlist for operator checks only. Unknown ids are still callable if configured.
_SUPPORTED_MODEL_PATTERNS = (
    re.compile(r"^gemini-1\.5-", re.I),
    re.compile(r"^gemini-2\.0-", re.I),
    re.compile(r"^gemini-2\.5-", re.I),
    re.compile(r"^gemini-3\.", re.I),
    re.compile(r"^gemini-flash", re.I),
    re.compile(r"^gemini-pro", re.I),
)


def gemini_configuration_status() -> dict[str, Any]:
    """Safe config status for operators — never includes the API key value."""
    key_set = bool((settings.gemini_api_key or "").strip())
    model = (settings.gemini_model or "").strip()
    model_configured = bool(model)
    model_looks_supported = bool(model) and any(p.search(model) for p in _SUPPORTED_MODEL_PATTERNS)
    return {
        "api_key_configured": key_set,
        "model": model or None,
        "model_configured": model_configured,
        "model_looks_supported": model_looks_supported,
        "ready": key_set and model_configured,
    }


def is_valid_gemini_feedback(feedback: Any) -> bool:
    """True when feedback is a usable mentor JSON object (explanation required)."""
    if not isinstance(feedback, dict):
        return False
    explanation = feedback.get("explanation")
    return isinstance(explanation, str) and bool(explanation.strip())


def _gemini_generate(prompt: str, *, timeout: int = 45) -> str | None:
    key = (settings.gemini_api_key or "").strip()
    if not key:
        logger.warning("Gemini skipped: GEMINI_API_KEY is not set")
        return None

    model = (settings.gemini_model or "gemini-3.8-flash").strip()
    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}"
        f":generateContent?key={key}"
    )
    payload = json.dumps({"contents": [{"parts": [{"text": prompt}]}]}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")[:300]
        logger.warning(
            "Gemini HTTP %s model=%s body=%s",
            exc.code,
            model,
            body,
        )
        return None
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
        logger.warning("Gemini request failed model=%s err=%s", model, exc)
        return None

    candidates = data.get("candidates") or []
    if not candidates:
        return None
    parts = (candidates[0].get("content") or {}).get("parts") or []
    text = "".join(p.get("text", "") for p in parts if isinstance(p, dict)).strip()
    return text or None


def _strip_json_fence(text: str) -> str:
    cleaned = re.sub(r"^```(?:json)?\s*", "", text.strip(), flags=re.IGNORECASE)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    return cleaned.strip()


def _parse_json_object(text: str) -> dict[str, Any] | None:
    try:
        parsed = json.loads(_strip_json_fence(text))
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def _criterion_available(item: dict[str, Any]) -> bool:
    """Unavailable / N/A criteria must not be treated as scored zeros."""
    if item.get("available") is False:
        return False
    score = item.get("score")
    if score is None:
        return False
    label = str(item.get("label") or "").strip().upper()
    if label in {"N/A", "NA", "UNAVAILABLE"}:
        return False
    try:
        int(score)
    except (TypeError, ValueError):
        return False
    return True


def _available_criteria(evaluation: dict[str, Any]) -> list[dict[str, Any]]:
    criteria = evaluation.get("criteria") or []
    if not isinstance(criteria, list):
        return []
    return [item for item in criteria if isinstance(item, dict) and _criterion_available(item)]


def _unavailable_criterion_names(evaluation: dict[str, Any]) -> list[str]:
    criteria = evaluation.get("criteria") or []
    names: list[str] = []
    if not isinstance(criteria, list):
        return names
    for item in criteria:
        if not isinstance(item, dict):
            continue
        if _criterion_available(item):
            continue
        name = item.get("name")
        if name:
            names.append(str(name))
    return names


def _score_int(item: dict[str, Any]) -> int | None:
    if not _criterion_available(item):
        return None
    try:
        return int(item.get("score"))
    except (TypeError, ValueError):
        return None


def _criterion_lines(evaluation: dict[str, Any]) -> str:
    criteria = evaluation.get("criteria") or []
    lines: list[str] = []
    if isinstance(criteria, list):
        for item in criteria:
            if not isinstance(item, dict):
                continue
            name = item.get("name") or "Criterion"
            if not _criterion_available(item):
                lines.append(f"- {name}: N/A (not measured — do not invent a score or defect)")
                continue
            score = _score_int(item)
            label = item.get("label") or ""
            lines.append(f"- {name}: {score}/5 ({label})".rstrip())
    return "\n".join(lines) if lines else "- (no criteria provided)"


def _filter_named_against_unavailable(names: list[str], evaluation: dict[str, Any]) -> list[str]:
    unavailable = {n.lower() for n in _unavailable_criterion_names(evaluation)}
    out: list[str] = []
    for name in names:
        text = str(name).strip()
        if not text:
            continue
        if text.lower() in unavailable:
            continue
        out.append(text)
    return out


def _weaknesses(evaluation: dict[str, Any]) -> str:
    raw = evaluation.get("weaknesses")
    if isinstance(raw, list) and raw:
        filtered = _filter_named_against_unavailable([str(x) for x in raw if x], evaluation)
        if filtered:
            return ", ".join(filtered)
    names: list[str] = []
    for item in _available_criteria(evaluation):
        score = _score_int(item)
        if score is not None and score <= 2:
            name = item.get("name")
            if name:
                names.append(str(name))
    return ", ".join(names) if names else "none critical"


def _strengths(evaluation: dict[str, Any]) -> str:
    raw = evaluation.get("strengths")
    if isinstance(raw, list) and raw:
        filtered = _filter_named_against_unavailable([str(x) for x in raw if x], evaluation)
        if filtered:
            return ", ".join(filtered)
    names: list[str] = []
    for item in _available_criteria(evaluation):
        score = _score_int(item)
        if score is not None and score >= 4:
            name = item.get("name")
            if name:
                names.append(str(name))
    return ", ".join(names) if names else "none highlighted"


def _score_by_name(evaluation: dict[str, Any], name: str) -> int | None:
    target = name.strip().lower()
    for item in _available_criteria(evaluation):
        if str(item.get("name") or "").strip().lower() == target:
            return _score_int(item)
    return None


def _clarity_consistency_note(evaluation: dict[str, Any]) -> str:
    """Guide Gemini so Sharpness and Blur are treated as one clarity theme."""
    sharp = _score_by_name(evaluation, "Sharpness")
    blur = _score_by_name(evaluation, "Blur")
    if sharp is None and blur is None:
        return (
            "Sharpness and Blur are both N/A or missing. Do not invent focus or blur problems."
        )
    if sharp is None:
        return (
            f"Sharpness is N/A. Blur is {blur}/5 (higher = less blur / better clarity). "
            "Do not invent a sharpness defect; do not contradict the Blur score."
        )
    if blur is None:
        return (
            f"Blur is N/A. Sharpness is {sharp}/5. "
            "Do not invent a blur defect; do not contradict the Sharpness score."
        )
    if abs(sharp - blur) <= 1:
        return (
            f"Sharpness ({sharp}/5) and Blur ({blur}/5) agree on clarity. "
            "Treat them as one clarity theme. Give at most one improvement tip about focus/clarity. "
            "Do not double-count the same softness problem."
        )
    return (
        f"Sharpness ({sharp}/5) and Blur ({blur}/5) differ. "
        "Both scores are higher-is-better (Blur high means little blur). "
        "Describe clarity carefully without saying the photo is both sharp and blurry. "
        "Prefer one concise clarity recommendation that reconciles both scores."
    )


def first_name_from_fullname(fullname: str | None) -> str | None:
    if not fullname:
        return None
    parts = fullname.strip().split()
    if not parts:
        return None
    first = parts[0].strip()
    return first or None


def build_media_evaluation_prompt(
    evaluation: dict[str, Any],
    *,
    member_first_name: str | None = None,
) -> str:
    """Build the mentor prompt (pure; used by generation and unit tests)."""
    overall = evaluation.get("overall_score") or evaluation.get("overallScore") or 0
    try:
        overall_f = float(overall)
    except (TypeError, ValueError):
        overall_f = 0.0
    overall_pct = evaluation.get("overall_percent") or evaluation.get("overallPercent")
    if overall_pct is None:
        overall_pct = overall_percent_from_five_point(overall_f) if overall_f > 0 else 0
    try:
        overall_pct_int = max(0, min(100, int(round(float(overall_pct)))))
    except (TypeError, ValueError):
        overall_pct_int = overall_percent_from_five_point(overall_f)
    quality_label = overall_quality_label_from_percent(overall_pct_int)
    overall_pct = overall_pct_int

    name_line = (
        f"Member first name: {member_first_name}"
        if member_first_name
        else "Member first name: (not provided)"
    )
    unavailable = _unavailable_criterion_names(evaluation)
    unavailable_line = (
        ", ".join(unavailable) if unavailable else "none"
    )

    return f"""You are an experienced photography and videography mentor for ACCESS VisionCheck at USTP Oroquieta.

You receive ONLY pre-computed technical scores from our automated image quality assessment.
You did NOT independently inspect or view the original photo or video.
You must NEVER invent, adjust, or contradict these scores or percentages.
You must NEVER invent image defects that are not supported by the measured criteria below.
You must NEVER make authenticity, AI-generated media, deepfake, or provenance conclusions.
Do not mention Gemini, model names, scoring engines, or algorithms to the member.
Criteria marked N/A were not measured — skip them entirely; never treat N/A as a zero or as a defect.

{name_line}

Media type: {evaluation.get("media_type") or evaluation.get("mediaType") or "photo"}
Overall quality: {quality_label} ({overall_f:.1f}/5, {overall_pct}/100)
Recommendation: {evaluation.get("recommendation") or "Keep practicing"}
Detected strengths (from available scores only): {_strengths(evaluation)}
Areas to develop (from available scores only): {_weaknesses(evaluation)}
Unavailable / N/A criteria (do not discuss as problems): {unavailable_line}

Criterion scores (DO NOT CHANGE THESE NUMBERS; preserve N/A):
{_criterion_lines(evaluation)}

CLARITY CONSISTENCY (Sharpness and Blur):
{_clarity_consistency_note(evaluation)}

ACCURACY RULES (follow strictly):
- Explain only the measured quality criteria that have numeric scores in the input above.
- Provide concise, actionable, user-friendly suggestions tied to weak available criteria.
- If Sharpness and Blur both need work, combine into one clarity tip — do not double-count.
- Avoid contradictory recommendations (never say the image is both sharp and blurry).
- Do not discuss criteria that are N/A or missing.
- Do not invent composition, subject, authenticity, or artistic judgments unsupported by the scores.

MEMBER-FACING LANGUAGE (critical):
- The member already sees scores on metric cards. Your JSON text must NOT include any numbers.
- Never write scores, fractions (such as 3/5), percentages, raw measurements, or numeric comparisons in explanation, strengths, improvements, tips, or closing_message.
- Use natural words only (for example: strong, soft, uneven, clear, muted).
- Do not mention thresholds, models, or scoring scales.

VOICE & TONE RULES (follow strictly):
- Never criticize harshly.
- Always begin the explanation with positive observations.
- Explain strengths first, then areas for improvement.
- Offer practical photography/videography tips tied to the weak available criteria.
- Encourage the member to continue practicing.
- If the overall quality level is low, motivate instead of discouraging. Frame gaps as the next step in their learning journey.
- End with a positive, warm closing statement.
- Sound like a supportive human mentor, not a machine. Use natural, conversational language.
- Open the explanation with an energetic, upbeat first sentence and end that sentence with an exclamation mark.
- If a member first name is provided above, use it at most once in that opening sentence (natural greeting, not repetitive).
- If no name is provided, do not invent or guess a name.

Respond with ONLY valid JSON (no markdown fences) in this exact shape:
{{
  "explanation": "2-4 sentences. First sentence must be positive and energetic, ending with !, then summarize quality in plain encouraging language with NO numbers",
  "strengths": ["specific strength 1 with no numbers", "specific strength 2 with no numbers"],
  "improvements": ["gentle improvement area 1 with no numbers", "gentle improvement area 2 with no numbers"],
  "tips": ["practical photo/video tip 1 with no numbers", "practical tip 2 with no numbers", "practical tip 3 with no numbers"],
  "closing_message": "One warm, motivating sentence inviting them to keep practicing and submit again (no numbers)"
}}
"""


def generate_media_evaluation_feedback(
    evaluation: dict[str, Any],
    *,
    member_first_name: str | None = None,
) -> dict[str, Any] | None:
    prompt = build_media_evaluation_prompt(
        evaluation,
        member_first_name=member_first_name,
    )
    text = _gemini_generate(prompt)
    if not text:
        return None
    parsed = _parse_json_object(text)
    if not is_valid_gemini_feedback(parsed):
        return None
    from app.services.rule_based_quality_feedback import sanitize_member_facing_feedback

    return sanitize_member_facing_feedback(parsed)


def generate_rubric_feedback(
    *,
    scores: dict[str, int],
    title: str,
    total_score: int,
    max_score: int,
) -> str | None:
    score_lines = "\n".join(f"- {name}: {value}/5" for name, value in scores.items())
    prompt = f"""You are an expert photography coach for ACCESS, a student documentation and photography organization at USTP Oroquieta.

A student submitted event photos titled "{title}" and received the following rubric scores (1–5 scale):
{score_lines}

Overall score: {total_score} / {max_score}

Write a concise, encouraging, and actionable feedback paragraph (3–5 sentences) for this student.
Focus on:
1. What they did well based on their highest scores
2. Specific, practical advice for their lowest-scoring areas
3. A motivating closing sentence

Keep the tone professional but warm. Do not use bullet points; write in flowing prose.
"""
    text = _gemini_generate(prompt)
    return text if text else None


def generate_admin_daily_summary(
    *,
    pending_requests: int,
    today_events: int,
    media_pending: int,
    unread_notifications: int,
    pending_members: int,
) -> str | None:
    prompt = f"""You are an assistant for ACCESS VisionCheck, a university documentation and photography organization admin console.

Write a concise daily briefing for the administrator (3–4 short sentences, plain prose, no bullet points).
Focus on what needs attention today:
- Pending documentation requests: {pending_requests}
- Events scheduled today: {today_events}
- Media awaiting evaluation: {media_pending}
- Unread notifications: {unread_notifications}
- Member registrations pending approval: {pending_members}

Be professional, actionable, and calm. Mention the highest-priority items first. Do not invent numbers beyond those provided.
"""
    return _gemini_generate(prompt, timeout=30)
