#!/usr/bin/env python3
"""Phase 7D: performance benchmark — EfficientNet-B0 vs MUSIQ+OpenCV vs local OpenCV.

Process-local only. Does not modify .env, Flutter, DB, authenticity, or Phase 6B artifacts.
Does not change production QUALITY_ENGINE.

Usage (Windows CMD):
  cd /d C:\\Users\\Dell\\Desktop\\access_mobile\\access_backend
  python scripts\\benchmark_quality_engines_phase7d.py
"""

from __future__ import annotations

import gc
import json
import os
import statistics
import subprocess
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

OUT_DIR = ROOT / "phase7d_performance_benchmark"
IMAGE_DIR = Path(r"C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos")
WARMUP = int(os.environ.get("PHASE7D_WARMUP", "2"))
MEASURED = int(os.environ.get("PHASE7D_MEASURED", "10"))
# Default worker settings for this process only (do not write .env).
os.environ.setdefault("MUSIQ_WORKER_URL", "http://127.0.0.1:8080")
os.environ.setdefault("MUSIQ_WORKER_TOKEN", "dev-local-musiq-token")
os.environ.setdefault("MUSIQ_WORKER_TIMEOUT_SEC", "120")
os.environ.setdefault("MUSIQ_WORKER_TLS_VERIFY", "false")


def _percentile(sorted_vals: list[float], p: float) -> float:
    if not sorted_vals:
        return float("nan")
    if len(sorted_vals) == 1:
        return float(sorted_vals[0])
    k = (len(sorted_vals) - 1) * (p / 100.0)
    f = int(k)
    c = min(f + 1, len(sorted_vals) - 1)
    if f == c:
        return float(sorted_vals[f])
    return float(sorted_vals[f] + (sorted_vals[c] - sorted_vals[f]) * (k - f))


def _summarize_ms(samples_ms: list[float]) -> dict[str, float]:
    ordered = sorted(samples_ms)
    return {
        "n": float(len(ordered)),
        "mean_ms": float(statistics.fmean(ordered)) if ordered else float("nan"),
        "median_ms": float(statistics.median(ordered)) if ordered else float("nan"),
        "p95_ms": _percentile(ordered, 95.0),
        "min_ms": float(ordered[0]) if ordered else float("nan"),
        "max_ms": float(ordered[-1]) if ordered else float("nan"),
        "stdev_ms": float(statistics.stdev(ordered)) if len(ordered) > 1 else 0.0,
    }


def _rss_mb() -> float | None:
    try:
        import psutil

        return float(psutil.Process(os.getpid()).memory_info().rss) / (1024.0 * 1024.0)
    except Exception:
        try:
            import ctypes
            from ctypes import wintypes

            class PROCESS_MEMORY_COUNTERS(ctypes.Structure):
                _fields_ = [
                    ("cb", wintypes.DWORD),
                    ("PageFaultCount", wintypes.DWORD),
                    ("PeakWorkingSetSize", ctypes.c_size_t),
                    ("WorkingSetSize", ctypes.c_size_t),
                    ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                    ("PagefileUsage", ctypes.c_size_t),
                    ("PeakPagefileUsage", ctypes.c_size_t),
                ]

            GetCurrentProcess = ctypes.windll.kernel32.GetCurrentProcess
            GetProcessMemoryInfo = ctypes.windll.psapi.GetProcessMemoryInfo
            counters = PROCESS_MEMORY_COUNTERS()
            counters.cb = ctypes.sizeof(PROCESS_MEMORY_COUNTERS)
            if GetProcessMemoryInfo(GetCurrentProcess(), ctypes.byref(counters), counters.cb):
                return float(counters.WorkingSetSize) / (1024.0 * 1024.0)
        except Exception:
            return None
    return None


def _system_ram_mb() -> dict[str, float | None]:
    try:
        import psutil

        vm = psutil.virtual_memory()
        return {
            "total_mb": float(vm.total) / (1024.0 * 1024.0),
            "used_mb": float(vm.used) / (1024.0 * 1024.0),
            "available_mb": float(vm.available) / (1024.0 * 1024.0),
            "percent": float(vm.percent),
        }
    except Exception:
        return {"total_mb": None, "used_mb": None, "available_mb": None, "percent": None}


def _cpu_percent(interval: float = 0.0) -> float | None:
    try:
        import psutil

        if interval > 0:
            return float(psutil.cpu_percent(interval=interval))
        psutil.cpu_percent(interval=None)
        return float(psutil.Process(os.getpid()).cpu_percent(interval=0.2))
    except Exception:
        return None


