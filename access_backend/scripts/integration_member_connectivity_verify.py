"""Member connectivity verify (PC-side). Uses .env.smoke.local if present; no password output."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import httpx
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

API = "http://127.0.0.1:3001/api"
load_dotenv(Path(__file__).resolve().parents[1] / ".env.smoke.local", override=False)

email = (os.environ.get("SMOKE_MEMBER_EMAIL") or "").strip()
password = (os.environ.get("SMOKE_MEMBER_PASSWORD") or "").strip()


def main() -> int:
    from app.config import settings

    print(f"replacement_upload_enabled={settings.replacement_upload_enabled}")
    engine = create_engine(settings.database_url)
    with engine.connect() as c:
        print(f"database={c.execute(text('SELECT current_database()')).scalar()}")
    engine.dispose()

    if not email or not password:
        print("member_login=SKIP (set SMOKE_MEMBER_EMAIL and SMOKE_MEMBER_PASSWORD in .env.smoke.local)")
        return 0

    with httpx.Client(timeout=45) as client:
        r = client.post(f"{API}/auth/login", json={"email": email, "password": password})
        print(f"member_login_status={r.status_code}")
        if r.status_code != 200:
            return 1
        tok = r.json().get("token") or r.json().get("access_token")
        h = {"Authorization": f"Bearer {tok}"}
        ev = client.get(f"{API}/evaluations?mine=true", headers=h)
        print(f"evaluations_mine_status={ev.status_code} count={len(ev.json()) if ev.status_code == 200 else 'NA'}")
        root = None
        if ev.status_code == 200 and ev.json():
            for row in ev.json():
                mid = row.get("media_id") or row.get("practice_media_id")
                if mid:
                    root = int(mid)
                    break
        if root:
            ch = client.get(f"{API}/evaluations/chains/{root}", headers=h)
            print(f"chain_history_status={ch.status_code} root={root}")
        rep = client.post(
            f"{API}/media/upload",
            headers=h,
            data={"replaces_media_id": "999999999"},
            files={"file": ("probe.jpg", b"\xff\xd8\xff\xd9", "image/jpeg")},
        )
        print(f"replacement_probe_status={rep.status_code}")
        if rep.status_code == 400:
            d = rep.json().get("detail")
            code = d.get("code") if isinstance(d, dict) else None
            print(f"replacement_probe_code={code}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
