#!/usr/bin/env python3
"""Phase 7E: profile OpenCV / MUSIQ latency bottlenecks (read-only investigation).

Does NOT change scoring formulas, thresholds, .env, Flutter, authenticity, or DB.
Does NOT delete EfficientNet-B0.

Usage (Windows CMD):
  cd /d C:\\Users\\Dell\\Desktop\\access_mobile\\access_backend
  python scripts\\profile_opencv_quality_phase7e.py
"""

from __future__ import annotations

import json
import os
import statistics
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

OUT_DIR = ROOT / "phase7e_performance_investigation"
IMAGE_DIR = Path(r"C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos")
# Same first-N set as Phase 7D for comparability.
N_IMAGES = int(os.environ.get("PHASE7E_IMAGES", "5"))
WARMUP = 1

os.environ.setdefault("MUSIQ_WORKER_URL", "http://127.0.0.1:8080")
os.environ.setdefault("MUSIQ_WORKER_TOKEN", "dev-local-musiq-token")
os.environ.setdefault("MUSIQ_WORKER_TIMEOUT_SEC", "120")
os.environ.setdefault("MUSIQ_WORKER_TLS_VERIFY", "false")


def _ms(fn: Callable[[], Any]) -> tuple[Any, float]:
    t0 = time.perf_counter()
    out = fn()
    return out, (time.perf_counter() - t0) * 1000.0


def _mean(vals: list[float]) -> float | None:
    return float(statistics.fmean(vals)) if vals else None


def _rss_mb() -> float | None:
    try:
        import psutil

        return float(psutil.Process(os.getpid()).memory_info().rss) / (1024.0 * 1024.0)
    except Exception:
        return None


def _select_images() -> list[Path]:
    files = sorted(
        [p for p in IMAGE_DIR.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png"}],
        key=lambda p: p.name.lower(),
    )
    return files[:N_IMAGES]


def profile_local_opencv(content: bytes) -> dict[str, Any]:
    """Step-time production app.services.opencv_quality on native resolution."""
    import cv2
    import numpy as np
    from app.services import opencv_quality as oq

    timings: dict[str, float] = {}
    bgr, timings["decode_oriented_bgr_ms"] = _ms(lambda: oq.decode_image(content))
    if bgr is None:
        return {"ok": False, "error": "decode_failed", "timings_ms": timings}

    h, w = bgr.shape[:2]
    meta = {"width": int(w), "height": int(h), "megapixels": round(w * h / 1e6, 3)}

    def gray_step():
        return cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)

    gray, timings["cvt_gray_ms"] = _ms(gray_step)

    def lap():
        return float(cv2.Laplacian(gray, cv2.CV_64F).var())

    lap_var, timings["sharpness_laplacian_var_ms"] = _ms(lap)
    timings["blur_from_sharpness_ms"] = 0.0  # pure arithmetic

    def noise_step():
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        residual = cv2.absdiff(gray, blurred)
        return float(np.std(residual))

    _, timings["noise_gaussian_residual_ms"] = _ms(noise_step)

    def bright_contrast():
        _ = float(np.mean(gray) / 255.0)
        _ = float(np.std(gray))

    _, timings["brightness_contrast_ms"] = _ms(bright_contrast)

    _, timings["blocking_artifacts_ms"] = _ms(lambda: oq._blocking_artifacts(gray))  # noqa: SLF001
    _, timings["ringing_artifacts_ms"] = _ms(lambda: oq._ringing_artifacts(gray))  # noqa: SLF001

    _, timings["full_analyze_bgr_ms"] = _ms(lambda: oq.analyze_bgr(bgr))
    _, timings["full_analyze_image_bytes_ms"] = _ms(lambda: oq.analyze_image_bytes(content))

    # Diagnostic only: same formulas after longest-side 1024 resize (NOT a scoring change).
    cap = 1024
    longest = max(h, w)
    if longest > cap:
        scale = cap / float(longest)
        nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
        resized, timings["diagnostic_resize_1024_ms"] = _ms(
            lambda: cv2.resize(bgr, (nw, nh), interpolation=cv2.INTER_AREA)
        )
        gray_r = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
        _, timings["diagnostic_blocking_after_resize_1024_ms"] = _ms(
            lambda: oq._blocking_artifacts(gray_r)  # noqa: SLF001
        )
        _, timings["diagnostic_ringing_after_resize_1024_ms"] = _ms(
            lambda: oq._ringing_artifacts(gray_r)  # noqa: SLF001
        )
        _, timings["diagnostic_full_analyze_bgr_resized_1024_ms"] = _ms(
            lambda: oq.analyze_bgr(resized)
        )
        meta["diagnostic_resized_to"] = [nw, nh]
    else:
        timings["diagnostic_resize_1024_ms"] = 0.0
        meta["diagnostic_resized_to"] = [w, h]

    return {"ok": True, "meta": meta, "timings_ms": timings, "lap_var": lap_var}


