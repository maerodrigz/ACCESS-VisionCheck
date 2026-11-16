"""Safe, lazy PyTorch import (Windows App Control may block torch DLLs at import time)."""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger("ACCESS.torch_runtime")

_torch: Any | None = None
_torch_checked = False
_torch_error: str | None = None


def torch_import_error() -> str | None:
    """Human-readable reason PyTorch could not load, or None if load succeeded."""
    _ensure_torch()
    return _torch_error


def torch_available() -> bool:
    return _ensure_torch()


def _ensure_torch() -> bool:
    global _torch, _torch_checked, _torch_error
    if _torch_checked:
        return _torch is not None
    _torch_checked = True
    try:
        import torch as torch_mod

        _torch = torch_mod
        _torch_error = None
    except Exception as exc:  # ImportError, OSError (WinError 4551), etc.
        _torch = None
        _torch_error = f"{type(exc).__name__}: {exc}"
        logger.warning("PyTorch unavailable: %s", _torch_error)
    return _torch is not None


def get_torch() -> Any | None:
    """Return the torch module after a safe import attempt, or None."""
    return _torch if _ensure_torch() else None
