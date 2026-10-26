"""Read-only WaveRep G4 evaluation audit (stdout JSON). Not for production."""
from __future__ import annotations

import json
import math
import statistics
from collections import Counter, defaultdict
from typing import Any

from app.database import SessionLocal
from app.models.ai_detection_result import AiDetectionResult
from app.models.media_file import MediaFile
from app.services.ai_authenticity_detector import probe_risk_level_from_probability


def _parse_exif(raw: str | None) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        return {}


def _is_video_row(exif: dict[str, Any], file_name: str, file_type: str | None) -> bool:
    if exif.get("is_video") is True:
        return True
    ft = (file_type or "").lower()
    if "video" in ft:
        return True
    fn = (file_name or "").lower()
    return fn.endswith((".mp4", ".mov", ".webm", ".mkv", ".m4v", ".3gp"))


def _risk_band(p: float) -> str:
    return probe_risk_level_from_probability(p)


def _classify_at_threshold(p: float, t_high: float, t_low: float = 0.30) -> str:
    if p < t_low:
        return "low"
    if p < t_high:
        return "suspicious"
    return "high"


def main() -> None:
    db = SessionLocal()
    try:
        rows = (
            db.query(AiDetectionResult, MediaFile)
            .join(MediaFile, MediaFile.id == AiDetectionResult.media_id)
            .all()
        )

        waverep_videos: list[dict[str, Any]] = []
        all_videos: list[dict[str, Any]] = []
        checkpoints: Counter[str] = Counter()
        models: Counter[str] = Counter()

        for ai, media in rows:
            exif = _parse_exif(ai.exif_metadata)
            if not _is_video_row(exif, media.file_name or "", getattr(media, "file_type", None)):
                continue
            backend = str(exif.get("detector_backend") or "").strip().lower()
            p = float(ai.ai_probability)
            band = _risk_band(p)
            entry = {
                "ai_id": ai.id,
                "media_id": media.id,
                "file_name": media.file_name,
                "detector_backend": backend or None,
                "ai_probability": p,
                "risk_band_probe_policy": band,
                "detection_result": ai.detection_result,
                "review_status": ai.review_status,
                "visual_ai_probability": exif.get("visual_ai_probability"),
                "waverep_model": exif.get("waverep_model")
                or (exif.get("waverep_supplementary") or {}).get("waverep_model")
                if isinstance(exif.get("waverep_supplementary"), dict)
                else exif.get("waverep_model"),
                "waverep_threshold": exif.get("waverep_threshold"),
                "waverep_frames": exif.get("waverep_frames_analyzed"),
            }
            all_videos.append(entry)
            if backend == "waverep_g4" or backend.startswith("waverep"):
                waverep_videos.append(entry)
                sup = exif.get("waverep_supplementary")
                if isinstance(sup, dict):
                    ck = str(sup.get("waverep_model") or "unknown")
                    models[ck] += 1
                wm = str(exif.get("waverep_model") or "WaveRep G4")
                models[wm] += 1

        def summarize(items: list[dict[str, Any]]) -> dict[str, Any]:
            if not items:
                return {"count": 0}
            probs = [x["ai_probability"] for x in items]
            bands = Counter(x["risk_band_probe_policy"] for x in items)
            det = Counter(x["detection_result"] for x in items)
            review = Counter(x["review_status"] for x in items)
            verified_human = [
                x
                for x in items
                if x["review_status"] in ("verified_human", "automated_low_ai_risk")
                or x["detection_result"] == "authentic"
            ]
            admin_verified_human = [x for x in items if x["review_status"] == "verified_human"]
            admin_confirmed_ai = [
                x
                for x in items
                if x["review_status"] in ("confirmed_ai_generated",)
                or x["detection_result"] == "ai_generated"
                and x["review_status"] not in ("pending_review", "needs_further_review")
            ]
            admin_confirmed_ai_strict = [
                x for x in items if x["review_status"] == "confirmed_ai_generated"
            ]
            sorted_p = sorted(probs)
            n = len(sorted_p)

            def pctile(q: float) -> float:
                if n == 1:
                    return sorted_p[0]
                idx = min(n - 1, max(0, int(q * (n - 1))))
                return sorted_p[idx]

            hist = Counter(int(p * 10) / 10 for p in probs)
            return {
                "count": n,
                "probability_min": min(probs),
                "probability_max": max(probs),
                "probability_mean": round(statistics.mean(probs), 4),
                "probability_median": round(statistics.median(probs), 4),
                "percentiles": {
                    "p25": round(pctile(0.25), 4),
                    "p50": round(pctile(0.5), 4),
                    "p75": round(pctile(0.75), 4),
                    "p90": round(pctile(0.9), 4),
                },
                "histogram_decile_bucket": dict(sorted(hist.items())),
                "risk_band_low_suspicious_high": dict(bands),
                "detection_result_counts": dict(det),
                "review_status_counts": dict(review),
                "admin_verified_human_count": len(admin_verified_human),
                "admin_confirmed_ai_count": len(admin_confirmed_ai_strict),
                "note_admin_ground_truth": (
                    "Only review_status verified_human / confirmed_ai_generated treated as admin labels."
                ),
            }

        # Ground truth subset for threshold sweep
        labeled: list[tuple[float, str]] = []
        for x in waverep_videos:
            if x["review_status"] == "verified_human":
                labeled.append((x["ai_probability"], "genuine"))
            elif x["review_status"] == "confirmed_ai_generated":
                labeled.append((x["ai_probability"], "ai"))

        thresholds = [0.45, 0.50, 0.60, 0.70]
        sweep: dict[str, Any] = {}
        for t in thresholds:
            tp = fp = tn = fn = 0
            for p, label in labeled:
                pred_ai = p >= t
                is_ai = label == "ai"
                if pred_ai and is_ai:
                    tp += 1
                elif pred_ai and not is_ai:
                    fp += 1
                elif not pred_ai and not is_ai:
                    tn += 1
                else:
                    fn += 1
            n = tp + fp + tn + fn
            prec = tp / (tp + fp) if (tp + fp) else None
            rec = tp / (tp + fn) if (tp + fn) else None
            fpr = fp / (fp + tn) if (fp + tn) else None
            fnr = fn / (fn + tp) if (fn + tp) else None
            sweep[str(t)] = {
                "confusion": {"tp": tp, "fp": fp, "tn": tn, "fn": fn},
                "n_labeled": n,
                "precision": round(prec, 4) if prec is not None else None,
                "recall": round(rec, 4) if rec is not None else None,
                "false_positive_rate": round(fpr, 4) if fpr is not None else None,
                "false_negative_rate": round(fnr, 4) if fnr is not None else None,
            }

        # Find specific file
        target = "VID_20260629_181454"
        target_rows = [
            x
            for x in waverep_videos
            if target.lower() in (x.get("file_name") or "").lower()
        ]

        out = {
            "all_video_ai_rows": summarize(all_videos),
            "waverep_g4_video_rows": summarize(waverep_videos),
            "waverep_model_labels_seen": dict(models),
            "checkpoint_note": "weights_dinov2_G4.ckpt per waverep_g4_detector.DEFAULT_CHECKPOINT_REL",
            "production_thresholds": {
                "probe_low_risk": 0.30,
                "probe_high_risk": 0.45,
                "waverep_internal_prediction_threshold": 0.5,
            },
            "admin_labeled_waverep_for_sweep": len(labeled),
            "threshold_sweep_admin_labels_only": sweep,
            "target_vid_20260629": target_rows,
        }
        print(json.dumps(out, indent=2))
    finally:
        db.close()


if __name__ == "__main__":
    main()
