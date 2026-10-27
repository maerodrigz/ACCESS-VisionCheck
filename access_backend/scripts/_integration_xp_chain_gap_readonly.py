from sqlalchemy import create_engine, text
from app.config import settings

e = create_engine(settings.database_url)
with e.connect() as c:
    missing = c.execute(
        text(
            """
            SELECT id, file_name, uploaded_by, submission_chain_id
            FROM media_files
            WHERE media_category = 'member_evaluation'
              AND (uploaded_by IS NULL OR submission_chain_id IS NULL)
            """
        )
    ).fetchall()
    print("member_eval_without_chain", len(missing))
    for row in missing:
        print(" ", row)

    cols = [
        r[0]
        for r in c.execute(
            text(
                """
                SELECT column_name FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'member_rankings'
                ORDER BY ordinal_position
                """
            )
        ).fetchall()
    ]
    print("member_rankings_columns", cols)
    xp_col = next((c for c in cols if "xp" in c.lower()), None)
    if xp_col:
        s = c.execute(text(f"SELECT COALESCE(SUM({xp_col}), 0) FROM member_rankings")).scalar()
        print(f"member_rankings_sum_{xp_col}", s)

    ev = c.execute(text("SELECT COALESCE(SUM(overall_score), 0) FROM media_evaluations")).scalar()
    print("media_evaluations_overall_score_sum", ev)

e.dispose()