def _docker_stats_musiq() -> dict[str, Any] | None:
    """Best-effort Docker worker resource sample (separate from FastAPI process)."""
    try:
        # Prefer container name from compose; fall back to any *musiq* match.
        listing = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}"],
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        if listing.returncode != 0:
            return {"error": listing.stderr.strip() or listing.stdout.strip() or "docker_ps_failed"}
        names = [ln.strip() for ln in listing.stdout.splitlines() if ln.strip()]
        targets = [n for n in names if "musiq" in n.lower()]
        if not targets:
            return {"error": "no_musiq_container_running", "containers": names}
        name = targets[0]
        stats = subprocess.run(
            [
                "docker",
                "stats",
                name,
                "--no-stream",
                "--format",
                "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}",
            ],
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
        if stats.returncode != 0:
            return {"error": stats.stderr.strip() or "docker_stats_failed", "container": name}
        line = (stats.stdout or "").strip().splitlines()[-1] if stats.stdout.strip() else ""
        parts = line.split("\t")
        out: dict[str, Any] = {"container": name, "raw": line}
        if len(parts) >= 4:
            out["cpu_perc_str"] = parts[1].strip()
            out["mem_usage_str"] = parts[2].strip()
            out["mem_perc_str"] = parts[3].strip()
            try:
                out["cpu_percent"] = float(parts[1].strip().replace("%", ""))
            except ValueError:
                out["cpu_percent"] = None
        return out
    except FileNotFoundError:
        return {"error": "docker_cli_not_found"}
    except Exception as exc:  # noqa: BLE001
        return {"error": f"{type(exc).__name__}: {exc}"}


def _select_images(n: int) -> list[Path]:
    files = sorted(
        [
            p
            for p in IMAGE_DIR.iterdir()
            if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png"}
        ],
        key=lambda p: p.name.lower(),
    )
    if len(files) < n:
        raise SystemExit(f"Need >= {n} images in {IMAGE_DIR}, found {len(files)}")
    return files[:n]


def _bind_worker_settings() -> None:
    from app.config import settings

    settings.musiq_worker_url = os.environ["MUSIQ_WORKER_URL"]
    settings.musiq_worker_token = os.environ["MUSIQ_WORKER_TOKEN"]
    settings.musiq_worker_timeout_sec = float(os.environ.get("MUSIQ_WORKER_TIMEOUT_SEC", "120"))
    settings.musiq_worker_tls_verify = os.environ.get("MUSIQ_WORKER_TLS_VERIFY", "false").lower() in (
        "1",
        "true",
        "yes",
    )
    # Keep production scoring config conceptually on enet; we call engines directly.
    settings.quality_engine = "enet"
    settings.quality_shadow_enabled = False


def _run_timed(fn: Callable[[], Any]) -> tuple[Any, float]:
    t0 = time.perf_counter()
    result = fn()
    dt_ms = (time.perf_counter() - t0) * 1000.0
    return result, dt_ms


def main() -> int:
    from dotenv import load_dotenv

    load_dotenv(ROOT / ".env", override=False)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    images = _select_images(MEASURED)
    # Warm-up uses the first image(s) only; measured set is the same N images for all engines.
    warmup_images = images[: min(WARMUP, len(images))]

    report: dict[str, Any] = {
        "phase": "7D",
        "title": "Quality engine performance benchmark",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "host": {
            "pid": os.getpid(),
            "cwd": str(ROOT),
            "system_ram_before_mb": _system_ram_mb(),
            "process_rss_before_mb": _rss_mb(),
        },
        "config": {
            "warmup_runs_per_engine": WARMUP,
            "measured_evals_per_engine": MEASURED,
            "image_dir": str(IMAGE_DIR),
            "images": [{"name": p.name, "bytes": p.stat().st_size} for p in images],
            "env_file_modified": False,
            "production_scoring_unchanged": True,
            "notes": [
                "MUSIQ OPQ is context-only; criterion scores come from worker classical OpenCV raw via adapter.",
                "FastAPI process RSS/CPU measured in this Python process (direct scorers, not full HTTP server).",
                "Docker worker resources sampled via docker stats (separate from FastAPI process).",
            ],
        },
        "engines": {},
        "errors": [],
    }

    _bind_worker_settings()

    from app.services import efficientnet_b0_scorer as enet
    from app.services import opencv_quality as ocv
    from app.services.musiq_worker_client import evaluate_bytes as musiq_evaluate_bytes
    from app.services.musiq_worker_client import readiness_check
    from app.services.musiq_quality_adapter import metrics_from_worker_result, strip_adapter_metadata

    # --- Init timings ---
    init: dict[str, Any] = {}
    gc.collect()
    # Force ENET cold-ish re-init by clearing module cache when possible.
    enet._model = None  # noqa: SLF001
    t0 = time.perf_counter()
    enet_ready = bool(enet.efficientnet_available() and enet.ensure_weights())
    init["efficientnet_b0"] = {
        "init_ms": (time.perf_counter() - t0) * 1000.0,
        "ready": enet_ready,
        "weights_path": str(enet.weights_path()),
        "weights_exists": enet.weights_path().is_file(),
    }

    t0 = time.perf_counter()
    ocv_ready = bool(ocv.opencv_available())
    # Touch decode path once for import side-effects.
    if ocv_ready and images:
        ocv.analyze_image_bytes(images[0].read_bytes())
    init["opencv_local"] = {
        "init_ms": (time.perf_counter() - t0) * 1000.0,
        "ready": ocv_ready,
        "note": "OpenCV has no separate weights file; init includes first analyze on image[0].",
    }

    t0 = time.perf_counter()
    ready = readiness_check()
    init["musiq_worker"] = {
        "init_ms": (time.perf_counter() - t0) * 1000.0,
        "ready": bool(ready.get("ready")),
        "readiness": ready,
        "note": "Worker model load happens inside Docker; this times HTTPS /ready from the FastAPI host process.",
    }
    report["initialization"] = init
    report["docker_worker_stats_before"] = _docker_stats_musiq()
    report["system_ram_after_init_mb"] = _system_ram_mb()
    report["process_rss_after_init_mb"] = _rss_mb()

    def bench_engine(
        name: str,
        *,
        ready_flag: bool,
        call: Callable[[bytes, str], dict[str, Any] | None],
        sample_docker: bool = False,
    ) -> dict[str, Any]:
        block: dict[str, Any] = {
            "engine": name,
            "ready": ready_flag,
            "warmup": [],
            "runs": [],
            "skipped": False,
        }
        if not ready_flag:
            block["skipped"] = True
            block["skip_reason"] = "engine_not_ready"
            return block

        # Warm-up (not included in latency stats).
        for i, path in enumerate(warmup_images):
            content = path.read_bytes()
            rss0 = _rss_mb()
            result, dt = _run_timed(lambda c=content, n=path.name: call(c, n))
            block["warmup"].append(
                {
                    "image": path.name,
                    "latency_ms": dt,
                    "ok": result is not None,
                    "rss_mb_after": _rss_mb(),
                    "rss_mb_before": rss0,
                }
            )

        cpu_samples: list[float] = []
        rss_samples: list[float] = []
        docker_samples: list[dict[str, Any]] = []
        latencies: list[float] = []

        for path in images:
            content = path.read_bytes()
            rss_before = _rss_mb()
            cpu_before = _cpu_percent(0.0)
            result, dt = _run_timed(lambda c=content, n=path.name: call(c, n))
            rss_after = _rss_mb()
            cpu_after = _cpu_percent(0.0)
            if cpu_after is not None:
                cpu_samples.append(cpu_after)
            if rss_after is not None:
                rss_samples.append(rss_after)
            if sample_docker:
                ds = _docker_stats_musiq()
                if ds:
                    docker_samples.append(ds)

            run_rec: dict[str, Any] = {
                "image": path.name,
                "image_bytes": len(content),
                "latency_ms": dt,
                "ok": result is not None,
                "rss_mb_before": rss_before,
                "rss_mb_after": rss_after,
                "process_cpu_percent": cpu_after,
                "cpu_percent_pre": cpu_before,
            }
            # Capture quality payload shape without confusing OPQ with criteria.
            if isinstance(result, dict):
                run_rec["result_keys"] = sorted(result.keys())
                if "sharpness" in result:
                    run_rec["sample_criterion_sharpness"] = result.get("sharpness")
                if "musiq_opq_raw" in result:
                    run_rec["musiq_opq_raw_context_only"] = result.get("musiq_opq_raw")
                    run_rec["note"] = "musiq_opq_raw is OPQ context, not an OpenCV criterion score"
                if result.get("_adapter_error"):
                    run_rec["adapter_error"] = result.get("_adapter_error")
            latencies.append(dt)
            block["runs"].append(run_rec)

        ok_lat = [r["latency_ms"] for r in block["runs"] if r.get("ok")]
        block["latency_summary_ms"] = _summarize_ms(ok_lat)
        block["latency_all_runs_ms"] = _summarize_ms(latencies)
        block["process_rss_mb"] = {
            "mean": float(statistics.fmean(rss_samples)) if rss_samples else None,
            "max": float(max(rss_samples)) if rss_samples else None,
            "min": float(min(rss_samples)) if rss_samples else None,
            "samples": len(rss_samples),
        }
        block["process_cpu_percent"] = {
            "mean": float(statistics.fmean(cpu_samples)) if cpu_samples else None,
            "max": float(max(cpu_samples)) if cpu_samples else None,
            "samples": len(cpu_samples),
            "note": "psutil process cpu_percent over ~0.2s sample after each eval",
        }
        if sample_docker and docker_samples:
            block["docker_worker_stats_samples"] = docker_samples
            cpu_d = [s.get("cpu_percent") for s in docker_samples if isinstance(s.get("cpu_percent"), (int, float))]
            block["docker_worker_cpu_percent"] = {
                "mean": float(statistics.fmean(cpu_d)) if cpu_d else None,
                "max": float(max(cpu_d)) if cpu_d else None,
                "n": len(cpu_d),
            }
            block["docker_worker_mem_usage_last"] = docker_samples[-1].get("mem_usage_str")
        block["ok_count"] = sum(1 for r in block["runs"] if r.get("ok"))
        block["fail_count"] = sum(1 for r in block["runs"] if not r.get("ok"))
        return block

    # --- Callables ---
    def call_enet(content: bytes, _name: str) -> dict[str, Any] | None:
        return enet.analyze_image_bytes(content)

    def call_opencv(content: bytes, _name: str) -> dict[str, Any] | None:
        return ocv.analyze_image_bytes(content)

    def call_musiq(content: bytes, name: str) -> dict[str, Any] | None:
        worker = musiq_evaluate_bytes(content, media_type="photo", filename=name)
        mapped = metrics_from_worker_result(worker, content=content)
        if mapped is None:
            return None
        clean, ctx = strip_adapter_metadata(mapped)
        # Attach OPQ context separately so it is not mistaken for a criterion.
        out = dict(clean)
        if ctx:
            out["musiq_opq_raw"] = ctx.get("musiq_opq_raw")
            out["musiq_opq_context_only"] = True
        return out

    print("Benchmarking EfficientNet-B0...", flush=True)
    report["engines"]["efficientnet_b0"] = bench_engine(
        "efficientnet_b0",
        ready_flag=enet_ready,
        call=call_enet,
        sample_docker=False,
    )

    print("Benchmarking local OpenCV...", flush=True)
    report["engines"]["opencv_local"] = bench_engine(
        "opencv_local",
        ready_flag=ocv_ready,
        call=call_opencv,
        sample_docker=False,
    )

    print("Benchmarking MUSIQ worker + classical OpenCV adapter...", flush=True)
    report["engines"]["musiq_worker_opencv"] = bench_engine(
        "musiq_worker_opencv",
        ready_flag=bool(ready.get("ready")),
        call=call_musiq,
        sample_docker=True,
    )

    report["docker_worker_stats_after"] = _docker_stats_musiq()
    report["system_ram_after_mb"] = _system_ram_mb()
    report["process_rss_after_mb"] = _rss_mb()
    report["finished_at"] = datetime.now(timezone.utc).isoformat()

    # Comparison table + recommendation from measured numbers only.
    table_rows = []
    for key, label in (
        ("efficientnet_b0", "EfficientNet-B0 (local PyTorch)"),
        ("musiq_worker_opencv", "MUSIQ + OpenCV (Docker worker)"),
        ("opencv_local", "OpenCV-only (local fallback)"),
    ):
        eng = report["engines"].get(key) or {}
        lat = eng.get("latency_summary_ms") or {}
        table_rows.append(
            {
                "evaluator": label,
                "engine_key": key,
                "ready": eng.get("ready"),
                "ok_count": eng.get("ok_count"),
                "mean_ms": lat.get("mean_ms"),
                "median_ms": lat.get("median_ms"),
                "p95_ms": lat.get("p95_ms"),
                "process_rss_mean_mb": (eng.get("process_rss_mb") or {}).get("mean"),
                "process_rss_max_mb": (eng.get("process_rss_mb") or {}).get("max"),
                "process_cpu_mean_pct": (eng.get("process_cpu_percent") or {}).get("mean"),
                "docker_cpu_mean_pct": (eng.get("docker_worker_cpu_percent") or {}).get("mean"),
                "docker_mem_usage": eng.get("docker_worker_mem_usage_last"),
                "init_ms": (report.get("initialization") or {}).get(key if key != "musiq_worker_opencv" else "musiq_worker", {}).get("init_ms")
                if key != "opencv_local"
                else (report.get("initialization") or {}).get("opencv_local", {}).get("init_ms"),
            }
        )
    # Fix init_ms mapping explicitly
    table_rows[0]["init_ms"] = (report.get("initialization") or {}).get("efficientnet_b0", {}).get("init_ms")
    table_rows[1]["init_ms"] = (report.get("initialization") or {}).get("musiq_worker", {}).get("init_ms")
    table_rows[2]["init_ms"] = (report.get("initialization") or {}).get("opencv_local", {}).get("init_ms")

    report["comparison_table"] = table_rows
    report["recommendation"] = _recommend(table_rows, report)

    raw_path = OUT_DIR / "benchmark_raw.json"
    table_path = OUT_DIR / "comparison_table.csv"
    md_path = OUT_DIR / "BENCHMARK_REPORT.md"

    raw_path.write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")
    _write_csv(table_path, table_rows)
    _write_md(md_path, report, table_rows)

    print(json.dumps({"comparison_table": table_rows, "recommendation": report["recommendation"]}, indent=2, default=str))
    print("wrote", raw_path)
    print("wrote", table_path)
    print("wrote", md_path)
    return 0


def _recommend(rows: list[dict[str, Any]], report: dict[str, Any]) -> dict[str, Any]:
    """Recommendation based only on measured rows that completed successfully."""
    usable = [r for r in rows if r.get("ready") and r.get("ok_count")]
    if not usable:
        return {
            "production_architecture": "insufficient_data",
            "rationale": "No engine completed measured evaluations.",
        }

    def mean_ms(r: dict[str, Any]) -> float:
        v = r.get("mean_ms")
        return float(v) if isinstance(v, (int, float)) else float("inf")

    fastest = min(usable, key=mean_ms)
    musiq = next((r for r in rows if r["engine_key"] == "musiq_worker_opencv"), None)
    enet = next((r for r in rows if r["engine_key"] == "efficientnet_b0"), None)
    ocv = next((r for r in rows if r["engine_key"] == "opencv_local"), None)

    parts = [
        f"Fastest mean latency among successful engines: {fastest['evaluator']} "
        f"({fastest.get('mean_ms'):.1f} ms)."
        if isinstance(fastest.get("mean_ms"), (int, float))
        else f"Fastest engine key: {fastest['engine_key']}.",
    ]
    if musiq and musiq.get("ok_count"):
        parts.append(
            "MUSIQ path adds Docker worker RAM/CPU separate from the FastAPI process; "
            f"worker mem sample={musiq.get('docker_mem_usage')!s}, "
            f"worker CPU mean%={musiq.get('docker_cpu_mean_pct')!s}."
        )
        parts.append(
            "Keep MUSIQ OPQ as overall perceptual context only; individual 1-5 criteria "
            "remain classical OpenCV (adapter) + FastAPI color/temporal."
        )
    if enet and not enet.get("ok_count"):
        parts.append("EfficientNet-B0 did not complete measured runs on this host; keep weights for rollback but do not rely on it until fixed.")
    elif enet and enet.get("ok_count"):
        parts.append(
            "Retain EfficientNet-B0 checkpoint as rollback/fallback; do not delete."
        )

    # Architecture recommendation preference: measured data driven.
    # Prefer musiq_worker for production quality if it completed and P95 is acceptable vs ENET,
    # with ENET then OpenCV fallback — matching Phase 7A design.
    arch = "QUALITY_ENGINE=musiq_worker with fallback EfficientNet-B0 then local OpenCV"
    if musiq and not musiq.get("ok_count"):
        arch = "Keep QUALITY_ENGINE=enet until MUSIQ worker benchmark succeeds"
    if enet and enet.get("ok_count") and musiq and musiq.get("ok_count"):
        enet_p95 = enet.get("p95_ms")
        musiq_p95 = musiq.get("p95_ms")
        if isinstance(enet_p95, (int, float)) and isinstance(musiq_p95, (int, float)):
            if musiq_p95 > enet_p95 * 5:
                parts.append(
                    f"MUSIQ P95 ({musiq_p95:.0f} ms) is >5x ENET P95 ({enet_p95:.0f} ms); "
                    "consider keeping enet default for latency-sensitive paths or raise worker timeout/capacity."
                )
    if ocv and ocv.get("ok_count"):
        parts.append(
            f"OpenCV-only is the lightest local fallback (mean {ocv.get('mean_ms')} ms); "
            "required when both worker and ENET are unavailable."
        )

    return {
        "production_architecture": arch,
        "fastest_mean_latency_engine": fastest.get("engine_key"),
        "rationale": " ".join(parts),
        "system_ram_after_mb": report.get("system_ram_after_mb"),
        "fastapi_process_rss_after_mb": report.get("process_rss_after_mb"),
        "docker_worker_stats_after": report.get("docker_worker_stats_after"),
    }


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    cols = [
        "evaluator",
        "engine_key",
        "ready",
        "ok_count",
        "mean_ms",
        "median_ms",
        "p95_ms",
        "init_ms",
        "process_rss_mean_mb",
        "process_rss_max_mb",
        "process_cpu_mean_pct",
        "docker_cpu_mean_pct",
        "docker_mem_usage",
    ]
    lines = [",".join(cols)]
    for r in rows:
        lines.append(",".join(_csv_cell(r.get(c)) for c in cols))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _csv_cell(v: Any) -> str:
    if v is None:
        return ""
    s = str(v)
    if "," in s or '"' in s:
        return '"' + s.replace('"', '""') + '"'
    return s


def _write_md(path: Path, report: dict[str, Any], rows: list[dict[str, Any]]) -> None:
    lines = [
        "# Phase 7D — Quality engine performance benchmark",
        "",
        f"- Started: `{report.get('started_at')}`",
        f"- Finished: `{report.get('finished_at')}`",
        f"- Measured evaluations per engine: **{MEASURED}** (warmup={WARMUP})",
        f"- Images: `{IMAGE_DIR}`",
        "",
        "## Comparison (measured)",
        "",
        "| Evaluator | Ready | OK | Mean ms | Median ms | P95 ms | Init ms | Process RSS mean MB | Process CPU mean % | Docker CPU mean % | Docker mem |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for r in rows:
        lines.append(
            "| {evaluator} | {ready} | {ok} | {mean} | {med} | {p95} | {init} | {rss} | {cpu} | {dcpu} | {dmem} |".format(
                evaluator=r.get("evaluator"),
                ready=r.get("ready"),
                ok=r.get("ok_count"),
                mean=_fmt(r.get("mean_ms")),
                med=_fmt(r.get("median_ms")),
                p95=_fmt(r.get("p95_ms")),
                init=_fmt(r.get("init_ms")),
                rss=_fmt(r.get("process_rss_mean_mb")),
                cpu=_fmt(r.get("process_cpu_mean_pct")),
                dcpu=_fmt(r.get("docker_cpu_mean_pct")),
                dmem=r.get("docker_mem_usage") or "n/a",
            )
        )
    rec = report.get("recommendation") or {}
    lines.extend(
        [
            "",
            "## Resource separation",
            "",
            f"- FastAPI/benchmark process RSS after: `{report.get('process_rss_after_mb')}` MB",
            f"- System RAM after: `{json.dumps(report.get('system_ram_after_mb'), default=str)}`",
            f"- Docker worker stats after: `{json.dumps(report.get('docker_worker_stats_after'), default=str)}`",
            "",
            "## Recommendation",
            "",
            f"- **Architecture:** {rec.get('production_architecture')}",
            f"- **Fastest mean latency:** `{rec.get('fastest_mean_latency_engine')}`",
            f"- **Rationale:** {rec.get('rationale')}",
            "",
            "## Notes",
            "",
            "- MUSIQ OPQ is overall perceptual context only; it is not an individual OpenCV criterion score.",
            "- Phase 6B research datasets were not modified.",
            "- `.env`, Flutter, authenticity, DB records, and production scoring config were not modified.",
            "- EfficientNet-B0 checkpoint was not deleted.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def _fmt(v: Any) -> str:
    if v is None:
        return "n/a"
    if isinstance(v, float):
        return f"{v:.2f}"
    return str(v)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        traceback.print_exc()
        raise
