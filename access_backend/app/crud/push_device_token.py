from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.push_device_token import PushDeviceToken


def upsert(db: Session, user_id: int, token: str, platform: str) -> PushDeviceToken:
    cleaned = token.strip()
    if not cleaned:
        raise ValueError("empty token")
    existing = db.scalar(select(PushDeviceToken).where(PushDeviceToken.token == cleaned))
    if existing:
        existing.user_id = user_id
        existing.platform = platform
        db.commit()
        db.refresh(existing)
        return existing
    row = PushDeviceToken(user_id=user_id, token=cleaned, platform=platform)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def delete_token(db: Session, user_id: int, token: str) -> int:
    cleaned = token.strip()
    if not cleaned:
        return 0
    result = db.execute(
        delete(PushDeviceToken).where(
            PushDeviceToken.user_id == user_id,
            PushDeviceToken.token == cleaned,
        )
    )
    db.commit()
    return result.rowcount or 0


def list_tokens_for_user(db: Session, user_id: int) -> list[str]:
    rows = db.scalars(select(PushDeviceToken.token).where(PushDeviceToken.user_id == user_id))
    return [r for r in rows if r]
