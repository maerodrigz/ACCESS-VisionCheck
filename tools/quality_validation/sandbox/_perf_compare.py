"""One-off local timing helper for diagnostics overhead (not a unit test)."""

from __future__ import annotations

import sys
import time
from pathlib import Path

import cv2
import numpy as np

REPO = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(REPO), str(REPO / "access_backend"), str(REPO / "tools" / "quality_validation")]

from tools.quality_validation.sandbox.evaluator import evaluate  # noqa: E402


def main() -> None:
    rng = np.random.default_rng(0)
    img = (rng.random((512, 512, 3)) * 255).astype(np.uint8)
    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 90])
    assert ok
    data = bytes(buf)

    evaluate(data, include_diagnostics=False)
    evaluate(data, include_diagnostics=True)

    def run(flag: bool, n: int = 3):
        walls = []
        last = None
        for _ in range(n):
            t0 = time.perf_counter()
            last = evaluate(data, include_diagnostics=flag)
            walls.append((time.perf_counter() - t0) * 1000.0)
        return sum(walls) / len(walls), last

    off_ms, roff = run(False)
    on_ms, ron = run(True)

    badges_off = {c["name"]: c["badge"] for c in roff["engine_b"]["criteria"]}
    badges_on = {c["name"]: c["badge"] for c in ron["engine_b"]["criteria"]}

    print("PERF_COMPARE")
    print(f"wall_avg_ms_diagnostics_off={off_ms:.1f}")
    print(f"wall_avg_ms_diagnostics_on={on_ms:.1f}")
    print(f"delta_ms={on_ms - off_ms:.1f}")
    print(f"enet_ms_sample={ron['engine_a']['elapsed_ms']}")
    print(f"classical_ms_sample={ron['engine_b']['elapsed_ms']}")
    print(f"diagnostics_ms_sample={ron['diagnostics_elapsed_ms']}")
    print(f"scores_identical={badges_off == badges_on}")


if __name__ == "__main__":
    main()
