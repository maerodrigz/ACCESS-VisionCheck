"""Schemas for server-proxied Gemini assist endpoints."""

from typing import Any

from pydantic import BaseModel, Field


class MediaEvaluationFeedbackIn(BaseModel):
    evaluation: dict[str, Any] = Field(description="EfficientNet evaluation payload from /media/evaluate")


class MediaEvaluationFeedbackOut(BaseModel):
    feedback: dict[str, Any] | None = None


class RubricFeedbackIn(BaseModel):
    scores: dict[str, int]
    title: str = "Submission"
    total_score: int = 0
    max_score: int = 0


class RubricFeedbackOut(BaseModel):
    text: str | None = None


class AdminDailySummaryIn(BaseModel):
    pending_requests: int = 0
    today_events: int = 0
    media_pending: int = 0
    unread_notifications: int = 0
    pending_members: int = 0


class AdminDailySummaryOut(BaseModel):
    summary: str | None = None
