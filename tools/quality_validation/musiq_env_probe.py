"""One-shot environment probe for the MUSIQ research benchmark. No model download."""

from __future__ import annotations

import platform
import shutil
import sys
from pathlib import Path


def main() -> None:
    print("exe", sys.executable)
    print("ver", sys.version.replace("\n", " "))
    print("plat", platform.platform())
    try:
        import torch
        import torchvision

        print("torch", torch.__version__)
        print("tv", torchvision.__version__)
        print("cuda", torch.cuda.is_available())
        print("cuda_ver", getattr(torch.version, "cuda", None))
        print("device_count", torch.cuda.device_count())
        if torch.cuda.is_available():
            print("gpu", torch.cuda.get_device_name(0))
    except Exception as exc:  # pragma: no cover
        print("torch_err", type(exc).__name__, exc)
    try:
        import timm

        print("timm", timm.__version__)
    except Exception as exc:  # pragma: no cover
        print("timm_err", type(exc).__name__, exc)
    try:
        import pyiqa

        print("pyiqa", pyiqa.__version__)
    except Exception:
        print("pyiqa", "not_installed")
    usage = shutil.disk_usage(Path(__file__).resolve().anchor)
    print("disk_total_gb", round(usage.total / 1e9, 2))
    print("disk_free_gb", round(usage.free / 1e9, 2))


if __name__ == "__main__":
    main()
