#!/usr/bin/env python3
"""Phase 7I: backup local .env and activate QUALITY_ENGINE=musiq_worker.

- Never prints secret values.
- Preserves all existing keys/values.
- If QUALITY_ENGINE is missing, appends musiq_worker (effective prior default was enet).
- If MUSIQ_WORKER_* connection keys are missing, appends local Docker defaults required
  for cutover (does not overwrite existing values).

Usage:
  cd /d C:\\Users\\Dell\\Desktop\\access_mobile\\access_backend
  python scripts\\apply_phase7i_local_cutover_env.py
  python scripts\\apply_phase7i_local_cutover_env.py --restore
"""

from __future__ import annotations

import argparse
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env"
OUT_DIR = ROOT / "phase7i_local_cutover"
BACKUP_DIR = OUT_DIR / "env_backups"

# Local Docker compose defaults (musiq_worker/docker-compose.yml). Not printed as secrets.
LOCAL_WORKER_DEFAULTS = {
    "MUSIQ_WORKER_URL": "http://127.0.0.1:8080",
    "MUSIQ_WORKER_TOKEN": "dev-local-musiq-token",
    "MUSIQ_WORKER_TIMEOUT_SEC": "90",
    "MUSIQ_WORKER_TLS_VERIFY": "false",
    "MUSIQ_WORKER_PREFER_REMOTE": "true",
}


def _latest_backup() -> Path | None:
    if not BACKUP_DIR.is_dir():
        return None
    backups = sorted(BACKUP_DIR.glob(".env.pre_phase7i_*"), key=lambda p: p.stat().st_mtime)
    return backups[-1] if backups else None


def _parse_keys(text: str) -> dict[str, str]:
    keys: dict[str, str] = {}
    for line in text.splitlines():
        raw = line.strip()
        if not raw or raw.startswith("#") or "=" not in raw:
            continue
        k, _, v = raw.partition("=")
        keys[k.strip()] = v
    return keys


def _set_or_append_quality_engine(text: str) -> tuple[str, str]:
    """Return (new_text, action)."""
    pattern = re.compile(r"^(\s*QUALITY_ENGINE\s*=\s*)(.*)$", re.MULTILINE)
    m = pattern.search(text)
    if m:
        old = m.group(2).strip()
        if old == "musiq_worker":
            return text, "already_musiq_worker"
        new_text = pattern.sub(r"\1musiq_worker", text, count=1)
        return new_text, f"replaced_{old or 'empty'}"
    suffix = "" if text.endswith("\n") or not text else "\n"
    block = (
        f"{suffix}\n"
        "# Phase 7I local cutover (QUALITY_ENGINE). Prior effective default was enet.\n"
        "QUALITY_ENGINE=musiq_worker\n"
    )
    return text + block, "appended"


def _append_missing_worker_keys(text: str, existing: dict[str, str]) -> tuple[str, list[str]]:
    added: list[str] = []
    out = text
    for key, value in LOCAL_WORKER_DEFAULTS.items():
        if key in existing:
            continue
        if not out.endswith("\n"):
            out += "\n"
        if not added:
            out += "\n# Phase 7I local MUSIQ worker connection (added; missing before cutover)\n"
        out += f"{key}={value}\n"
        added.append(key)
    return out, added


def apply() -> int:
    if not ENV_PATH.is_file():
        print("ERROR: .env missing")
        return 2

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = BACKUP_DIR / f".env.pre_phase7i_{stamp}"
    shutil.copy2(ENV_PATH, backup)
    # Pointer for easy restore (contains no secrets beyond being a path).
    (OUT_DIR / "LATEST_ENV_BACKUP.txt").write_text(str(backup), encoding="utf-8")

    original = ENV_PATH.read_text(encoding="utf-8")
    existing = _parse_keys(original)
    new_text, qe_action = _set_or_append_quality_engine(original)
    new_text, added_worker = _append_missing_worker_keys(new_text, existing)
    ENV_PATH.write_text(new_text, encoding="utf-8")

    after = _parse_keys(ENV_PATH.read_text(encoding="utf-8"))
    print("PHASE7I_ENV_APPLY=ok")
    print(f"BACKUP={backup.name}")
    print(f"QUALITY_ENGINE_ACTION={qe_action}")
    print(f"QUALITY_ENGINE_NOW={after.get('QUALITY_ENGINE')}")
    print(f"MUSIQ_WORKER_URL_SET={'yes' if after.get('MUSIQ_WORKER_URL') else 'no'}")
    print(f"MUSIQ_WORKER_TOKEN_SET={'yes' if after.get('MUSIQ_WORKER_TOKEN') else 'no'}")
    print(f"WORKER_KEYS_ADDED={','.join(added_worker) if added_worker else 'none'}")
    print(f"OTHER_KEYS_PRESERVED={len(existing)}")
    return 0


def restore() -> int:
    pointer = OUT_DIR / "LATEST_ENV_BACKUP.txt"
    backup = Path(pointer.read_text(encoding="utf-8").strip()) if pointer.is_file() else _latest_backup()
    if backup is None or not backup.is_file():
        print("ERROR: no Phase 7I .env backup found")
        return 2
    shutil.copy2(backup, ENV_PATH)
    print("PHASE7I_ENV_RESTORE=ok")
    print(f"RESTORED_FROM={backup.name}")
    after = _parse_keys(ENV_PATH.read_text(encoding="utf-8"))
    print(f"QUALITY_ENGINE_NOW={after.get('QUALITY_ENGINE', '(unset→enet default)')}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--restore", action="store_true")
    args = parser.parse_args()
    return restore() if args.restore else apply()


if __name__ == "__main__":
    raise SystemExit(main())
