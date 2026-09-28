"""Server-side Gemini narrative generation (API key never sent to clients)."""

from __future__ import annotations

import json
import re
import urllib.error
import urllib.request
from typing import Any

from app.config import settings


def _gemini_generate(prompt: str, *, timeout: int = 45) -> str | None:
    key = (settings.gemini_api_key or "").strip()
    if not key:
        return None

    model = (settings.gemini_model or "gemini-1.5-flash").strip()
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
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
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


def _criterion_lines(evaluation: dict[str, Any]) -> str:
    criteria = evaluation.get("criteria") or []
    lines: list[str] = []
    if isinstance(criteria, list):
        for item in criteria:
            if not isinstance(item, dict):
                continue
            name = item.get("name") or "Criterion"
            score = item.get("score", 3)
            label = item.get("label") or ""
            lines.append(f"- {name}: {score}/5 ({label})".rstrip())
    return "\n".join(lines) if lines else "- (no criteria provided)"


def _weaknesses(evaluation: dict[str, Any]) -> str:
    raw = evaluation.get("weaknesses")
    if isinstance(raw, list) and raw:
        return ", ".join(str(x) for x in raw if x)
    criteria = evaluation.get("criteria") or []
    names: list[str] = []
    if isinstance(criteria, list):
        for item in criteria:
            if isinstance(item, dict) and int(item.get("score") or 0) <= 2:
                name = item.get("name")
                if name:
                    names.append(str(name))
    return ", ".join(names) if names else "none critical"


def _strengths(evaluation: dict[str, Any]) -> str:
    raw = evaluation.get("strengths")
    if isinstance(raw, list) and raw:
        return ", ".join(str(x) for x in raw if x)
    criteria = evaluation.get("criteria") or []
    names: list[str] = []
    if isinstance(criteria, list):
        for item in criteria:
            if isinstance(item, dict) and int(item.get("score") or 0) >= 4:
                name = item.get("name")
                if name:
                    names.append(str(name))
    return ", ".join(names) if names else "none highlighted"


def first_name_from_fullname(fullname: str | None) -> str | None:
    if not fullname:
        return None
    parts = fullname.strip().split()
    if not parts:
        return None
    first = parts[0].strip()
    return first or None


def generate_media_evaluation_feedback(
    evaluation: dict[str, Any],
    *,
    member_first_name: str | None = None,
) -> dict[str, Any] | None:
    overall = evaluation.get("overall_score") or evaluation.get("overallScore") or 0
    try:
        overall_f = float(overall)
    except (TypeError, ValueError):
        overall_f = 0.0
    overall_pct = evaluation.get("overall_percent") or evaluation.get("overallPercent")
    if overall_pct is None:
        overall_pct = round((overall_f / 5) * 100) if overall_f > 0 else 0

    name_line = (
        f"Member first name: {member_first_name}"
        if member_first_name
        else "Member first name: (not provided)"
    )

    prompt = f"""You are an experienced photography and videography mentor for ACCESS VisionCheck at USTP Oroquieta.

You receive ONLY pre-computed technical scores from our AI quality analysis (EfficientNet-B0).
You must NEVER invent, adjust, or contradict these scores or percentages.
Do not mention EfficientNet, Gemini, AI models, or scoring algorithms to the member.

{name_line}

Media type: {evaluation.get("media_type") or evaluation.get("mediaType") or "photo"}
Overall quality: {evaluation.get("quality_level") or evaluation.get("qualityLevel") or "Fair"} ({overall_f:.1f}/5, {overall_pct}/100)
Recommendation: {evaluation.get("recommendation") or "Keep practicing"}
Detected strengths (from scores): {_strengths(evaluation)}
Areas to develop (from scores): {_weaknesses(evaluation)}

Criterion scores (DO NOT CHANGE THESE NUMBERS):
{_criterion_lines(evaluation)}

VOICE & TONE RULES (follow strictly):
- Never criticize harshly.
- Always begin the explanation with positive observations.
- Explain strengths first, then areas for improvement.
- Offer practical photography/videography tips tied to the weak criteria.
- Encourage the member to continue practicing.
- If the overall score is low, motivate instead of discouraging. Frame gaps as the next step in their learning journey.
- End with a positive, warm closing statement.
- Sound like a supportive human mentor, not a machine. Use natural, conversational language.
- Open the explanation with an energetic, upbeat first sentence and end that sentence with an exclamation mark.
- If a member first name is provided above, use it at most once in that opening sentence (natural greeting, not repetitive).
- If no name is provided, do not invent or guess a name.

Respond with ONLY valid JSON (no markdown fences) in this exact shape:
{{
  "explanation": "2-4 sentences. First sentence must be positive and energetic, ending with !, then summarize scores in plain encouraging language",
  "strengths": ["specific strength 1", "specific strength 2"],
  "improvements": ["gentle improvement area 1", "gentle improvement area 2"],
  "tips": ["practical photo/video tip 1", "practical tip 2", "practical tip 3"],
  "closing_message": "One warm, motivating sentence inviting them to keep practicing and submit again"
}}
"""

    text = _gemini_generate(prompt)
    if not text:
        return None
    return _parse_json_object(text)


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
