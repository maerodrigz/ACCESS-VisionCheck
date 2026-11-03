"""Read-only: member evaluation + event media counts on configured DB."""

from sqlalchemy import text

from app.config import settings
from app.database import SessionLocal


def main() -> None:
    print(f"database={settings.db_name}")
    with SessionLocal() as db:
        rows = db.execute(
            text(
                """
                SELECT u.id, u.email, u.fullname,
                  (SELECT COUNT(*) FROM media_files m
                     WHERE m.uploaded_by = u.id AND m.media_category = 'member_evaluation') AS eval_media,
                  (SELECT COUNT(*) FROM media_evaluations me
                     JOIN media_files m ON m.id = me.media_id
                     WHERE m.uploaded_by = u.id) AS eval_rows,
                  (SELECT COUNT(*) FROM media_files m
                     WHERE m.uploaded_by = u.id AND m.media_category = 'event_documentation') AS event_uploads
                FROM users u
                JOIN roles r ON r.id = u.role_id
                WHERE r.role_name = 'Member' AND u.status = 'approved'
                ORDER BY eval_rows DESC NULLS LAST
                LIMIT 20
                """
            )
        ).all()
        for row in rows:
            print(row)
        approved_gallery = db.scalar(
            text(
                """
                SELECT COUNT(*) FROM media_files
                WHERE media_category = 'event_documentation'
                  AND approval_status = 'approved'
                """
            )
        )
        print(f"approved_event_gallery_rows={approved_gallery}")


if __name__ == "__main__":
    main()
