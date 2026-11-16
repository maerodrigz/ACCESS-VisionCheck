"""Read-only: Organization user 75 requests and linked media ownership."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from sqlalchemy import create_engine, text

BACKEND = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND))

from app.env_bootstrap import bootstrap_environment

bootstrap_environment()
from app.config import settings  # noqa: E402

ADMIN_ID = 1
ORG_ID = 75
TARGET_IDS = (73, 74, 75, 76)


def main() -> None:
    engine = create_engine(settings.database_url)
    out: dict = {"org_user_id": ORG_ID, "admin_user_id": ADMIN_ID}
    with engine.connect() as c:
        out["requests"] = [
            dict(r._mapping)
            for r in c.execute(
                text(
                    """
                    SELECT id, title, status, event_date, archived_at
                    FROM documentation_requests
                    WHERE requestor_id = :uid
                    ORDER BY id
                    """
                ),
                {"uid": ORG_ID},
            )
        ]
        req_ids = [r["id"] for r in out["requests"]]
        if req_ids:
            out["media_on_org_requests"] = [
                dict(r._mapping)
                for r in c.execute(
                    text(
                        """
                        SELECT mf.id, mf.uploaded_by, mf.request_id, mf.media_category,
                               mf.file_name, LEFT(mf.file_url, 90) AS file_url_prefix,
                               u.email AS uploader_email,
                               r.role_name AS uploader_role
                        FROM media_files mf
                        LEFT JOIN users u ON u.id = mf.uploaded_by
                        LEFT JOIN roles r ON r.id = u.role_id
                        WHERE mf.request_id = ANY(:ids)
                        ORDER BY mf.id
                        """
                    ),
                    {"ids": req_ids},
                )
            ]
            out["assignments_on_org_requests"] = [
                dict(r._mapping)
                for r in c.execute(
                    text(
                        """
                        SELECT ra.id, ra.request_id, ra.member_id, ra.assigned_by,
                               ra.status, um.email AS member_email
                        FROM request_assignments ra
                        JOIN users um ON um.id = ra.member_id
                        WHERE ra.request_id = ANY(:ids)
                        ORDER BY ra.id
                        """
                    ),
                    {"ids": req_ids},
                )
            ]
        else:
            out["media_on_org_requests"] = []
            out["assignments_on_org_requests"] = []

        out["admin_media_count"] = c.execute(
            text("SELECT COUNT(*) FROM media_files WHERE uploaded_by = :aid"),
            {"aid": ADMIN_ID},
        ).scalar()
        out["orphan_220"] = [
            dict(r._mapping)
            for r in c.execute(
                text(
                    """
                    SELECT id, uploaded_by, request_id, media_category, file_name,
                           LEFT(file_url, 100) AS file_url_prefix
                    FROM media_files WHERE id = 220
                    """
                )
            )
        ]
        out["non_admin_ids_confirmed"] = list(
            c.execute(
                text(
                    """
                    SELECT u.id, u.email, r.role_name
                    FROM users u JOIN roles r ON r.id = u.role_id
                    WHERE r.role_name != 'Admin'
                    ORDER BY u.id
                    """
                )
            ).fetchall()
        )
    print(json.dumps(out, indent=2, default=str))


if __name__ == "__main__":
    main()
