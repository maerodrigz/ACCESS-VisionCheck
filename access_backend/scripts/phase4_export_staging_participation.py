"""Export staging participation JSON for Flutter profile evidence (no secrets in output file)."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
REPORT_DIR = BACKEND.parent / "access_mobile_staging_backups"
BASE = "http://127.0.0.1:3011/api"
EMAIL_DEFAULT = "carlos.m@student.ustp.edu.ph"


def main() -> int:
    email = (sys.argv[1] if len(sys.argv) > 1 else EMAIL_DEFAULT).strip()
    password = os.environ.get("STAGING_MEMBER_PASSWORD", "member123")

    try:
        login_req = urllib.request.Request(
            f"{BASE}/auth/login",
            data=json.dumps({"email": email, "password": password}).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(login_req, timeout=30) as resp:
            token = json.loads(resp.read().decode()).get("token")
        if not token:
            print("FAIL: login missing token")
            return 1
        part_req = urllib.request.Request(
            f"{BASE}/member/participation",
            headers={"Authorization": f"Bearer {token}"},
            method="GET",
        )
        with urllib.request.urlopen(part_req, timeout=30) as resp:
            participation = json.loads(resp.read().decode())
    except urllib.error.URLError as exc:
        print(f"FAIL: staging API {BASE} ({exc})")
        return 1

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    out = REPORT_DIR / "phase4_staging_participation_live.json"
    payload = {
        "api_base": BASE,
        "member_email": email,
        "participation": participation,
    }
    out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"WROTE {out}")
    print(
        f"policy={participation.get('skill_progression_policy_version')} "
        f"effective={participation.get('skill_effective_tier')} "
        f"strict_v2={participation.get('skill_computed_tier_v2_strict')} "
        f"grandfather_adj={participation.get('skill_computed_tier_v2_grandfather_adjusted')} "
        f"stored_legacy={participation.get('skill_tier_stored_legacy')}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
