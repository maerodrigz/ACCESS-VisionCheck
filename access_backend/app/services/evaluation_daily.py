"""Calendar day boundaries for practice evaluation daily limits."""

from datetime import date, datetime
from zoneinfo import ZoneInfo

from app.config import settings


def evaluation_calendar_date() -> date:
    """Local calendar date for daily upload cap (timezone from EVALUATION_DAILY_TIMEZONE)."""
    name = (settings.evaluation_daily_timezone or "UTC").strip()
    try:
        tz = ZoneInfo(name)
    except Exception:
        tz = ZoneInfo("UTC")
    return datetime.now(tz).date()
