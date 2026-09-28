"""
Step 8C.1: Controlled PROBE CPU + wall retiming on 4 REAL images (no production changes).

Usage:
  cd access_backend
  python scripts/experiment_probe_step8c1.py
"""

from __future__ import annotations

import csv
import json
import platform
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

PROBE_ROOT = ROOT / "experiments" / "probe"
VENDOR = PROBE_ROOT / "vendor_lib"
if str(VENDOR) not in sys.path:
    sys.path.insert(0, str(VENDOR))
sys.path.insert(0, str(PROBE_ROOT))

from probe_inference import load_probe_dino_checkpoint, probe_image_scores  # noqa: E402

CKPT_PATH = (
    PROBE_ROOT
    / "modelscope_cache"
    / "models"
    / "shuinishaojiu--PROBE-AIGI-Detection"
    / "snapshots"
    / "master"
    / "DINOv2_best_model_step_34999.pth"
)
HF_CACHE = PROBE_ROOT / "hf_cache"
DATASET_ROOT = Path.home() / "Desktop" / "fresh_validation"
STEP8B_CSV = ROOT / "evaluation_results" / "step8b" / "20260927_040610" / "step8b_probe_results.csv"
PATCH_BATCH_SIZE = 8

# Selected before inference (see step8c1_summary.json selection_notes)
TEST_FILENAMES = [
    "IMG_20230512_103539_795.jpg",  # A: Step 8B 63-patch wall outlier
    "IMG_20230612_173018_154.jpg",  # B: Step 8B 130-patch wall outlier
    "IMG_20260824_192434_311@-1182336623.jpg",  # C: 72-patch median peer (no other 63-patch REAL)
    "IMG_20231119_112124_234.jpg",  # D: 130-patch median runtime peer
]
ROLE = {
    "IMG_20230512_103539_795.jpg": "A_outlier_63patch",
    "IMG_20230612_173018_154.jpg": "B_outlier_130patch",
    "IMG_20260824_192434_311@-1182336623.jpg": "C_normal_72patch_median_peer",
    "IMG_20231119_112124_234.jpg": "D_normal_130patch_median_peer",
}


def load_step8b_by_filename(path: Path) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    with path.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            out[row["filename"]] = row
    return out


def find_image_path(filename: str) -> Path:
    matches = list(DATASET_ROOT.rglob(filename))
    if len(matches) != 1:
        raise SystemExit(f"Expected 1 file for {filename}, found {len(matches)}")
    return matches[0]


def power_note() -> str:
    try:
        import subprocess

        r = subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                "(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | "
                "Select-Object -First 1 -ExpandProperty BatteryStatus)",
            ],
            capture_output=True,
            text=True,
            timeout=15,
        )
        code = (r.stdout or "").strip()
        # 1 discharging, 2 AC, 3 fully charged, etc.
        mapping = {"1": "discharging", "2": "AC_power", "3": "fully_charged", "4": "low", "5": "critical", "6": "charging"}
        if code in mapping:
            return f"Win32_Battery.BatteryStatus={code} ({mapping[code]})"
        if not code:
            return "Win32_Battery unavailable (likely desktop AC)"
        return f"Win32_Battery.BatteryStatus={code}"
    except Exception as exc:
        return f"power query failed: {exc}"


