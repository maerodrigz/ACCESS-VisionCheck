"""Reproducibility metadata for validation runs."""

from __future__ import annotations

import hashlib
import json
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from tools.quality_validation import __version__ as toolkit_version
from tools.quality_validation.engines import engine_availability


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def backend_root() -> Path:
    return repo_root() / "access_backend"


def git_revision(cwd: Path | None = None) -> str | None:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=cwd or repo_root(),
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )
        if out.returncode == 0:
            return out.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def weights_file_hash() -> dict[str, Any]:
    try:
        from app.services.efficientnet_b0_scorer import weights_path

        wp = weights_path()
        if wp.exists():
            return {"path": str(wp), "sha256": file_sha256(wp)}
        return {"path": str(wp), "sha256": None, "missing": True}
    except Exception as exc:
        return {"error": str(exc)}


def build_run_metadata(
    *,
    engines: list[str],
    video_sample_frames: int | None,
    dataset_manifest: str | None,
) -> dict[str, Any]:
    try:
        import numpy as np

        numpy_version = np.__version__
    except ImportError:
        numpy_version = None
    try:
        import cv2

        opencv_version = cv2.__version__
    except ImportError:
        opencv_version = None
    try:
        from app.services.efficientnet_b0_scorer import MODEL_ID, MODEL_VERSION

        model_id = MODEL_ID
        model_version = MODEL_VERSION
    except Exception:
        model_id = None
        model_version = None

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "toolkit_version": toolkit_version,
        "git_revision": git_revision(),
        "python_version": sys.version,
        "platform": platform.platform(),
        "numpy_version": numpy_version,
        "opencv_version": opencv_version,
        "efficientnet_model_id": model_id,
        "efficientnet_model_version": model_version,
        "weights_file": weights_file_hash(),
        "engine_availability": engine_availability(),
        "evaluation_config": {
            "engines_requested": engines,
            "video_sample_frames": video_sample_frames,
            "dataset_manifest": dataset_manifest,
            "include_authenticity": False,
            "writes_to_database": False,
        },
    }


def write_metadata(path: Path, meta: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(meta, indent=2), encoding="utf-8")
