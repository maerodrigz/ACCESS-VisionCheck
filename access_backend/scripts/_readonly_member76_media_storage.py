from sqlalchemy import text

from app.database import SessionLocal


def main() -> None:
    with SessionLocal() as db:
        row = db.execute(
            text(
                """
                SELECT
                  SUM(CASE WHEN file_url LIKE 'supabase-ref:%' THEN 1 ELSE 0 END),
                  SUM(CASE WHEN file_url LIKE 'https:%' THEN 1 ELSE 0 END),
                  SUM(CASE WHEN file_url LIKE '/uploads/%'
                    AND file_url != '/uploads/__storage_removed__' THEN 1 ELSE 0 END),
                  SUM(CASE WHEN file_url = '/uploads/__storage_removed__' THEN 1 ELSE 0 END),
                  COUNT(*)
                FROM media_files
                WHERE uploaded_by = 76 AND media_category = 'member_evaluation'
                """
            )
        ).one()
        print(
            "member76_eval_media",
            {
                "supabase_ref": int(row[0] or 0),
                "https_stored": int(row[1] or 0),
                "local_uploads": int(row[2] or 0),
                "storage_removed": int(row[3] or 0),
                "total": int(row[4] or 0),
            },
        )


if __name__ == "__main__":
    main()
