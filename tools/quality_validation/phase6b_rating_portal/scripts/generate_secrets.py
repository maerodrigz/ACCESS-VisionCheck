#!/usr/bin/env python3
"""Generate evaluator invite tokens + facilitator token (print once; store as secrets)."""

from __future__ import annotations

import argparse
import secrets
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--write-env", type=Path, default=None, help="Optional .env path to write")
    ap.add_argument("--public-base-url", default="http://127.0.0.1:8090")
    args = ap.parse_args()

    tokens = {f"R{i}": secrets.token_urlsafe(24) for i in (1, 2, 3)}
    fac = secrets.token_urlsafe(32)
    invites = ",".join(f"{k}:{v}" for k, v in tokens.items())

    print("=== Store these as secrets. Do not commit. ===")
    print(f"EVALUATOR_INVITES={invites}")
    print(f"FACILITATOR_TOKEN={fac}")
    print(f"PUBLIC_BASE_URL={args.public_base_url}")
    print("")
    print("Evaluator links:")
    for eid, tok in tokens.items():
        print(f"  {eid}: {args.public_base_url.rstrip('/')}/r/{tok}")
    print(f"Facilitator export header: X-Facilitator-Token: <FACILITATOR_TOKEN>")

    if args.write_env:
        args.write_env.write_text(
            "\n".join(
                [
                    f"EVALUATOR_INVITES={invites}",
                    f"FACILITATOR_TOKEN={fac}",
                    f"PUBLIC_BASE_URL={args.public_base_url}",
                    "PORT=8090",
                    "ALLOW_BOOTSTRAP_WITHOUT_SECRETS=false",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        print(f"Wrote {args.write_env} (keep private)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
