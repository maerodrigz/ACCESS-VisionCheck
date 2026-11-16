"""Read-only: compare legacy 70/30 skill tiers vs quality-only eligible formula.

Does NOT write to the database or call recalculate_skill_level.
"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

_BACKEND = Path(__file__).resolve().parents[1]
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from dotenv import load_dotenv

load_dotenv(_BACKEND / ".env")

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.crud import member_profile as profile_crud
from app.crud.rankings_admin import _ai_counts
from app.database import SessionLocal
from app.models.enums import RoleName, UserStatus
from app.models.role import Role
from app.models.user import User
from app.services.skill_evaluation_eligibility import eligible_skill_evaluation_stats
from app.services.skill_scoring import effective_skill_level, media_quality_percent


def _legacy_skill_score(media_q: float, ai_q: float) -> float:
    return round(media_q * 0.7 + ai_q * 0.3, 2)


def main() -> None:
    out_dir = _BACKEND / "backups" / "skill_formula_preview"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "skill_tier_old_vs_new.csv"

    db: Session = SessionLocal()
    try:
        members = db.scalars(
            select(User)
            .join(Role, User.role_id == Role.id)
            .where(User.status == UserStatus.APPROVED, Role.role_name == RoleName.MEMBER)
        ).all()

        rows_out: list[dict] = []
        for user in members:
            uid = user.id
            eligible = eligible_skill_evaluation_stats(db, uid)
            all_count, all_avg = profile_crud.evaluations_stats(db, uid)
            human, ai_gen, suspicious = _ai_counts(db, uid)
            total_checked = human + ai_gen + suspicious
            ai_q = (
                round((human / total_checked) * 100.0, 2) if total_checked > 0 else 100.0
            )
            media_q_eligible = media_quality_percent(eligible.average_score)
            media_q_all = media_quality_percent(all_avg)
            legacy_score = _legacy_skill_score(media_q_all, ai_q)
            new_score = media_q_eligible
            legacy_tier = effective_skill_level(legacy_score, all_count)
            new_tier = effective_skill_level(new_score, eligible.count)
            override = None
            ranking = user.member_ranking
            if ranking and ranking.competency_level_override:
                override = ranking.competency_level_override
            stored_level = user.skill_level.level_name if user.skill_level else None

            rows_out.append(
                {
                    "user_id": uid,
                    "name": user.fullname,
                    "stored_skill_level": stored_level or "",
                    "override": override or "",
                    "legacy_skill_score": legacy_score,
                    "new_skill_score": new_score,
                    "legacy_computed_tier": legacy_tier,
                    "new_computed_tier": new_tier,
                    "tier_changed": legacy_tier != new_tier,
                    "all_eval_count": all_count,
                    "eligible_eval_count": eligible.count,
                    "ai_authenticity_pct": ai_q,
                }
            )

        with out_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=list(rows_out[0].keys()) if rows_out else [])
            if rows_out:
                writer.writeheader()
                writer.writerows(rows_out)

        changed = sum(1 for r in rows_out if r["tier_changed"])
        print(f"database={settings.db_name}")
        print(f"members={len(rows_out)}")
        print(f"tier_would_change={changed}")
        print(f"report={out_path}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