def profile_worker_classical_local(content: bytes) -> dict[str, Any]:
    """Time the worker/shadow classical path locally (includes RESIZE_CAP=1024)."""
    from app.services.quality_shadow.classical import (
        RESIZE_CAP,
        analyze_bgr_raw,
        classical_quality_from_bgr,
        decode_bgr_from_bytes,
        _blocking_boundary_ratio,
        _flat_block_frac,
        _immerkaer,
        _residual_std,
        _ringing_edge_lap,
        _resize_cap_bgr,
    )
    import cv2
    import numpy as np

    timings: dict[str, float] = {}
    bgr, timings["decode_cv_imdecode_ms"] = _ms(lambda: decode_bgr_from_bytes(content))
    if bgr is None:
        return {"ok": False, "error": "decode_failed", "timings_ms": timings}
    h, w = bgr.shape[:2]
    resized, timings["resize_cap_ms"] = _ms(lambda: _resize_cap_bgr(bgr, RESIZE_CAP))
    rh, rw = resized.shape[:2]

    def to_gray():
        return cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY).astype(np.float64)

    gray, timings["gray_float64_ms"] = _ms(to_gray)

    _, timings["laplacian_sobel_tenengrad_bundle_ms"] = _ms(lambda: analyze_bgr_raw(resized))
    # Break out expensive classical pieces on resized gray
    g8 = np.clip(gray, 0, 255).astype(np.uint8)
    _, timings["immerkaer_ms"] = _ms(lambda: _immerkaer(gray))
    _, timings["residual_std_ms"] = _ms(lambda: _residual_std(gray))
    _, timings["blocking_boundary_ratio_ms"] = _ms(lambda: _blocking_boundary_ratio(gray))
    _, timings["flat_block_frac_ms"] = _ms(lambda: _flat_block_frac(gray))
    _, timings["ringing_edge_lap_ms"] = _ms(lambda: _ringing_edge_lap(g8))
    _, timings["classical_quality_from_bgr_ms"] = _ms(lambda: classical_quality_from_bgr(bgr))

    return {
        "ok": True,
        "meta": {
            "native_wh": [w, h],
            "resized_wh": [rw, rh],
            "resize_cap": RESIZE_CAP,
        },
        "timings_ms": timings,
    }


def profile_enet(content: bytes) -> dict[str, Any]:
    from app.services import efficientnet_b0_scorer as enet
    from app.services.image_orientation import oriented_pil_image

    timings: dict[str, float] = {}
    if not enet.efficientnet_available():
        return {"ok": False, "error": "enet_unavailable"}
    enet.ensure_weights()

    pil, timings["oriented_pil_ms"] = _ms(lambda: oriented_pil_image(content))
    if pil is None:
        return {"ok": False, "error": "pil_failed", "timings_ms": timings}
    w, h = pil.size

    def preprocess():
        return enet._preprocess(pil)  # noqa: SLF001

    tensor, timings["preprocess_resize_224_ms"] = _ms(preprocess)

    def infer():
        torch = __import__("app.services.torch_runtime", fromlist=["get_torch"]).get_torch()
        model = enet._get_model()  # noqa: SLF001
        assert torch is not None and model is not None
        with torch.no_grad():
            return model(tensor).squeeze(0).cpu().numpy()

    _, timings["forward_ms"] = _ms(infer)
    _, timings["full_analyze_image_bytes_ms"] = _ms(lambda: enet.analyze_image_bytes(content))
    return {
        "ok": True,
        "meta": {"pil_wh": [w, h], "network_input": [224, 224]},
        "timings_ms": timings,
    }


