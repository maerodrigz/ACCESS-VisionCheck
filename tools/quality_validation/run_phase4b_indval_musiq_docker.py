#!/usr/bin/env python3
"""Phase 4B: live MUSIQ on INDVAL via Docker worker HTTP (Phase 5 config).

Uses the same worker auth, multipart evaluate, and timeout patterns as
run_phase5_criterion_validation.py. Scores the frozen 100-image INDVAL holdout.

Safety rules:
  - Writes ONLY under a new musiq_live_docker_<UTC>/ directory.
  - Never overwrites machine_scores.csv, human packs, Phase 5 outputs, or
    prior musiq_live_* host-TF restore folders.
  - Never fabricates, imputes, or substitutes historical/cached MUSIQ CSV scores.
  - Requires GET /ready with the frozen Phase 5 model ids.
  - Requires a 3-image smoke test (finite musiq_opq_raw, status ok) before batch.
  - Full batch requires musiq status ok + finite score per image; failures are
    recorded, not filled in.

Usage (after Docker worker is ready; do not run until operator approves):

  access_backend/venv312/Scripts/python.exe run_phase4b_indval_musiq_docker.py
  access_backend/venv312/Scripts/python.exe run_phase4b_indval_musiq_docker.py --smoke-only
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx

_TOOLKIT = Path(__file__).resolve().parent
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

DEFAULT_MANIFEST = _TOOLKIT / "workspace" / "phase4a_indval" / "holdout_manifest.csv"
DEFAULT_OUTPUT_ROOT = _TOOLKIT / "workspace" / "phase4a_indval" / "machine_output"
MACHINE_SCORES_CSV = DEFAULT_OUTPUT_ROOT / "machine_scores.csv"
WORKER_ENV_FILE = _TOOLKIT.parents[1] / "musiq_worker" / ".env"
PHASE4A_FREEZE = _TOOLKIT / "phase4a_freeze_manifest.json"

# Exact frozen Phase 5 / Phase 6A MUSIQ identity (Docker worker).
EXPECTED_MODEL_ID = "tfhub:google/musiq/paq2piq/1"
EXPECTED_MODEL_VERSION = "paq2piq/1"
EXPECTED_ENGINE_HANDLE = "https://tfhub.dev/google/musiq/paq2piq/1"
EXPECTED_SCALE = "approx_0_100_mos_like"

PROTECTED_BASENAMES = frozenset(
    {
        "machine_scores.csv",
        "experimental_feedback_observations.csv",
    }
)


def _now_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def _write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str] | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows and not fieldnames:
        path.write_text("", encoding="utf-8")
        return
    cols = fieldnames or list(rows[0].keys())
    # Stable union of keys if rows vary
    if fieldnames is None:
        keys: list[str] = []
        for row in rows:
            for k in row:
                if k not in keys:
                    keys.append(k)
        cols = keys
    with path.open("w", newline="", encoding="utf-8") as handle:
        w = csv.DictWriter(handle, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k, "") for k in cols})


def _parse_dotenv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#") or "=" not in s:
            continue
        k, v = s.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def load_token() -> tuple[str, str]:
    """Return (token, source_label). Never log the token value."""
    env_tok = (os.environ.get("MUSIQ_WORKER_TOKEN") or "").strip()
    if env_tok:
        return env_tok, "env:MUSIQ_WORKER_TOKEN"
    dotenv = _parse_dotenv(WORKER_ENV_FILE)
    file_tok = (dotenv.get("MUSIQ_WORKER_TOKEN") or "").strip()
    if file_tok:
        return file_tok, "musiq_worker/.env"
    return "dev-local-musiq-token", "docker-compose-default"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def is_finite_number(value: Any) -> bool:
    try:
        x = float(value)
    except (TypeError, ValueError):
        return False
    return math.isfinite(x)


def musiq_score_ok(musiq: dict[str, Any] | None) -> bool:
    if not isinstance(musiq, dict):
        return False
    if musiq.get("status") != "ok":
        return False
    if musiq.get("model_id") != EXPECTED_MODEL_ID:
        return False
    if musiq.get("engine_handle") != EXPECTED_ENGINE_HANDLE:
        return False
    return is_finite_number(musiq.get("musiq_opq_raw"))


def assert_output_isolation(out_dir: Path, output_root: Path) -> None:
    """Refuse paths that would clobber protected Phase 4B artifacts."""
    out_res = out_dir.resolve()
    root_res = output_root.resolve()
    if out_res == root_res:
        raise SystemExit(
            "ERROR: output_dir must be a new musiq_live_docker_* subdirectory, "
            f"not the machine_output root ({root_res})"
        )
    if out_res.parent.resolve() != root_res:
        raise SystemExit(
            f"ERROR: output_dir {out_res} must be a direct child of output_root {root_res}"
        )
    name = out_res.name
    if not name.startswith("musiq_live_docker_"):
        raise SystemExit(
            f"ERROR: output directory name must start with musiq_live_docker_, got {name}"
        )
    if name in PROTECTED_BASENAMES or out_res.name == "machine_scores.csv":
        raise SystemExit("ERROR: refusing to overwrite machine_scores.csv")


def load_and_verify_manifest(manifest: Path) -> list[dict[str, str]]:
    if not manifest.is_file():
        raise SystemExit(f"ERROR: missing holdout manifest: {manifest}")
    rows = _read_csv(manifest)
    if len(rows) != 100:
        raise SystemExit(f"ERROR: expected 100 INDVAL rows, found {len(rows)}")
    ids = [r.get("indval_id", "") for r in rows]
    expected = [f"INDVAL-{i:03d}" for i in range(1, 101)]
    if ids != expected:
        raise SystemExit(
            "ERROR: indval_id sequence mismatch "
            f"(first={ids[:3]} last={ids[-3:] if ids else []})"
        )
    verified: list[dict[str, str]] = []
    for row in rows:
        path = Path(row["path"])
        if not path.is_file():
            raise SystemExit(f"ERROR: image missing for {row['indval_id']}: {path}")
        expected_hash = (row.get("file_sha256") or "").strip().lower()
        if not expected_hash:
            raise SystemExit(f"ERROR: missing file_sha256 for {row['indval_id']}")
        actual = sha256_file(path).lower()
        if actual != expected_hash:
            raise SystemExit(
                f"ERROR: SHA-256 mismatch for {row['indval_id']}: "
                f"manifest={expected_hash} actual={actual}"
            )
        verified.append(dict(row))
    return verified


def check_ready(base_url: str, timeout: float) -> dict[str, Any]:
    url = f"{base_url.rstrip('/')}/ready"
    try:
        with httpx.Client(timeout=timeout) as client:
            resp = client.get(url)
    except Exception as exc:  # noqa: BLE001
        raise SystemExit(
            f"ERROR: Docker MUSIQ worker unavailable at {url}: {exc}. "
            "Stop: do not substitute cached MUSIQ scores."
        ) from exc
    if resp.status_code != 200:
        raise SystemExit(
            f"ERROR: worker /ready returned HTTP {resp.status_code}: {(resp.text or '')[:300]}. "
            "Stop: do not substitute cached MUSIQ scores."
        )
    body = resp.json()
    if not isinstance(body, dict) or not body.get("musiq_ready"):
        raise SystemExit(
            f"ERROR: worker not musiq_ready: {body}. "
            "Stop: do not substitute cached MUSIQ scores."
        )
    if body.get("model_id") != EXPECTED_MODEL_ID:
        raise SystemExit(
            f"ERROR: unexpected model_id {body.get('model_id')!r}; "
            f"expected {EXPECTED_MODEL_ID!r}"
        )
    if body.get("model_version") != EXPECTED_MODEL_VERSION:
        raise SystemExit(
            f"ERROR: unexpected model_version {body.get('model_version')!r}; "
            f"expected {EXPECTED_MODEL_VERSION!r}"
        )
    handle = body.get("engine_handle")
    if handle != EXPECTED_ENGINE_HANDLE:
        raise SystemExit(
            f"ERROR: unexpected engine_handle {handle!r}; "
            f"expected {EXPECTED_ENGINE_HANDLE!r}"
        )
    return body


def evaluate_one(
    client: httpx.Client,
    base_url: str,
    token: str,
    path: Path,
    *,
    media_id: str,
) -> dict[str, Any]:
    """Phase 5-compatible multipart evaluate. Never invents MUSIQ scores."""
    t0 = time.perf_counter()
    headers = {"Authorization": f"Bearer {token}"}
    files = {"file": (path.name, path.read_bytes(), "image/jpeg")}
    data = {"media_type": "photo", "file_ext": ".jpg"}
    rec: dict[str, Any] = {
        "media_id": media_id,
        "filename": path.name,
        "path": str(path),
        "http_status": None,
        "client_error": None,
        "wall_ms": None,
        "raw": None,
    }
    try:
        resp = client.post(
            f"{base_url.rstrip('/')}/v1/evaluate",
            headers=headers,
            files=files,
            data=data,
        )
        rec["http_status"] = resp.status_code
        rec["wall_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
        if resp.status_code >= 400:
            rec["client_error"] = f"http_{resp.status_code}:{(resp.text or '')[:200]}"
            rec["raw"] = {
                "status": "error",
                "error": rec["client_error"],
                "musiq": None,
            }
            return rec
        body = resp.json()
        if not isinstance(body, dict):
            rec["client_error"] = "invalid_json"
            rec["raw"] = {"status": "error", "error": "invalid_json", "musiq": None}
            return rec
        rec["raw"] = body
        return rec
    except Exception as exc:  # noqa: BLE001
        rec["wall_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
        rec["client_error"] = f"request_failed:{type(exc).__name__}"
        rec["raw"] = {
            "status": "error",
            "error": rec["client_error"],
            "musiq": None,
        }
        return rec


def flatten_musiq_row(rec: dict[str, Any], manifest_row: dict[str, str]) -> dict[str, Any]:
    raw = rec.get("raw") or {}
    musiq = raw.get("musiq") if isinstance(raw.get("musiq"), dict) else {}
    ok = musiq_score_ok(musiq) and not rec.get("client_error")
    return {
        "indval_id": manifest_row.get("indval_id") or rec.get("media_id"),
        "source_media_key": manifest_row.get("source_media_key"),
        "pool": manifest_row.get("pool"),
        "file_sha256": manifest_row.get("file_sha256"),
        "path": manifest_row.get("path") or rec.get("path"),
        "filename": rec.get("filename"),
        "http_status": rec.get("http_status"),
        "client_error": rec.get("client_error"),
        "wall_ms": rec.get("wall_ms"),
        "worker_status": raw.get("status"),
        "worker_error": raw.get("error"),
        "worker_version": raw.get("worker_version"),
        "classical_map_version": raw.get("classical_map_version"),
        "duration_ms": raw.get("duration_ms"),
        "musiq_status": musiq.get("status"),
        "musiq_opq_raw": musiq.get("musiq_opq_raw") if ok else None,
        "musiq_scale": musiq.get("musiq_scale") or EXPECTED_SCALE,
        "musiq_model_id": musiq.get("model_id"),
        "musiq_model_version": musiq.get("model_version"),
        "musiq_engine_handle": musiq.get("engine_handle"),
        "musiq_error": musiq.get("error"),
        "musiq_finite_ok": ok,
        "soft_score_applied_to_musiq": raw.get("soft_score_applied_to_musiq"),
        "production_payload_mutated": raw.get("production_payload_mutated"),
        "cached_musiq_csv_used": False,
        "fabricated_or_imputed": False,
    }


def failed_row_from(flat: dict[str, Any]) -> dict[str, Any] | None:
    if flat.get("musiq_finite_ok"):
        return None
    return {
        "indval_id": flat.get("indval_id"),
        "http_status": flat.get("http_status"),
        "client_error": flat.get("client_error"),
        "worker_status": flat.get("worker_status"),
        "worker_error": flat.get("worker_error"),
        "musiq_status": flat.get("musiq_status"),
        "musiq_error": flat.get("musiq_error"),
        "musiq_opq_raw": flat.get("musiq_opq_raw"),
        "note": "live_musiq_not_ok_no_imputation",
    }


def run_smoke(
    client: httpx.Client,
    base_url: str,
    token: str,
    rows: list[dict[str, str]],
    *,
    smoke_n: int = 3,
) -> dict[str, Any]:
    sample = rows[:smoke_n]
    results: list[dict[str, Any]] = []
    for row in sample:
        path = Path(row["path"])
        indval = row["indval_id"]
        first = evaluate_one(client, base_url, token, path, media_id=indval)
        second = evaluate_one(client, base_url, token, path, media_id=indval)
        m1 = (first.get("raw") or {}).get("musiq") if isinstance(first.get("raw"), dict) else None
        m2 = (second.get("raw") or {}).get("musiq") if isinstance(second.get("raw"), dict) else None
        ok1 = musiq_score_ok(m1) and not first.get("client_error")
        ok2 = musiq_score_ok(m2) and not second.get("client_error")
        s1 = m1.get("musiq_opq_raw") if isinstance(m1, dict) else None
        s2 = m2.get("musiq_opq_raw") if isinstance(m2, dict) else None
        handle_ok = (
            isinstance(m1, dict)
            and m1.get("engine_handle") == EXPECTED_ENGINE_HANDLE
            and m1.get("model_id") == EXPECTED_MODEL_ID
        )
        deterministic = ok1 and ok2 and float(s1) == float(s2)
        smoke_pass = bool(ok1 and ok2 and handle_ok and deterministic)
        results.append(
            {
                "indval_id": indval,
                "source_media_key": row.get("source_media_key"),
                "path": str(path),
                "pass1_musiq_opq_raw": s1 if ok1 else None,
                "pass2_musiq_opq_raw": s2 if ok2 else None,
                "pass1_status": (m1 or {}).get("status") if isinstance(m1, dict) else None,
                "pass2_status": (m2 or {}).get("status") if isinstance(m2, dict) else None,
                "pass1_wall_ms": first.get("wall_ms"),
                "pass2_wall_ms": second.get("wall_ms"),
                "pass1_client_error": first.get("client_error"),
                "pass2_client_error": second.get("client_error"),
                "deterministic_repeat": deterministic,
                "handle_ok": handle_ok,
                "smoke_pass": smoke_pass,
                # Keep raw for debugging smoke only (no token)
                "pass1_http_status": first.get("http_status"),
                "pass2_http_status": second.get("http_status"),
            }
        )
    return {
        "n": len(results),
        "all_pass": all(r["smoke_pass"] for r in results) and len(results) == smoke_n,
        "expected_model_id": EXPECTED_MODEL_ID,
        "expected_engine_handle": EXPECTED_ENGINE_HANDLE,
        "cached_musiq_csv_used": False,
        "results": results,
    }


def write_outputs(
    out_dir: Path,
    *,
    meta: dict[str, Any],
    smoke: dict[str, Any],
    score_rows: list[dict[str, Any]],
    jsonl_records: list[dict[str, Any]],
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "run_meta.json").write_text(
        json.dumps(meta, indent=2) + "\n", encoding="utf-8"
    )
    (out_dir / "smoke_test_3.json").write_text(
        json.dumps(smoke, indent=2) + "\n", encoding="utf-8"
    )
    with (out_dir / "live_evaluations.jsonl").open("w", encoding="utf-8") as jf:
        for rec in jsonl_records:
            jf.write(json.dumps(rec, ensure_ascii=False) + "\n")
    _write_csv(out_dir / "musiq_live_scores.csv", score_rows)
    failed = [fr for row in score_rows if (fr := failed_row_from(row)) is not None]
    if not failed:
        if meta.get("blocker"):
            failed = [
                {
                    "indval_id": "",
                    "note": "batch_not_run",
                    "blocker": meta.get("blocker"),
                }
            ]
        else:
            failed = [{"indval_id": "", "note": "no_failed_or_partial_rows"}]
    _write_csv(out_dir / "failed_or_partial.csv", failed)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    ap.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    ap.add_argument(
        "--worker-url",
        default=os.environ.get("MUSIQ_WORKER_URL", "http://127.0.0.1:8080"),
    )
    ap.add_argument(
        "--timeout-sec",
        type=float,
        default=float(os.environ.get("MUSIQ_WORKER_TIMEOUT_SEC", "120")),
    )
    ap.add_argument("--smoke-n", type=int, default=3)
    ap.add_argument("--smoke-only", action="store_true")
    ap.add_argument("--limit", type=int, default=None, help="Dev/test only; omit for full 100")
    ap.add_argument("--run-tag", type=str, default=None)
    args = ap.parse_args(argv)

    stamp = args.run_tag or _now_stamp()
    out_dir = args.output_root / f"musiq_live_docker_{stamp}"
    assert_output_isolation(out_dir, args.output_root)

    print("Phase 4B INDVAL Docker MUSIQ: preflight…")
    rows = load_and_verify_manifest(args.manifest)
    print(f"  manifest OK: {len(rows)} INDVAL images, SHA-256 verified")

    if MACHINE_SCORES_CSV.is_file():
        print(f"  preserving existing OpenCV artifact: {MACHINE_SCORES_CSV}")

    ready = check_ready(args.worker_url, args.timeout_sec)
    print(
        f"  worker ready: model_id={ready.get('model_id')} "
        f"version={ready.get('model_version')}"
    )

    token, token_source = load_token()
    print(f"  token source: {token_source} (value not printed)")

    freeze_id = None
    if PHASE4A_FREEZE.is_file():
        try:
            freeze_id = json.loads(PHASE4A_FREEZE.read_text(encoding="utf-8")).get(
                "freeze_id"
            )
        except Exception:  # noqa: BLE001
            freeze_id = None

    out_dir.mkdir(parents=True, exist_ok=False)
    print(f"  output: {out_dir}")

    meta: dict[str, Any] = {
        "started_at_utc": datetime.now(timezone.utc).isoformat(),
        "protocol": "phase4b_indval_musiq_docker",
        "freeze_id": freeze_id,
        "manifest": str(args.manifest.resolve()),
        "output_dir": str(out_dir.resolve()),
        "worker_url": args.worker_url,
        "token_source": token_source,
        "ready": ready,
        "expected_model_id": EXPECTED_MODEL_ID,
        "expected_model_version": EXPECTED_MODEL_VERSION,
        "expected_engine_handle": EXPECTED_ENGINE_HANDLE,
        "preserves_machine_scores_csv": True,
        "preserves_human_ratings": True,
        "preserves_phase5_outputs": True,
        "cached_musiq_csv_used": False,
        "fabricated_or_imputed": False,
        "smoke_n": args.smoke_n,
        "smoke_only": bool(args.smoke_only),
        "limit": args.limit,
        "n_manifest": len(rows),
    }

    batch_rows = list(rows)
    if args.limit is not None:
        batch_rows = batch_rows[: args.limit]

    with httpx.Client(timeout=args.timeout_sec) as client:
        smoke = run_smoke(
            client,
            args.worker_url,
            token,
            rows,
            smoke_n=args.smoke_n,
        )
        meta["smoke_all_pass"] = smoke["all_pass"]
        if not smoke["all_pass"]:
            meta["blocker"] = (
                "Three-image smoke test failed; refusing full holdout run. "
                "Do not substitute cached MUSIQ scores."
            )
            meta["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
            write_outputs(
                out_dir,
                meta=meta,
                smoke=smoke,
                score_rows=[],
                jsonl_records=[],
            )
            print(meta["blocker"], flush=True)
            return 3

        if args.smoke_only:
            meta["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
            meta["n_musiq_ok"] = sum(1 for r in smoke["results"] if r["smoke_pass"])
            write_outputs(
                out_dir,
                meta=meta,
                smoke=smoke,
                score_rows=[],
                jsonl_records=[],
            )
            print(f"[MUSIQ] smoke-only complete -> {out_dir}", flush=True)
            return 0

        score_rows: list[dict[str, Any]] = []
        jsonl_records: list[dict[str, Any]] = []
        for i, row in enumerate(batch_rows, start=1):
            indval = row["indval_id"]
            path = Path(row["path"])
            print(f"  evaluate {i}/{len(batch_rows)} {indval}…", flush=True)
            rec = evaluate_one(client, args.worker_url, token, path, media_id=indval)
            safe_rec = {
                "media_id": rec["media_id"],
                "filename": rec["filename"],
                "path": rec["path"],
                "http_status": rec["http_status"],
                "client_error": rec["client_error"],
                "wall_ms": rec["wall_ms"],
                "raw": rec["raw"],
            }
            jsonl_records.append(safe_rec)
            flat = flatten_musiq_row(rec, row)
            # Never impute: leave musiq_opq_raw null when not ok
            if not flat["musiq_finite_ok"]:
                flat["musiq_opq_raw"] = None
            score_rows.append(flat)
            print(
                f"    musiq={flat.get('musiq_status')} "
                f"opq={flat.get('musiq_opq_raw')} ok={flat.get('musiq_finite_ok')}",
                flush=True,
            )

    n_ok = sum(1 for r in score_rows if r.get("musiq_finite_ok"))
    meta["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
    meta["n_target"] = len(batch_rows)
    meta["n_scored"] = len(score_rows)
    meta["n_musiq_ok"] = n_ok
    meta["n_musiq_failed"] = len(score_rows) - n_ok
    write_outputs(
        out_dir,
        meta=meta,
        smoke=smoke,
        score_rows=score_rows,
        jsonl_records=jsonl_records,
    )
    print(f"[MUSIQ] live docker scores -> {out_dir} ok={n_ok}/{len(score_rows)}", flush=True)
    if n_ok != len(score_rows):
        return 4
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
