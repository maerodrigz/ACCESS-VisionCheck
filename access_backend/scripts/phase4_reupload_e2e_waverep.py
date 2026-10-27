#!/usr/bin/env python3
"""
Phase 4 staging E2E (HTTP) — isolated QA only.

Requires:
  - PostgreSQL database access_waverep_test (NOT access / access_uat / prod)
  - Backend: python manage.py --env-file .env.waverep_test runserver --host 127.0.0.1 --port 3003
  - REPLACEMENT_UPLOAD_ENABLED=true in .env.waverep_test only

Usage:
  cd access_backend
  python scripts/phase4_reupload_e2e_waverep.py
"""

from __future__ import annotations

import json
import os
import sys
import time
import uuid
from pathlib import Path

import httpx
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(_ROOT / ".env.waverep_test", override=True)
load_dotenv(_ROOT / ".env.smoke.local", override=False)

API = os.environ.get("PHASE4_API_BASE", "http://127.0.0.1:3003/api").rstrip("/")
ADMIN_EMAIL = os.environ.get("SMOKE_ADMIN_EMAIL", "admin@access.edu")
ADMIN_PASSWORD = os.environ.get("SMOKE_ADMIN_PASSWORD", "admin123")
MEMBER_EMAIL = os.environ.get(
    "SMOKE_WAVEREP_MEMBER_EMAIL",
    os.environ.get("SMOKE_MEMBER_EMAIL", "waverep.member@example.com"),
)
MEMBER_PASSWORD = os.environ.get(
    "SMOKE_WAVEREP_MEMBER_PASSWORD",
    os.environ.get("SMOKE_MEMBER_PASSWORD", "member123"),
)

def _qa_jpeg_bytes(unique: str) -> bytes:
    """Real JPEG bytes OpenCV/EfficientNet can analyze (minimal stub JPEG fails deferred AI)."""
    import hashlib

    import cv2
    import numpy as np

    digest = hashlib.sha256(unique.encode("utf-8")).digest()
    base = int.from_bytes(digest[:3], "big")
    color = (base % 256, (base >> 8) % 256, (base >> 16) % 256)
    img = np.zeros((128, 128, 3), dtype=np.uint8)
    img[:, :] = color
    ok, buf = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
    if not ok:
        raise RuntimeError("failed to encode QA JPEG")
    return buf.tobytes()


def _assert_isolated_db() -> None:
    url = os.environ.get("DATABASE_URL", "").strip()
    if "access_waverep_test" not in url:
        raise SystemExit(
            "Refusing run: DATABASE_URL must target access_waverep_test "
            "(load .env.waverep_test)."
        )
    engine = create_engine(url, pool_pre_ping=True)
    with engine.connect() as conn:
        db = conn.execute(text("SELECT current_database()")).scalar()
        if db != "access_waverep_test":
            raise SystemExit(f"Refusing run: connected to {db!r}, expected access_waverep_test")
        mig = conn.execute(
            text(
                "SELECT 1 FROM information_schema.tables "
                "WHERE table_name = 'submission_chains'"
            )
        ).scalar()
        if not mig:
            raise SystemExit(
                "submission_chains missing — run: "
                "ACCESS_PYTEST_DB=access_waverep_test "
                "python -m app.migrations.run_submission_chains_phase1 upgrade"
            )
    engine.dispose()


def _login(client: httpx.Client, email: str, password: str) -> str:
    r = client.post(f"{API}/auth/login", json={"email": email, "password": password})
    r.raise_for_status()
    data = r.json()
    token = data.get("token") or data.get("access_token")
    if not token:
        raise RuntimeError(f"login missing token for {email}")
    return token


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _poll_eval(client: httpx.Client, token: str, media_id: int, timeout_s: int = 300) -> dict:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        mr = client.get(f"{API}/media/{media_id}", headers=_auth(token))
        if mr.status_code == 200:
            proc = (mr.json().get("processing_status") or "").lower()
            if proc == "completed" or proc == "":
                r = client.get(
                    f"{API}/evaluations?mine=true&media_id={media_id}",
                    headers=_auth(token),
                )
                if r.status_code == 200:
                    rows = r.json()
                    if isinstance(rows, list) and rows:
                        return rows[0]
        time.sleep(3)
    raise TimeoutError(f"evaluation not ready for media_id={media_id} after {timeout_s}s")


