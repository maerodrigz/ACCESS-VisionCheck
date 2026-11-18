"""Rankings list stays equal to the per-member rules, with a bounded query count."""

from __future__ import annotations

from sqlalchemy import func, select, event

from app.crud import member_profile as profile_crud
from app.crud.rankings_admin import (
    _ai_counts,
    _integrity_counts,
    _participation_status,
    _skill_payload_for_user,
    list_rankings,
    monthly_points_for_user,
)
from app.database import SessionLocal, engine
from app.models.media_file import MediaFile
from app.models.user import User
from app.services.skill_evaluation_eligibility import eligible_skill_evaluation_stats


def test_list_rankings_matches_per_member_rules_and_uses_few_queries() -> None:
    db = SessionLocal()
    queries = {"n": 0}

    def _count(*_args, **_kwargs) -> None:
        queries["n"] += 1

    event.listen(engine, "before_cursor_execute", _count)
    try:
        rows = list_rankings(db)
        query_count = queries["n"]
        by_id = {row["user_id"]: row for row in rows}
        assert len(by_id) == len(rows)

        for row in rows:
            user_id = row["user_id"]
            eligible = eligible_skill_evaluation_stats(db, user_id)
            human, ai_gen, suspicious = _ai_counts(db, user_id)
            violations, warnings = _integrity_counts(db, user_id)
            uploads = profile_crud.uploads_count(db, user_id)
            approved = profile_crud.approved_uploads_count(db, user_id)
            _count_unused, average = profile_crud.evaluations_stats(db, user_id)
            completed = profile_crud.assignments_completed(db, user_id)
            assigned = profile_crud.assignments_total(db, user_id)
            admin_score = profile_crud.admin_evaluation_score(db, user_id)
            skill = _skill_payload_for_user(db, user_id)
            member = db.get(User, user_id)
            ranking = member.member_ranking if member is not None else None
            last_upload = db.scalar(
                select(func.max(MediaFile.uploaded_at)).where(MediaFile.uploaded_by == user_id)
            )
            last_activity = last_upload or (ranking.updated_at if ranking else None)
            assert row["monthly_points"] == monthly_points_for_user(db, user_id)
            assert row["uploads"] == uploads
            assert row["approved_uploads"] == approved
            assert row["evaluation_count"] == eligible.count
            assert row["avg_score"] == round(eligible.average_score, 3)
            assert row["total_evaluation_rows"] == average
            assert row["completed_tasks"] == completed
            assert row["assigned_tasks"] == assigned
            assert row["admin_evaluation_score"] == skill["admin_evaluation_score"]
            assert admin_score == skill["admin_evaluation_score"]
            assert row["skill_score"] == skill["skill_score"]
            assert row["average_quality_score"] == skill["average_quality_score"]
            assert row["ai_human_count"] == human
            assert row["ai_flagged_count"] == ai_gen + suspicious
            assert row["integrity_violations"] == violations
            assert row["integrity_warnings"] == warnings
            assert row["skill_eligible_photo_count"] == skill["skill_eligible_photo_count"]
            assert row["skill_eligible_video_count"] == skill["skill_eligible_video_count"]
            assert row["skill_eligible_photo_average"] == skill["skill_eligible_photo_average"]
            assert row["skill_eligible_video_average"] == skill["skill_eligible_video_average"]
            assert row["participation_status"] == _participation_status(
                uploads=uploads,
                avg_score=eligible.average_score,
                ai_gen=ai_gen,
                suspicious=suspicious,
                last_activity=last_activity,
            )
            assert row["points"] == row["good_evaluations"]
            assert row["id"] == user_id
            assert row["name"] == row["member_name"]

        assert query_count <= 20
        assert rows == sorted(rows, key=lambda item: item["rank"])
    finally:
        event.remove(engine, "before_cursor_execute", _count)
        db.close()