def profile_musiq_http(content: bytes, filename: str) -> dict[str, Any]:
    """Client wall clock vs worker-reported duration_ms; classical estimated locally."""
    from app.services.musiq_worker_client import evaluate_bytes

    t0 = time.perf_counter()
    body = evaluate_bytes(content, media_type="photo", filename=filename)
    client_wall_ms = (time.perf_counter() - t0) * 1000.0

    server_ms = body.get("duration_ms")
    try:
        server_ms_f = float(server_ms) if server_ms is not None else None
    except (TypeError, ValueError):
        server_ms_f = None

    classical_local = profile_worker_classical_local(content)
    classical_ms = None
    if classical_local.get("ok"):
        classical_ms = classical_local["timings_ms"].get("classical_quality_from_bgr_ms")

    http_overhead_ms = None
    musiq_est_ms = None
    if server_ms_f is not None:
        http_overhead_ms = max(0.0, client_wall_ms - server_ms_f)
        if classical_ms is not None:
            # Remainder of server time after local-equivalent classical (approx).
            musiq_est_ms = max(0.0, server_ms_f - float(classical_ms))

    musiq = body.get("musiq") if isinstance(body.get("musiq"), dict) else {}
    return {
        "ok": body.get("status") in ("ok", "partial"),
        "client_wall_ms": client_wall_ms,
        "worker_duration_ms": server_ms_f,
        "http_and_transfer_est_ms": http_overhead_ms,
        "classical_local_proxy_ms": classical_ms,
        "musiq_plus_misc_server_est_ms": musiq_est_ms,
        "musiq_opq_raw": musiq.get("musiq_opq_raw"),
        "musiq_opq_note": "OPQ context only; not an OpenCV criterion",
        "worker_status": body.get("status"),
        "payload_bytes": len(content),
        "classical_local_detail": classical_local,
    }


