from sqlalchemy import create_engine, text

from app.config import settings


def main() -> None:
    engine = create_engine(settings.database_url)
    with engine.connect() as c:
        db = c.execute(text("SELECT current_database()")).scalar()
        reupload = c.execute(
            text(
                "SELECT COUNT(*) FROM ai_detection_results "
                "WHERE LOWER(COALESCE(review_status, '')) LIKE '%reupload%'"
            )
        ).scalar()
        awaiting = c.execute(
            text(
                "SELECT COUNT(*) FROM submission_chains "
                "WHERE awaiting_replacement_media_id IS NOT NULL"
            )
        ).scalar()
        print(f"database={db}")
        print(f"ai_reupload_requested_rows={reupload}")
        print(f"chains_awaiting_replacement={awaiting}")
    engine.dispose()


if __name__ == "__main__":
    main()
