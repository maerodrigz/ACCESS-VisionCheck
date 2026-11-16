"""Read-only: why fewer chains than post-migration (no writes)."""
from sqlalchemy import create_engine, text

from app.config import settings


def main() -> None:
    engine = create_engine(settings.database_url)
    with engine.connect() as c:
        # Practice eval media that could have had a chain (uploaded_by set) but have no link now.
        orphan_roots = c.execute(
            text(
                """
                SELECT COUNT(*) FROM media_files m
                WHERE m.media_category = 'member_evaluation'
                  AND m.uploaded_by IS NOT NULL
                  AND m.submission_chain_id IS NULL
                  AND NOT EXISTS (
                    SELECT 1 FROM submission_chains sc WHERE sc.root_media_id = m.id
                  )
                """
            )
        ).scalar()
        # Chains whose root media row no longer exists (should be 0 with RESTRICT).
        missing_root = c.execute(
            text(
                """
                SELECT COUNT(*) FROM submission_chains sc
                WHERE NOT EXISTS (
                  SELECT 1 FROM media_files m WHERE m.id = sc.root_media_id
                )
                """
            )
        ).scalar()
        print(f"eval_media_eligible_but_no_chain={orphan_roots}")
        print(f"chains_with_missing_root_media={missing_root}")
    engine.dispose()


if __name__ == "__main__":
    main()
