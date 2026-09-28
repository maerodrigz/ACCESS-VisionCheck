"""
Benchmark EfficientNet-B0 IQA accuracy (technical quality head only).

Usage:
  cd access_backend
  python scripts/benchmark_efficientnet_b0.py
  python scripts/benchmark_efficientnet_b0.py --samples 512 --seed 42
  python scripts/benchmark_efficientnet_b0.py --csv path/to/labels.csv

CSV format (header required). Paths are relative to the CSV file directory:
  path,sharpness,blur,noise,brightness,contrast,blocking_artifacts,ringing_artifacts
Each label column is optional 0-1. Include only columns you have human scores for.

Synthetic scores measure fit to the training-style generator. For real ACCESS photos,
build a labeled CSV from admin/expert ratings and pass --csv.
"""

from __future__ import annotations

import argparse
import csv
import random
import sys
from pathlib import Path

import cv2

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.services.efficientnet_b0_scorer import (  # noqa: E402
    CRITERION_KEYS,
    analyze_image_bytes,
    efficientnet_available,
    ensure_weights,
    weights_path,
)
from app.services.efficientnet_benchmark import summarize_predictions  # noqa: E402
from app.services.efficientnet_synthetic_iqa import (  # noqa: E402
    encode_jpeg_bgr,
    synthesize_iqa_sample,
)


def _check_ready() -> None:
    if not efficientnet_available():
        raise SystemExit("PyTorch/torchvision not installed. pip install torch torchvision")
    if not ensure_weights():
        raise SystemExit(
            f"Weights missing at {weights_path()}. Run: python scripts/train_efficientnet_heads.py"
        )


def _predict_jpeg(content: bytes) -> dict[str, float]:
    metrics = analyze_image_bytes(content)
    if metrics is None:
        raise RuntimeError("EfficientNet inference returned None")
    return {key: float(metrics[key]) for key in CRITERION_KEYS}


def run_synthetic(*, samples: int, seed: int) -> list[dict]:
    rng = random.Random(seed)
    rows: list[dict] = []
    for i in range(samples):
        image, labels = synthesize_iqa_sample(rng=rng)
        jpeg = encode_jpeg_bgr(image)
        pred = _predict_jpeg(jpeg)
        rows.append({"id": i, "labels": labels, "pred": pred})
    return rows


def run_pairwise_sharpness(*, pairs: int, seed: int) -> tuple[int, int]:
    """Same scene, sharp vs blurred: model should rank sharpness higher."""
    rng = random.Random(seed + 999)
    correct = 0
    for _ in range(pairs):
        sharp_img, sharp_labels = synthesize_iqa_sample(rng=rng)
        blur_img = sharp_img.copy()
        blur_img = cv2.GaussianBlur(blur_img, (15, 15), 4.0)
        sharp_pred = _predict_jpeg(encode_jpeg_bgr(sharp_img))["sharpness"]
        blur_pred = _predict_jpeg(encode_jpeg_bgr(blur_img))["sharpness"]
        if sharp_pred > blur_pred:
            correct += 1
    return correct, pairs


def _parse_float(raw: str | None) -> float | None:
    if raw is None or str(raw).strip() == "":
        return None
    return float(raw)


def run_csv(csv_path: Path) -> list[dict]:
    base = csv_path.parent
    rows: list[dict] = []
    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames or "path" not in reader.fieldnames:
            raise SystemExit("CSV must include a path column")
        for i, row in enumerate(reader):
            rel = (row.get("path") or "").strip()
            if not rel:
                continue
            img_path = (base / rel).resolve()
            if not img_path.is_file():
                print(f"skip missing: {img_path}")
                continue
            content = img_path.read_bytes()
            pred = _predict_jpeg(content)
            labels: dict[str, float] = {}
            for key in CRITERION_KEYS:
                val = _parse_float(row.get(key))
                if val is not None:
                    labels[key] = max(0.0, min(1.0, val))
            if not labels:
                print(f"skip no labels: {img_path}")
                continue
            rows.append({"id": i, "labels": labels, "pred": pred, "path": str(img_path)})
    return rows


def _print_report(title: str, rows: list[dict]) -> None:
    if not rows:
        print(f"\n{title}: no rows evaluated")
        return

    from app.services.efficientnet_benchmark import criterion_metrics

    for key in CRITERION_KEYS:
        subset = [r for r in rows if key in r["labels"]]
        if len(subset) < 2:
            continue
        true = [float(r["labels"][key]) for r in subset]
        pred = [float(r["pred"][key]) for r in subset]
        m = criterion_metrics(key, true, pred)
        print(
            f"  {m.key:20}  MAE={m.mae:.4f}  RMSE={m.rmse:.4f}  "
            f"r={m.pearson:+.3f}  rho={m.spearman:+.3f}  n={m.n}"
        )

    full_label_rows = [r for r in rows if all(key in r["labels"] for key in CRITERION_KEYS)]
    if full_label_rows:
        metrics, mean_mae = summarize_predictions(full_label_rows)
        print(f"  {'mean MAE (all 7)':20}  {mean_mae:.4f}  (n={len(full_label_rows)})")
    elif rows:
        print(f"  ({len(rows)} samples with partial labels)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Benchmark EfficientNet-B0 IQA accuracy")
    parser.add_argument("--samples", type=int, default=256, help="Synthetic hold-out samples")
    parser.add_argument("--seed", type=int, default=42, help="RNG seed for synthetic set")
    parser.add_argument("--pairs", type=int, default=64, help="Sharp vs blur pairwise tests")
    parser.add_argument("--csv", type=Path, default=None, help="CSV with human/expert labels")
    args = parser.parse_args()

    _check_ready()
    print(f"Weights: {weights_path()}")
    print(f"Criteria: {', '.join(CRITERION_KEYS)}")

    synth_rows = run_synthetic(samples=args.samples, seed=args.seed)
    print(f"\n=== Synthetic hold-out (n={len(synth_rows)}, seed={args.seed}) ===")
    _print_report("Synthetic", synth_rows)

    correct, total = run_pairwise_sharpness(pairs=args.pairs, seed=args.seed)
    pct = 100.0 * correct / total if total else 0.0
    print(f"\n=== Pairwise sharpness ranking ===")
    print(f"  sharp beat blurred: {correct}/{total} ({pct:.1f}%)")

    if args.csv:
        csv_rows = run_csv(args.csv.resolve())
        print(f"\n=== Labeled dataset: {args.csv} ===")
        _print_report("CSV", csv_rows)

    print(
        "\nNote: High synthetic scores only show the head fits the generator used in "
        "train_efficientnet_heads.py. For production accuracy on member uploads, label "
        "real photos/videos and re-run with --csv."
    )


if __name__ == "__main__":
    main()