def main() -> int:
    from dotenv import load_dotenv

    load_dotenv(ROOT / ".env", override=False)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    from app.config import settings

    settings.musiq_worker_url = os.environ["MUSIQ_WORKER_URL"]
    settings.musiq_worker_token = os.environ["MUSIQ_WORKER_TOKEN"]
    settings.musiq_worker_timeout_sec = float(os.environ.get("MUSIQ_WORKER_TIMEOUT_SEC", "120"))
    settings.musiq_worker_tls_verify = False
    settings.quality_engine = "enet"
    settings.quality_shadow_enabled = False

    images = _select_images()
    report: dict[str, Any] = {
        "phase": "7E",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "n_images": len(images),
        "images": [{"name": p.name, "bytes": p.stat().st_size} for p in images],
        "process_rss_mb_start": _rss_mb(),
        "phase7d_baseline_means_ms": {
            "efficientnet_b0": 209.85,
            "musiq_worker_opencv": 4776.27,
            "opencv_local": 4888.84,
        },
        "per_image": [],
        "aggregates": {},
        "findings": [],
        "safe_optimization_candidates": [],
    }

    # Warmup first image lightly
    if images:
        from app.services import opencv_quality as oq

        _ = oq.analyze_image_bytes(images[0].read_bytes())

    agg_local: dict[str, list[float]] = {}
    agg_musiq_client: list[float] = []
    agg_musiq_server: list[float] = []
    agg_http: list[float] = []
    agg_classical_proxy: list[float] = []
    agg_musiq_est: list[float] = []
    agg_enet_full: list[float] = []
    agg_mp: list[float] = []

    for path in images:
        content = path.read_bytes()
        row: dict[str, Any] = {"image": path.name, "bytes": len(content)}
        print(f"Profiling {path.name} ({len(content)} bytes)...", flush=True)

        local = profile_local_opencv(content)
        row["local_opencv"] = local
        if local.get("ok"):
            agg_mp.append(float(local["meta"]["megapixels"]))
            for k, v in local["timings_ms"].items():
                agg_local.setdefault(k, []).append(float(v))

        classical = profile_worker_classical_local(content)
        row["worker_classical_local"] = classical

        enet = profile_enet(content)
        row["efficientnet_b0"] = enet
        if enet.get("ok"):
            agg_enet_full.append(float(enet["timings_ms"]["full_analyze_image_bytes_ms"]))

        musiq = profile_musiq_http(content, path.name)
        row["musiq_http"] = musiq
        if musiq.get("client_wall_ms") is not None:
            agg_musiq_client.append(float(musiq["client_wall_ms"]))
        if musiq.get("worker_duration_ms") is not None:
            agg_musiq_server.append(float(musiq["worker_duration_ms"]))
        if musiq.get("http_and_transfer_est_ms") is not None:
            agg_http.append(float(musiq["http_and_transfer_est_ms"]))
        if musiq.get("classical_local_proxy_ms") is not None:
            agg_classical_proxy.append(float(musiq["classical_local_proxy_ms"]))
        if musiq.get("musiq_plus_misc_server_est_ms") is not None:
            agg_musiq_est.append(float(musiq["musiq_plus_misc_server_est_ms"]))

        report["per_image"].append(row)

    report["aggregates"] = {
        "mean_megapixels": _mean(agg_mp),
        "local_opencv_mean_ms": {k: _mean(v) for k, v in agg_local.items()},
        "enet_full_mean_ms": _mean(agg_enet_full),
        "musiq_client_wall_mean_ms": _mean(agg_musiq_client),
        "musiq_worker_duration_mean_ms": _mean(agg_musiq_server),
        "http_transfer_est_mean_ms": _mean(agg_http),
        "classical_resized_proxy_mean_ms": _mean(agg_classical_proxy),
        "musiq_inference_plus_misc_est_mean_ms": _mean(agg_musiq_est),
        "process_rss_mb_end": _rss_mb(),
    }

    loc = report["aggregates"]["local_opencv_mean_ms"]
    findings = []
    if loc:
        ranked = sorted(
            [(k, v) for k, v in loc.items() if v is not None and not k.startswith("diagnostic")],
            key=lambda kv: kv[1],
            reverse=True,
        )
        findings.append(
            {
                "id": "local_opencv_step_ranking",
                "detail": "Mean step times for production opencv_quality on native resolution.",
                "ranked_mean_ms": ranked,
            }
        )
        block = loc.get("blocking_artifacts_ms")
        ring = loc.get("ringing_artifacts_ms")
        full = loc.get("full_analyze_image_bytes_ms")
        if block and full and block / full > 0.4:
            findings.append(
                {
                    "id": "blocking_python_loop_dominates_local_opencv",
                    "detail": (
                        "Production _blocking_artifacts uses nested Python loops over every 8x8 "
                        "block at native resolution (no resize cap). This likely dominates local OpenCV latency."
                    ),
                    "blocking_mean_ms": block,
                    "full_mean_ms": full,
                    "share": block / full,
                }
            )
        if ring and full and ring / full > 0.2:
            findings.append(
                {
                    "id": "ringing_python_loop_expensive",
                    "detail": (
                        "Production _ringing_artifacts uses Python per-row/per-pixel sign-change loops "
                        "on native resolution."
                    ),
                    "ringing_mean_ms": ring,
                    "full_mean_ms": full,
                    "share": ring / full,
                }
            )
        diag_full = loc.get("diagnostic_full_analyze_bgr_resized_1024_ms")
        if diag_full is not None and full is not None:
            findings.append(
                {
                    "id": "native_vs_resize1024_diagnostic",
                    "detail": (
                        "Diagnostic only: same opencv_quality.analyze_bgr after longest-side 1024 resize. "
                        "Not a production scoring change; scores would need parity validation before adoption."
                    ),
                    "native_full_analyze_bgr_mean_ms": loc.get("full_analyze_bgr_ms"),
                    "resized_1024_full_analyze_bgr_mean_ms": diag_full,
                    "speedup_factor": (loc.get("full_analyze_bgr_ms") or 0) / diag_full if diag_full else None,
                }
            )

    findings.append(
        {
            "id": "enet_fixed_224_input",
            "detail": (
                "EfficientNet always resizes to 224x224 before the network. Wall time is largely "
                "decode/preprocess + small CNN forward — insensitive to multi-megapixel pixel loops."
            ),
            "enet_full_mean_ms": report["aggregates"]["enet_full_mean_ms"],
        }
    )
    findings.append(
        {
            "id": "musiq_path_split",
            "detail": (
                "MUSIQ path client wall ≈ HTTP/transfer + worker duration. Worker classical uses "
                "RESIZE_CAP=1024; MUSIQ PaQ-2-PiQ scores original JPEG bytes (no client-side resize). "
                "musiq_plus_misc_server_est ≈ worker_duration - local classical_quality_from_bgr proxy."
            ),
            "client_wall_mean_ms": report["aggregates"]["musiq_client_wall_mean_ms"],
            "worker_duration_mean_ms": report["aggregates"]["musiq_worker_duration_mean_ms"],
            "http_transfer_est_mean_ms": report["aggregates"]["http_transfer_est_mean_ms"],
            "classical_resized_proxy_mean_ms": report["aggregates"]["classical_resized_proxy_mean_ms"],
            "musiq_inference_plus_misc_est_mean_ms": report["aggregates"][
                "musiq_inference_plus_misc_est_mean_ms"
            ],
        }
    )
    findings.append(
        {
            "id": "why_local_opencv_rivals_musiq_total",
            "detail": (
                "Phase 7D showed local OpenCV (~4889 ms) similar to MUSIQ+OpenCV (~4776 ms). "
                "That is consistent with native-resolution Python blocking/ringing dominating local "
                "fallback, while the Docker path pays for large JPEG upload + TensorFlow MUSIQ but "
                "runs classical after a 1024 resize (cheaper classical)."
            ),
        }
    )
    report["findings"] = findings

    report["safe_optimization_candidates"] = [
        {
            "id": "vectorize_or_cap_local_opencv_blocking_ringing",
            "risk": "medium",
            "preserves_formulas_if": (
                "NumPy/OpenCV vectorization of the same flat-block and ringing definitions, "
                "or applying an explicit documented resize cap with validated score parity vs baseline."
            ),
            "do_not": "Change variance threshold 8.0, block size 8, Canny 80/160, or soft_score bins just for speed.",
        },
        {
            "id": "align_local_opencv_with_worker_resize_cap_1024",
            "risk": "high_without_parity_tests",
            "preserves_formulas_if": (
                "Only after comparing native vs capped metrics/_soft_score outputs on a frozen image set; "
                "document any intentional resolution policy."
            ),
            "note": "Worker classical already caps at 1024; local opencv_quality does not.",
        },
        {
            "id": "musiq_input_downscale_before_tf",
            "risk": "high_for_opq_values",
            "preserves_formulas_if": "Never for criterion scores; OPQ is context-only but values would change — requires acceptance tests.",
            "note": "Would not change OpenCV criteria if classical stays on its own resize path.",
        },
        {
            "id": "avoid_double_decode_in_pipelines",
            "risk": "low",
            "preserves_formulas_if": "Reuse decoded BGR across color heuristics + quality when already in memory.",
            "note": "Does not change numeric formulas.",
        },
        {
            "id": "keep_enet_as_fast_local_fallback",
            "risk": "none",
            "preserves_formulas_if": "No change; architecture choice only.",
            "note": "Phase 7D/7C show ENET is ~20x faster than native local OpenCV on these photos.",
        },
    ]

    report["finished_at"] = datetime.now(timezone.utc).isoformat()
    report["scoring_behavior_changed"] = False

    raw_path = OUT_DIR / "profile_raw.json"
    md_path = OUT_DIR / "BOTTLENECK_REPORT.md"
    raw_path.write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")
    _write_md(md_path, report)
    print(json.dumps({"aggregates": report["aggregates"], "findings": findings}, indent=2, default=str))
    print("wrote", raw_path)
    print("wrote", md_path)
    return 0