def main() -> None:
    if not CKPT_PATH.is_file():
        raise SystemExit(f"Missing checkpoint: {CKPT_PATH}")

    print("STEP 8C.1 test images (before inference):")
    for fn in TEST_FILENAMES:
        print(f"  - {fn} [{ROLE[fn]}]")

    step8b = load_step8b_by_filename(STEP8B_CSV)
    for fn in TEST_FILENAMES:
        if fn not in step8b:
            raise SystemExit(f"Missing from Step 8B CSV: {fn}")

    import torch

    device = torch.device("cpu")
    env = {
        "device": "cpu",
        "python": platform.python_version(),
        "torch": torch.__version__,
        "platform": platform.platform(),
        "power_note": power_note(),
        "patch_batch_size": PATCH_BATCH_SIZE,
        "checkpoint": str(CKPT_PATH),
    }
    print("Environment:", json.dumps(env, indent=2))

    HF_CACHE.mkdir(parents=True, exist_ok=True)
    t_load0 = time.perf_counter()
    model = load_probe_dino_checkpoint(CKPT_PATH, hf_cache=HF_CACHE)
    model.to(device)
    model_load_wall = time.perf_counter() - t_load0

    rows: list[dict[str, Any]] = []
    for fn in TEST_FILENAMES:
        fp = find_image_path(fn)
        content = fp.read_bytes()
        s8 = step8b[fn]

        wall0 = time.perf_counter()
        cpu0 = time.process_time()
        mean_logit, prob, n_patches, (w, h) = probe_image_scores(
            model, content, device=device, patch_batch_size=PATCH_BATCH_SIZE
        )
        wall_s = time.perf_counter() - wall0
        cpu_s = time.process_time() - cpu0

        s8_wall = float(s8["inference_seconds"])
        s8_prob = float(s8["probe_probability"])
        s8_patches = int(s8["number_of_patches"])

        row = {
            "role": ROLE[fn],
            "filename": fn,
            "filepath": str(fp),
            "image_width": w,
            "image_height": h,
            "patch_count": n_patches,
            "wall_seconds": wall_s,
            "cpu_seconds": cpu_s,
            "wall_seconds_per_patch": wall_s / n_patches if n_patches else None,
            "cpu_seconds_per_patch": cpu_s / n_patches if n_patches else None,
            "probe_probability": prob,
            "probe_mean_logit": mean_logit,
            "step8b_wall_seconds": s8_wall,
            "step8b_patch_count": s8_patches,
            "step8b_probe_probability": s8_prob,
            "wall_seconds_delta_vs_step8b": wall_s - s8_wall,
            "probe_probability_delta_vs_step8b": prob - s8_prob if prob is not None else None,
            "patch_count_matches_step8b": n_patches == s8_patches,
        }
        rows.append(row)
        print(
            f"{fn}: patches={n_patches} wall={wall_s:.1f}s cpu={cpu_s:.1f}s "
            f"probe={prob} (8B wall={s8_wall:.1f}s probe={s8_prob})",
            flush=True,
        )

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = ROOT / "evaluation_results" / "step8c1" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)

    fieldnames = list(rows[0].keys())
    with (out_dir / "step8c1_retiming.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for row in rows:
            w.writerow(row)

    prob_ok = all(abs(r["probe_probability_delta_vs_step8b"] or 0) < 1e-5 for r in rows)
    wall_ratios = []
    for r in rows:
        if r["step8b_wall_seconds"] > 1000:
            wall_ratios.append(
                {
                    "filename": r["filename"],
                    "step8b_wall": r["step8b_wall_seconds"],
                    "controlled_wall": r["wall_seconds"],
                    "step8b_to_controlled_ratio": r["step8b_wall_seconds"] / r["wall_seconds"]
                    if r["wall_seconds"]
                    else None,
                }
            )

    summary = {
        "step8c1_status": "COMPLETE",
        "production_behavior_changed": False,
        "test_images": [{"filename": fn, "role": ROLE[fn]} for fn in TEST_FILENAMES],
        "selection_notes": {
            "C_substitution": (
                "Step 8B has exactly one REAL image with 63 patches (image A). "
                "No separate normal 63-patch peer exists. Control C is the REAL image "
                "with 72 patches whose Step 8B wall time was closest to the median of "
                "the 51-75 patch REAL group (excluding A)."
            ),
        },
        "environment": {**env, "model_load_wall_seconds": model_load_wall},
        "results": rows,
        "probability_reproducible_within_1e-5": prob_ok,
        "outlier_wall_reproduction": wall_ratios,
        "interpretation_hint": (
            "If Step 8B multi-hour wall times shrink to minutes in this run while "
            "CPU time tracks wall time and peers scale with patch count, classify "
            "Step 8B extremes as environmental idle-time artifacts, not normal PROBE compute."
        ),
        "step8b_csv": str(STEP8B_CSV),
        "output_dir": str(out_dir),
    }
    (out_dir / "step8c1_summary.json").write_text(json.dumps(summary, indent=2, default=str), encoding="utf-8")

    report = [
        "STEP 8C.1 STATUS: COMPLETE",
        f"Output: {out_dir}",
        "PRODUCTION BEHAVIOR CHANGED: NO",
        "",
        "Test images:",
        *[f"  {fn} ({ROLE[fn]})" for fn in TEST_FILENAMES],
    ]
    (out_dir / "step8c1_report.txt").write_text("\n".join(report), encoding="utf-8")
    print(f"\nWrote {out_dir}")


if __name__ == "__main__":
    main()
