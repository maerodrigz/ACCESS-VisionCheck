from sqlalchemy import create_engine, text

from app.config import settings


def main() -> None:
    engine = create_engine(settings.database_url)
    with engine.connect() as c:
        drift = c.execute(
            text(
                """
                SELECT COUNT(*) FROM submission_chains sc
                JOIN media_files m ON m.id = sc.root_media_id
                WHERE m.submission_chain_id IS DISTINCT FROM sc.id
                """
            )
        ).scalar()
        roots_no_chain_row = c.execute(
            text(
                """
                SELECT COUNT(*) FROM media_files m
                WHERE m.media_category = 'member_evaluation'
                  AND m.uploaded_by IS NOT NULL
                  AND m.submission_chain_id IS NULL
                """
            )
        ).scalar()
        print(f"root_media_chain_id_drift={drift}")
        print(f"eval_media_null_chain_id={roots_no_chain_row}")
    engine.dispose()


if __name__ == "__main__":
    main()
