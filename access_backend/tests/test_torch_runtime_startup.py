"""API startup must not require PyTorch import at module load."""

from __future__ import annotations


def test_main_app_imports_without_torch(monkeypatch) -> None:
    import app.services.torch_runtime as tr

    monkeypatch.setattr(tr, "_torch_checked", True)
    monkeypatch.setattr(tr, "_torch", None)
    monkeypatch.setattr(tr, "_torch_error", "OSError: blocked")

    from main import app

    assert app.title == "ACCESS VisionCheck API"


def test_active_backend_without_torch(monkeypatch) -> None:
    import app.services.torch_runtime as tr

    monkeypatch.setattr(tr, "_torch_checked", True)
    monkeypatch.setattr(tr, "_torch", None)
    monkeypatch.setattr(tr, "_torch_error", "OSError: blocked")

    from app.services.dedicated_ai_detector import active_ai_detector_backend

    assert active_ai_detector_backend() in ("probe", "univfd")


def test_probe_unavailable_when_torch_blocked(monkeypatch) -> None:
    import app.services.torch_runtime as tr

    monkeypatch.setattr(tr, "_torch_checked", True)
    monkeypatch.setattr(tr, "_torch", None)
    monkeypatch.setattr(tr, "_torch_error", "OSError: blocked")

    from app.services.probe_dino_detector import probe_checkpoint_on_disk, probe_detector_available

    if probe_checkpoint_on_disk():
        assert probe_detector_available() is False
