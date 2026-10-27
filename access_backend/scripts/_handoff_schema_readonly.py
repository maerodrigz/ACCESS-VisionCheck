"""One-off read-only schema check for handoff (no writes)."""
from sqlalchemy import create_engine, text

from app.config import settings


def main() -> None:
    engine = create_engine(settings.database_url)
    with engine.connect() as c:
        db = c.execute(text("SELECT current_database()")).scalar()
        has = c.execute(
            text(
                "SELECT EXISTS (SELECT 1 FROM information_schema.tables "
                "WHERE table_schema = 'public' AND table_name = 'submission_chains')"
            )
        ).scalar()
        count = (
            c.execute(text("SELECT COUNT(*) FROM submission_chains")).scalar()
            if has
            else None
        )
        print(f"database={db}")
        print(f"submission_chains_table={has}")
        print(f"submission_chains_rows={count}")
    engine.dispose()


if __name__ == "__main__":
    main()
