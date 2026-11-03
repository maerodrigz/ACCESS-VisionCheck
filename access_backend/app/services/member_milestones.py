"""Award Tier-A milestones and notify members (skill tier, eval gates, first eval, title)."""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.crud import member_milestone as milestone_crud
from app.crud import member_profile as profile_crud
from app.services import notification_events as notify_events

_KIND_SKILL_TIER = "skill_tier"
_KIND_FIRST_EVAL = "first_evaluation"
_KIND_EVAL_GATE = "eval_gate"
_KIND_PHOTO_TITLE = "photographer_title"

_EVAL_GATES_V1: tuple[tuple[int, str, str], ...] = (
    (3, "Intermediate", "3 evaluated submissions unlock Intermediate tier eligibility."),
    (6, "Advanced", "6 evaluated submissions unlock Advanced tier eligibility."),
    (10, "Expert", "10 evaluated submissions unlock Expert tier eligibility."),
)

_EVAL_GATES_V2: tuple[tuple[int, str, str], ...] = (
    (
        3,
        "Intermediate",
        "3 skill-eligible released evaluations toward Intermediate "
        "(balanced progression also requires 60%+ quality and 2 distinct upload days).",
    ),
    (
        12,
        "Advanced",
        "12 skill-eligible released evaluations toward Advanced "
        "(balanced progression also requires 75%+ quality and 10 distinct upload days).",
    ),
    (
        24,
        "Expert",
        "24 skill-eligible released evaluations toward Expert "
        "(balanced progression also requires 90%+ quality and 24 distinct upload days).",
    ),
)


def _eval_gates_for_active_policy() -> tuple[tuple[int, str, str], ...]:
    from app.services.skill_progression import active_skill_progression_policy
    from app.services.skill_progression_policy import POLICY_V2

    if active_skill_progression_policy() == POLICY_V2:
        return _EVAL_GATES_V2
    return _EVAL_GATES_V1


def _eval_gate_milestone_key(gate_count: int) -> str:
    from app.services.skill_progression import active_skill_progression_policy
    from app.services.skill_progression_policy import POLICY_V2

    if active_skill_progression_policy() == POLICY_V2:
        return f"v2:{gate_count}"
    return str(gate_count)


def _photographer_title(avg_score: float, eval_count: int) -> str | None:
    if eval_count < 3:
        return None
    avg = avg_score
    if avg > 1.0:
        avg = min(1.0, avg / 5.0)
    senior = eval_count >= 5
    if avg >= 0.90:
        return "Master Photographer"
    if avg >= 0.80:
        return "Expert Photographer"
    if avg >= 0.70:
        return "Senior Documenter" if senior else "Documenter"
    if avg >= 0.60:
        return "Senior Photographer" if senior else "Photographer"
    if avg >= 0.50:
        return "Junior Documenter"
    return "Apprentice"


def _award(
    db: Session,
    user_id: int,
    *,
    milestone_kind: str,
    milestone_key: str,
    title: str,
    message: str,
) -> None:
    row = milestone_crud.create_if_new(
        db,
        user_id,
        milestone_kind=milestone_kind,
        milestone_key=milestone_key,
        title=title,
        message=message,
    )
    if row is None:
        return
    notify_events.notify_user(
        db,
        user_id,
        title=title,
        message=message,
        category="media_evaluation",
        priority="normal",
        action_type="milestone",
        action_ref_id=row.id,
    )


def on_skill_level_recalculated(
    db: Session,
    user_id: int,
    *,
    old_level: str | None,
    new_level: str,
    old_computed_tier: str | None = None,
    new_computed_tier: str | None = None,
) -> None:
    """Notify on computed tier promotion (ignores admin override-only effective label changes)."""
    new_computed = (new_computed_tier or new_level or "").strip()
    old_computed = (old_computed_tier or old_level or "").strip()
    if not new_computed:
        return
    if old_computed.lower() == new_computed.lower():
        return
    _award(
        db,
        user_id,
        milestone_kind=_KIND_SKILL_TIER,
        milestone_key=new_computed,
        title=f"Skill tier: {new_computed}",
        message=(
            f"Congratulations. Your official ACCESS skill label is now {new_computed}. "
            "Keep building quality scores and a clean integrity record."
        ),
    )


def on_evaluation_completed(db: Session, user_id: int, *, evaluation_count: int) -> None:
    if evaluation_count <= 0:
        return

    if evaluation_count == 1:
        _award(
            db,
            user_id,
            milestone_kind=_KIND_FIRST_EVAL,
            milestone_key="first",
            title="First evaluation complete",
            message=(
                "You completed your first practice media evaluation. "
                "Your skill tier and leaderboard XP will grow from here."
            ),
        )

    for gate_count, tier_name, gate_msg in _eval_gates_for_active_policy():
        if evaluation_count != gate_count:
            continue
        _award(
            db,
            user_id,
            milestone_kind=_KIND_EVAL_GATE,
            milestone_key=_eval_gate_milestone_key(gate_count),
            title=f"{gate_count} evaluations milestone",
            message=gate_msg,
        )

    _, avg = profile_crud.evaluations_stats(db, user_id)
    title = _photographer_title(float(avg or 0), evaluation_count)
    if title:
        _award(
            db,
            user_id,
            milestone_kind=_KIND_PHOTO_TITLE,
            milestone_key=title.replace(" ", "_").lower()[:80],
            title=f"Title earned: {title}",
            message=(
                f"You earned the photographer title {title} based on your evaluation quality. "
                "This title is shown on your profile separately from your skill tier."
            ),
        )