def main() -> int:
    print(f"Phase 4 E2E target: {API}")
    _assert_isolated_db()
    errors: list[str] = []

    def check(label: str, cond: bool, detail: str = "") -> None:
        if cond:
            print(f"  PASS  {label}")
        else:
            msg = f"{label}" + (f": {detail}" if detail else "")
            print(f"  FAIL  {msg}")
            errors.append(msg)

    with httpx.Client(timeout=120.0) as client:
        try:
            hr = client.get(f"{API}/health")
            check("health 200", hr.status_code == 200, hr.text[:120])
            if hr.status_code == 200:
                db_name = hr.json().get("database")
                check(
                    "health database is access_waverep_test",
                    db_name == "access_waverep_test",
                    str(db_name),
                )
        except Exception as exc:
            print(f"  FAIL  health: {exc}")
            print("\nStart isolated QA backend on 3003 with .env.waverep_test")
            return 1

        try:
            admin_tok = _login(client, ADMIN_EMAIL, ADMIN_PASSWORD)
            check("admin login", True)
        except Exception as exc:
            print(f"  FAIL  admin login: {exc}")
            return 1

        seed = uuid.uuid4().hex[:10]
        fresh_email = f"phase4.{seed}@waverep.example.com"
        fresh_password = "Phase4E2E!qa"
        create = client.post(
            f"{API}/users",
            headers=_auth(admin_tok),
            json={
                "name": f"Phase4 Member {seed}",
                "email": fresh_email,
                "password": fresh_password,
                "role": "Member",
                "status": "approved",
            },
        )
        check("admin created fresh QA member", create.status_code in (200, 201), create.text[:160])
        try:
            member_tok = _login(client, fresh_email, fresh_password)
            check("fresh member login", True)
        except Exception as exc:
            print(f"  FAIL  fresh member login: {exc}")
            return 1

        seed = uuid.uuid4().hex
        content = _qa_jpeg_bytes(seed)
        files = {"file": (f"phase4_{seed[:8]}.jpg", content, "image/jpeg")}

        r = client.post(f"{API}/media/upload", headers=_auth(member_tok), files=files)
        check("normal member upload 200", r.status_code == 200, r.text[:200])
        if r.status_code != 200:
            return 1
        root_media_id = int(r.json()["id"])

        try:
            ev0 = _poll_eval(client, member_tok, root_media_id)
            check("deferred AI eval persisted", ev0.get("overall_score") is not None)
        except TimeoutError as exc:
            check("deferred AI eval persisted", False, str(exc))

        ai_list = client.get(f"{API}/admin/ai-detection?inbox=all", headers=_auth(admin_tok))
        check("admin ai list 200", ai_list.status_code == 200)
        ai_row = None
        if ai_list.status_code == 200:
            for row in ai_list.json():
                if row.get("media_id") == root_media_id:
                    ai_row = row
                    break
        check("root in integrity inbox", ai_row is not None)

        if ai_row:
            ai_id = ai_row["id"]
            patch = client.patch(
                f"{API}/admin/ai-detection/{ai_id}",
                headers=_auth(admin_tok),
                json={
                    "review_status": "reupload_requested",
                    "admin_remarks": "Phase4 E2E: please upload a clearer original practice photo.",
                },
            )
            check("admin reupload request 200", patch.status_code == 200, patch.text[:160])

        rep_content = _qa_jpeg_bytes(seed + "rep")
        rep_files = {"file": (f"phase4_rep_{seed[:8]}.jpg", rep_content, "image/jpeg")}
        rep_data = {"replaces_media_id": str(root_media_id)}
        rep = client.post(
            f"{API}/media/upload",
            headers=_auth(member_tok),
            files=rep_files,
            data=rep_data,
        )
        check("replacement upload 200", rep.status_code == 200, rep.text[:200])
        rep_media_id = int(rep.json()["id"]) if rep.status_code == 200 else 0

        root_after = client.get(f"{API}/media/{root_media_id}", headers=_auth(member_tok))
        check("original media still readable", root_after.status_code == 200)

        chain = client.get(
            f"{API}/evaluations/chains/{root_media_id}",
            headers=_auth(member_tok),
        )
        check("member chain history 200", chain.status_code == 200)
        if chain.status_code == 200:
            body = chain.json()
            media_ids = [m["media_id"] for m in body.get("media", [])]
            check("chain lists root and replacement", root_media_id in media_ids and rep_media_id in media_ids)
            check(
                "active replacement set",
                body.get("active_replacement_media_id") == rep_media_id,
            )

        dup = client.post(
            f"{API}/media/upload",
            headers=_auth(member_tok),
            files={
                "file": (
                    f"phase4_dup_{seed[:8]}.jpg",
                    _qa_jpeg_bytes(seed + "dup"),
                    "image/jpeg",
                )
            },
            data=rep_data,
        )
        check("duplicate replacement 409", dup.status_code == 409, dup.text[:160])

        if rep_media_id:
            try:
                _poll_eval(client, member_tok, rep_media_id, timeout_s=300)
                check("replacement deferred AI eval persisted", True)
            except TimeoutError as exc:
                check("replacement deferred AI eval persisted", False, str(exc))

        lookup = client.get(
            f"{API}/admin/media/{rep_media_id}/ai-detection",
            headers=_auth(admin_tok),
        )
        check("admin ai lookup by media id 200", lookup.status_code == 200, lookup.text[:120])

        if rep_media_id and lookup.status_code == 200:
            rep_ai_id = lookup.json()["id"]
            verify = client.patch(
                f"{API}/admin/ai-detection/{rep_ai_id}",
                headers=_auth(admin_tok),
                json={
                    "review_status": "verified_human",
                    "admin_remarks": "Phase4 E2E: replacement verified as human.",
                },
            )
            check("admin verify replacement 200", verify.status_code == 200, verify.text[:160])
            chain2 = client.get(
                f"{API}/admin/media/{root_media_id}/submission-chain",
                headers=_auth(admin_tok),
            )
            if chain2.status_code == 200:
                c2 = chain2.json()
                check(
                    "lifecycle clears active replacement",
                    c2.get("active_replacement_media_id") is None,
                )
                xp_total = int(c2.get("xp_awarded_total") or 0)
                check(
                    "chain XP not double-awarded on replacement verify",
                    xp_total <= 100,
                    f"xp_awarded_total={xp_total}",
                )

        normal2 = client.post(
            f"{API}/media/upload",
            headers=_auth(member_tok),
            files={"file": (f"phase4_normal_{seed[:8]}.jpg", _qa_jpeg_bytes(seed + "norm2"), "image/jpeg")},
        )
        check("ordinary upload without replaces_media_id 200", normal2.status_code == 200)

        # Daily cap: replacements skip limit; ordinary uploads do not (fresh limit-test member).
        limit_seed = uuid.uuid4().hex[:8]
        limit_email = f"phase4.limit.{limit_seed}@waverep.example.com"
        limit_password = "Phase4Limit!qa"
        lim_create = client.post(
            f"{API}/users",
            headers=_auth(admin_tok),
            json={
                "name": f"Phase4 Limit {limit_seed}",
                "email": limit_email,
                "password": limit_password,
                "role": "Member",
                "status": "approved",
            },
        )
        check("limit-test member created", lim_create.status_code in (200, 201), lim_create.text[:120])
        if lim_create.status_code in (200, 201):
            limit_tok = _login(client, limit_email, limit_password)
            limit_root_id: int | None = None
            for i in range(5):
                up = client.post(
                    f"{API}/media/upload",
                    headers=_auth(limit_tok),
                    files={
                        "file": (
                            f"limit_{limit_seed}_{i}.jpg",
                            _qa_jpeg_bytes(f"{limit_seed}-n{i}"),
                            "image/jpeg",
                        )
                    },
                )
                if i == 0 and up.status_code == 200:
                    limit_root_id = int(up.json()["id"])
            if limit_root_id is not None:
                try:
                    _poll_eval(client, limit_tok, limit_root_id, timeout_s=240)
                except TimeoutError:
                    pass
            sixth = client.post(
                f"{API}/media/upload",
                headers=_auth(limit_tok),
                files={
                    "file": (
                        f"limit_{limit_seed}_6.jpg",
                        _qa_jpeg_bytes(f"{limit_seed}-n6"),
                        "image/jpeg",
                    )
                },
            )
            check("6th ordinary upload hits daily limit 429", sixth.status_code == 429, sixth.text[:120])
            if limit_root_id is not None:
                ai_lim = client.get(
                    f"{API}/admin/media/{limit_root_id}/ai-detection",
                    headers=_auth(admin_tok),
                )
                if ai_lim.status_code == 200:
                    client.patch(
                        f"{API}/admin/ai-detection/{ai_lim.json()['id']}",
                        headers=_auth(admin_tok),
                        json={
                            "review_status": "reupload_requested",
                            "admin_remarks": "Phase4 limit test: please re-upload a clearer photo.",
                        },
                    )
                rep_lim = client.post(
                    f"{API}/media/upload",
                    headers=_auth(limit_tok),
                    files={
                        "file": (
                            f"limit_rep_{limit_seed}.jpg",
                            _qa_jpeg_bytes(f"{limit_seed}-rep"),
                            "image/jpeg",
                        )
                    },
                    data={"replaces_media_id": str(limit_root_id)},
                )
                check(
                    "replacement upload exempt from daily limit 200",
                    rep_lim.status_code == 200,
                    rep_lim.text[:120],
                )

        if rep_media_id and chain.status_code == 200:
            rep_after = client.post(
                f"{API}/media/upload",
                headers=_auth(member_tok),
                files={
                    "file": (
                        f"phase4_rep_after_verify_{seed[:8]}.jpg",
                        _qa_jpeg_bytes(seed + "afterverify"),
                        "image/jpeg",
                    )
                },
                data={"replaces_media_id": str(root_media_id)},
            )
            check(
                "replacement blocked after verify (no reupload status)",
                rep_after.status_code in (409, 400),
                rep_after.text[:120],
            )

    print(f"\nPhase 4 summary: {len(errors)} failure(s)")
    for e in errors:
        print(f"  - {e}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
