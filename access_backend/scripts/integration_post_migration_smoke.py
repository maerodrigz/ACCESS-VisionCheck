"""Non-destructive HTTP smoke tests after postgres migration (port 3001)."""
from __future__ import annotations

import os
import sys

import httpx
from sqlalchemy import create_engine, text

API = os.environ.get("SMOKE_API_BASE", "http://127.0.0.1:3001/api").rstrip("/")
ADMIN_EMAIL = os.environ.get("SMOKE_ADMIN_EMAIL", "admin@access.edu")
ADMIN_PASSWORD = os.environ.get("SMOKE_ADMIN_PASSWORD", "admin123")


def _login(client: httpx.Client, email: str, password: str) -> str:
    r = client.post(f"{API}/auth/login", json={"email": email, "password": password})
    if r.status_code != 200:
        raise RuntimeError(f"login failed {email}: {r.status_code} {r.text[:200]}")
    data = r.json()
    token = data.get("token") or data.get("access_token")
    if not token:
        raise RuntimeError(f"no token for {email}")
    return token


def main() -> int:
    errors: list[str] = []

    def ok(label: str, cond: bool, detail: str = "") -> None:
        if cond:
            print(f"PASS  {label}")
        else:
            msg = f"FAIL  {label}" + (f": {detail}" if detail else "")
            print(msg)
            errors.append(msg)

    from app.config import settings

    ok("config db_name is postgres", settings.db_name == "postgres", settings.db_name)
    ok("config replacement_upload_enabled false", not settings.replacement_upload_enabled)

    with httpx.Client(timeout=60.0) as client:
        hr = client.get(f"{API}/health")
        ok("GET /api/health 200", hr.status_code == 200, hr.text[:120])
        if hr.status_code == 200:
            body = hr.json()
            ok("health db connected", body.get("db") == "connected" or body.get("status") == "ok")

        try:
            admin_tok = _login(client, ADMIN_EMAIL, ADMIN_PASSWORD)
            ok("admin login", True)
        except RuntimeError as exc:
            ok("admin login", False, str(exc))
            return 1

        h_auth = {"Authorization": f"Bearer {admin_tok}"}
        stats = client.get(f"{API}/admin/stats", headers=h_auth)
        ok("GET /admin/stats 200", stats.status_code == 200, stats.text[:160])

        ai = client.get(f"{API}/admin/ai-detection", params={"inbox": "all"}, headers=h_auth)
        ok("GET /admin/ai-detection 200", ai.status_code == 200, ai.text[:160])
        ai_rows = ai.json() if ai.status_code == 200 and isinstance(ai.json(), list) else []
        media_id = ai_rows[0]["media_id"] if ai_rows else None

        if media_id:
            stream = client.get(
                f"{API}/admin/media/{media_id}/stream",
                params={"access_token": admin_tok},
            )
            ok(
                "GET /admin/media/{id}/stream",
                stream.status_code in (200, 404),
                f"status={stream.status_code}",
            )
            chain = client.get(
                f"{API}/admin/media/{media_id}/submission-chain",
                headers=h_auth,
            )
            ok(
                "GET /admin/media/{id}/submission-chain",
                chain.status_code in (200, 404),
                f"status={chain.status_code}",
            )
        else:
            print("SKIP  admin stream/chain (no ai rows)")

        engine = create_engine(settings.database_url, pool_pre_ping=True)
        with engine.connect() as conn:
            member_row = conn.execute(
                text(
                    """
                    SELECT u.email FROM users u
                    JOIN roles r ON r.id = u.role_id
                    WHERE r.role_name = 'Member' AND u.status = 'approved'
                    ORDER BY u.id LIMIT 1
                    """
                )
            ).fetchone()
            root_chain = conn.execute(
                text(
                    """
                    SELECT sc.root_media_id FROM submission_chains sc
                    ORDER BY sc.id LIMIT 1
                    """
                )
            ).fetchone()
        engine.dispose()

        member_tok: str | None = None
        if not member_row:
            ok("member account for smoke", False, "no approved member in postgres")
        else:
            member_email = member_row[0]
            from pathlib import Path

            from dotenv import load_dotenv

            load_dotenv(Path(__file__).resolve().parents[1] / ".env.smoke.local", override=False)
            member_password = os.environ.get("SMOKE_MEMBER_PASSWORD") or os.environ.get(
                "SMOKE_WAVEREP_MEMBER_PASSWORD"
            )
            if not member_password:
                member_password = "member123"
            try:
                member_tok = _login(client, member_email, member_password)
                ok(f"member login ({member_email})", True)
            except RuntimeError:
                ok(
                    f"member login ({member_email})",
                    False,
                    "set SMOKE_MEMBER_PASSWORD in .env.smoke.local if not seed member123",
                )

            if member_tok:
                mh = {"Authorization": f"Bearer {member_tok}"}
                ev = client.get(f"{API}/evaluations?mine=true", headers=mh)
                ok("GET /evaluations?mine=true 200", ev.status_code == 200, ev.text[:160])
                if root_chain:
                    root_id = int(root_chain[0])
                    ch = client.get(f"{API}/evaluations/chains/{root_id}", headers=mh)
                    ok(
                        "GET /evaluations/chains/{root} member",
                        ch.status_code in (200, 404),
                        f"status={ch.status_code} root={root_id}",
                    )

                # Flag off: rejected before file persistence (replaces_media_id set).
                rep_probe = client.post(
                    f"{API}/media/upload",
                    headers=mh,
                    data={"replaces_media_id": "999999999"},
                    files={"file": ("smoke_probe.jpg", b"\xff\xd8\xff\xd9", "image/jpeg")},
                )
                ok(
                    "replacement upload disabled (not 200)",
                    rep_probe.status_code != 200,
                    f"status={rep_probe.status_code}",
                )
                if rep_probe.status_code == 400:
                    detail = rep_probe.json().get("detail")
                    code = detail.get("code") if isinstance(detail, dict) else None
                    ok(
                        "replacement disabled code",
                        code == "replacement_upload_disabled",
                        str(code),
                    )

    print("\n--- record counts (postgres) ---")
    import subprocess

    subprocess.run(
        [sys.executable, str(__import__("pathlib").Path(__file__).parent / "_integration_baseline_counts_readonly.py")],
        check=False,
        env={k: v for k, v in os.environ.items() if k != "ACCESS_PYTEST_DB"},
    )

    if errors:
        print(f"\nSMOKE FAILED ({len(errors)} checks)")
        return 1
    print("\nSMOKE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
