from sqlalchemy import create_engine, text

from app.config import settings


def main() -> None:
    engine = create_engine(settings.database_url)
    with engine.connect() as c:
        ids = [
            r[0]
            for r in c.execute(text("SELECT id FROM submission_chains ORDER BY id")).fetchall()
        ]
        events = c.execute(text("SELECT COUNT(*) FROM submission_chain_events")).scalar()
        orphaned = c.execute(
            text(
                "SELECT COUNT(*) FROM media_files m "
                "WHERE m.submission_chain_id IS NOT NULL "
                "AND NOT EXISTS (SELECT 1 FROM submission_chains s WHERE s.id = m.submission_chain_id)"
            )
        ).scalar()
        print(f"chain_ids_present={ids}")
        print(f"chain_id_count={len(ids)}")
        print(f"submission_chain_events={events}")
        print(f"media_orphan_chain_fk={orphaned}")
    engine.dispose()


if __name__ == "__main__":
    main()
