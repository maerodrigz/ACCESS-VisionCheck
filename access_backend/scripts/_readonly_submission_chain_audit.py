"""Read-only audit: submission_chains counts and breakdown (no writes)."""
from __future__ import annotations

from sqlalchemy import create_engine, text

from app.config import settings


def main() -> None:
    engine = create_engine(settings.database_url)
    with engine.connect() as c:
        db = c.execute(text("SELECT current_database()")).scalar()
        host_port = settings.database_url.split("@")[-1] if "@" in settings.database_url else "?"
        total = c.execute(text("SELECT COUNT(*) FROM submission_chains")).scalar()
        with_awaiting = c.execute(
            text(
                "SELECT COUNT(*) FROM submission_chains "
                "WHERE awaiting_replacement_media_id IS NOT NULL"
            )
        ).scalar()
        with_active_rep = c.execute(
            text(
                "SELECT COUNT(*) FROM submission_chains "
                "WHERE active_replacement_media_id IS NOT NULL"
            )
        ).scalar()
        media_with_chain_id = c.execute(
            text(
                "SELECT COUNT(*) FROM media_files "
                "WHERE submission_chain_id IS NOT NULL"
            )
        ).scalar()
        eval_media = c.execute(
            text(
                "SELECT COUNT(*) FROM media_files "
                "WHERE media_category = 'member_evaluation'"
            )
        ).scalar()
        media_eval_rows = c.execute(
            text("SELECT COUNT(*) FROM media_evaluations")
        ).scalar()
        print(f"database={db}")
        print(f"db_url_tail={host_port}")
        print(f"submission_chains_total={total}")
        print(f"chains_awaiting_replacement={with_awaiting}")
        print(f"chains_active_replacement={with_active_rep}")
        print(f"media_files_with_submission_chain_id={media_with_chain_id}")
        print(f"media_member_evaluation={eval_media}")
        print(f"media_evaluations_rows={media_eval_rows}")
        no_chain = c.execute(
            text(
                "SELECT COUNT(*) FROM media_files "
                "WHERE media_category = 'member_evaluation' "
                "AND submission_chain_id IS NULL"
            )
        ).scalar()
        with_chain = c.execute(
            text(
                "SELECT COUNT(*) FROM media_files "
                "WHERE media_category = 'member_evaluation' "
                "AND submission_chain_id IS NOT NULL"
            )
        ).scalar()
        print(f"eval_media_without_chain_link={no_chain}")
        print(f"eval_media_with_chain_link={with_chain}")
        null_uploader = c.execute(
            text(
                "SELECT COUNT(*) FROM media_files "
                "WHERE media_category = 'member_evaluation' AND uploaded_by IS NULL"
            )
        ).scalar()
        no_chain_has_uploader = c.execute(
            text(
                "SELECT COUNT(*) FROM media_files "
                "WHERE media_category = 'member_evaluation' "
                "AND uploaded_by IS NOT NULL AND submission_chain_id IS NULL"
            )
        ).scalar()
        print(f"eval_media_null_uploader={null_uploader}")
        print(f"eval_media_with_uploader_but_no_chain={no_chain_has_uploader}")
        chain_ids = c.execute(
            text(
                "SELECT MIN(id) AS min_id, MAX(id) AS max_id, "
                "MIN(created_at) AS min_created, MAX(created_at) AS max_created "
                "FROM submission_chains"
            )
        ).mappings().first()
        if chain_ids:
            print(f"submission_chains_id_range={dict(chain_ids)}")
    engine.dispose()


if __name__ == "__main__":
    main()
