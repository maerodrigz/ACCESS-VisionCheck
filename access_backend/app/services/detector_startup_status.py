"""Read-only AI / PyTorch readiness for manage.py banner and /api/health."""

from __future__ import annotations

from typing import Any

from app.services.torch_runtime import torch_available, torch_import_error


def integrity_detector_status() -> dict[str, Any]:
    """Configured detectors, checkpoint presence, and PyTorch load state (no inference)."""
    from app.config import settings
    from app.services.dedicated_ai_detector import active_ai_detector_backend
    from app.services.probe_dino_detector import checkpoint_path, probe_checkpoint_on_disk

    backend = active_ai_detector_backend()
    out: dict[str, Any] = {
        "detector_backend": backend,
        "pytorch_available": torch_available(),
    }
    err = torch_import_error()
    if err:
        out["pytorch_error"] = err

    if backend == "probe":
        ckpt = checkpoint_path()
        on_disk = probe_checkpoint_on_disk()
        out["probe_checkpoint"] = ckpt.name
        out["probe_checkpoint_on_disk"] = on_disk
        out["probe_checkpoint_ready"] = on_disk and torch_available()
        out["probe_low_risk_threshold"] = float(settings.probe_low_risk_threshold)
        out["probe_high_risk_threshold"] = float(settings.probe_high_risk_threshold)

    if getattr(settings, "waverep_enabled", False):
        from app.services.waverep_g4_detector import waverep_runtime_status

        out["waverep"] = waverep_runtime_status()

    return out