def _write_md(path: Path, report: dict[str, Any]) -> None:
    loc = report["aggregates"].get("local_opencv_mean_ms") or {}
    lines = [
        "# Phase 7E — Image quality performance investigation",
        "",
        f"- Started: `{report.get('started_at')}`",
        f"- Finished: `{report.get('finished_at')}`",
        f"- Images profiled: **{report.get('n_images')}** from `{IMAGE_DIR}`",
        f"- Mean megapixels: **{report['aggregates'].get('mean_megapixels')}**",
        f"- Scoring behavior changed: **{report.get('scoring_behavior_changed')}**",
        "",
        "## Phase 7D baseline (for context)",
        "",
        "| Engine | Mean ms |",
        "|---|---:|",
        "| EfficientNet-B0 | 209.85 |",
        "| MUSIQ + OpenCV | 4776.27 |",
        "| Local OpenCV | 4888.84 |",
        "",
        "## Local OpenCV step means (production `opencv_quality`)",
        "",
        "| Step | Mean ms |",
        "|---|---:|",
    ]
    for k, v in sorted(loc.items(), key=lambda kv: (kv[1] is None, -(kv[1] or 0))):
        if v is None:
            continue
        lines.append(f"| `{k}` | {v:.2f} |")

    agg = report["aggregates"]
    lines.extend(
        [
            "",
            "## MUSIQ path split (measured / estimated)",
            "",
            f"- Client wall mean: **{agg.get('musiq_client_wall_mean_ms')}** ms",
            f"- Worker `duration_ms` mean: **{agg.get('musiq_worker_duration_mean_ms')}** ms",
            f"- HTTP/transfer estimate (client − worker): **{agg.get('http_transfer_est_mean_ms')}** ms",
            f"- Classical resized proxy (local `classical_quality_from_bgr`): **{agg.get('classical_resized_proxy_mean_ms')}** ms",
            f"- MUSIQ+misc server estimate (worker − classical proxy): **{agg.get('musiq_inference_plus_misc_est_mean_ms')}** ms",
            f"- ENET full mean (this run): **{agg.get('enet_full_mean_ms')}** ms",
            "",
            "## Findings",
            "",
        ]
    )
    for f in report.get("findings") or []:
        lines.append(f"### `{f.get('id')}`")
        lines.append("")
        lines.append(str(f.get("detail") or ""))
        lines.append("")
        for k, v in f.items():
            if k in ("id", "detail"):
                continue
            lines.append(f"- **{k}:** `{v}`")
        lines.append("")

    lines.extend(["## Safe optimization candidates (not implemented)", ""])
    for c in report.get("safe_optimization_candidates") or []:
        lines.append(f"### `{c.get('id')}`")
        lines.append("")
        lines.append(f"- Risk: **{c.get('risk')}**")
        lines.append(f"- Preserves formulas if: {c.get('preserves_formulas_if')}")
        if c.get("do_not"):
            lines.append(f"- Do not: {c.get('do_not')}")
        if c.get("note"):
            lines.append(f"- Note: {c.get('note')}")
        lines.append("")

    lines.extend(
        [
            "## Constraints honored",
            "",
            "- No scoring formula/threshold changes",
            "- No `.env` / Flutter / deploy / ENET deletion",
            "- PROBE/WaveRep, research datasets, DB records untouched",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        traceback.print_exc()
        raise
