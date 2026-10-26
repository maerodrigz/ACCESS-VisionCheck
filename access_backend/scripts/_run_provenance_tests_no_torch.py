#!/usr/bin/env python3
"""Run provenance tests when torch DLL is blocked (Windows App Control)."""
from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import MagicMock

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))

class _TorchMock(MagicMock):
    class nn:
        Module = object

    class _utils:
        @staticmethod
        def _get_device_index(*_a, **_k):
            return 0


torch_mock = _TorchMock()
torch_mock.nn = _TorchMock.nn
torch_mock._utils = _TorchMock._utils
sys.modules["torch"] = torch_mock
sys.modules["torch.nn"] = torch_mock.nn
for name in (
    "torchvision",
    "torchvision.transforms",
    "torchvision.models",
    "torch._dynamo",
    "torch._dynamo.utils",
):
    sys.modules.setdefault(name, MagicMock())

import types

_eff_stub = types.ModuleType("app.services.efficientnet_b0_scorer")
_eff_stub.MODEL_ID = "efficientnet-b0"
_eff_stub.analyze_image_bytes = lambda *_a, **_k: {}  # type: ignore[attr-defined]
_eff_stub.efficientnet_available = lambda: False  # type: ignore[attr-defined]
_eff_stub.ensure_weights = lambda: None  # type: ignore[attr-defined]
sys.modules["app.services.efficientnet_b0_scorer"] = _eff_stub

import pytest

ARGS = sys.argv[1:] or [
    "tests/test_video_provenance_phase21.py",
    "tests/test_camera_provenance_policy.py",
    "-q",
]

if __name__ == "__main__":
    raise SystemExit(pytest.main(ARGS))
