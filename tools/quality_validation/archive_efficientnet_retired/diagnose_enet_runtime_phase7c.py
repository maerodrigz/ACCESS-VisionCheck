# ARCHIVED — EfficientNet-B0 retired. Non-executable without deleted scorer/weights.
# See archive_efficientnet_retired/README.md

#!/usr/bin/env python3
"""Phase 7C: diagnose why EfficientNet-B0 was skipped in Phase 7B.

Read-only. Does not edit .env, uploads, evaluations, or research artifacts.

Usage (Windows CMD):
  cd /d C:\\Users\\Dell\\Desktop\\access_mobile\\access_backend
  python scripts\\diagnose_enet_runtime_phase7c.py
"""

from __future__ import annotations

import json
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

REPORT = ROOT / "scripts" / "_verify_out" / "phase7c_enet_runtime_diagnose.json"
TEST_IMAGE = Path(
    r"C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos\IMG_20230512_103539_795.jpg"
)


def main() -> int:
    from dotenv import load_dotenv

    load_dotenv(ROOT / ".env", override=False)

    report: dict[str, Any] = {
        "phase": "7C",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "env_file_modified": False,
        "cutover_activated": False,
    }

    from app.services.torch_runtime import get_torch, torch_available, torch_import_error
    from app.services import efficientnet_b0_scorer as enet
    from app.services.media_evaluator import (
        preferred_quality_engine,
        resolve_quality_engine_for_bytes,
        QUALITY_ENGINE_EFFICIENTNET,
        QUALITY_ENGINE_OPENCV,
    )
    from app.services.opencv_quality import opencv_available
    from app.config import settings
    from app.services.musiq_worker_client import quality_engine, production_uses_enet

    weights = enet.weights_path()
    report["settings_quality_engine"] = settings.quality_engine
    report["client_quality_engine"] = quality_engine()
    report["production_uses_enet"] = production_uses_enet()
    report["torch"] = {
        "available": torch_available(),
        "import_error": torch_import_error(),
        "module_repr": repr(get_torch()) if torch_available() else None,
    }
    try:
        import PIL  # noqa: F401
        from PIL import Image  # noqa: F401

        pil_ok = True
        pil_err = None
    except Exception as exc:  # noqa: BLE001
        pil_ok = False
        pil_err = f"{type(exc).__name__}: {exc}"
    report["pil"] = {"available": pil_ok, "error": pil_err}

    report["weights"] = {
        "path": str(weights),
        "exists": weights.is_file(),
        "size_bytes": weights.stat().st_size if weights.is_file() else None,
    }
    report["efficientnet_available"] = enet.efficientnet_available()
    report["opencv_available"] = opencv_available()

    # Probe ensure_weights / model load with visible errors (scorer swallows them).
    load_probe: dict[str, Any] = {"ensure_weights": None, "build_error": None, "load_error": None}
    try:
        load_probe["ensure_weights"] = bool(enet.ensure_weights())
    except Exception as exc:  # noqa: BLE001
        load_probe["ensure_weights_exception"] = f"{type(exc).__name__}: {exc}"

    if not load_probe.get("ensure_weights"):
        try:
            model = enet._build_iqa_model()  # noqa: SLF001
            load_probe["build_ok"] = model is not None
            if model is None:
                load_probe["build_error"] = " _build_iqa_model returned None"
            else:
                torch = get_torch()
                assert torch is not None
                try:
                    state = torch.load(weights, map_location="cpu", weights_only=True)
                except TypeError:
                    state = torch.load(weights, map_location="cpu")
                model.load_state_dict(state, strict=False)
                model.eval()
                load_probe["manual_load_ok"] = True
        except Exception as exc:  # noqa: BLE001
            load_probe["manual_load_ok"] = False
            load_probe["load_error"] = f"{type(exc).__name__}: {exc}"
            load_probe["traceback"] = traceback.format_exc()
    report["model_load_probe"] = load_probe

    preferred = preferred_quality_engine()
    report["preferred_quality_engine"] = preferred
    report["preferred_interpretation"] = (
        "ENET preferred"
        if preferred == QUALITY_ENGINE_EFFICIENTNET
        else (
            "OpenCV preferred because ENET unavailable/unloaded"
            if preferred == QUALITY_ENGINE_OPENCV
            else "No local quality engine"
        )
    )

    # Resolution on real image (default QUALITY_ENGINE from settings / .env, usually enet).
    if TEST_IMAGE.is_file():
        content = TEST_IMAGE.read_bytes()
        metrics, engine, opencv_fallback = resolve_quality_engine_for_bytes(content)
        report["resolve_default"] = {
            "engine": engine,
            "opencv_fallback": opencv_fallback,
            "metrics_keys": sorted(metrics.keys()) if isinstance(metrics, dict) else None,
            "has_metrics": metrics is not None,
            "image_bytes": len(content),
        }
        if engine == QUALITY_ENGINE_EFFICIENTNET and metrics is not None:
            # Confirm inference values exist
            report["resolve_default"]["sample_sharpness"] = metrics.get("sharpness")
        elif preferred != QUALITY_ENGINE_EFFICIENTNET:
            report["resolve_default"]["why_not_enet"] = (
                "preferred_quality_engine did not select efficientnet-b0 "
                f"(efficientnet_available={enet.efficientnet_available()}, "
                f"ensure_weights={load_probe.get('ensure_weights')})"
            )
        else:
            # ENET preferred but resolve returned something else
            direct = enet.analyze_image_bytes(content)
            report["resolve_default"]["direct_enet_analyze"] = direct is not None
            if direct is None:
                report["resolve_default"]["why_not_enet"] = (
                    "preferred ENET but analyze_image_bytes returned None"
                )
    else:
        report["resolve_default"] = {"error": f"missing image {TEST_IMAGE}"}

    # Simulate musiq_worker failure chain flags without calling worker.
    report["fallback_chain_contract"] = {
        "order_when_QUALITY_ENGINE_musiq_worker": [
            "musiq_worker",
            "efficientnet-b0",
            "opencv",
        ],
        "phase7b_observed_worker_unavailable_engine": "opencv",
        "phase7b_observed_default_enet_engine": "opencv",
        "phase7b_default_opencv_fallback_flag": False,
        "meaning_of_opencv_fallback_false_on_enet_control": (
            "preferred_quality_engine() returned opencv, so ENET was not considered ready "
            "(efficientnet_available/ensure_weights false). OpenCV was the primary local engine, "
            "not a post-ENET fallback."
        ),
        "meaning_of_opencv_fallback_true_on_worker_unavailable": (
            "from_musiq_fallback=True forces opencv_fallback=True even when ENET was never ready; "
            "OpenCV success alone does not prove ENET fallback worked."
        ),
    }

    report["finished_at"] = datetime.now(timezone.utc).isoformat()
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")
    print(json.dumps(report, indent=2, default=str))
    print("report_written", REPORT)

    # Non-zero if ENET cannot run (the Phase 7B defect under investigation).
    if not enet.efficientnet_available() or not load_probe.get("ensure_weights"):
        return 2
    if report.get("resolve_default", {}).get("engine") != QUALITY_ENGINE_EFFICIENTNET:
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

