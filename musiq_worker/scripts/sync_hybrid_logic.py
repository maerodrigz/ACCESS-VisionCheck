#!/usr/bin/env python3
"""Re-copy Phase 1–3 hybrid modules from access_backend into this worker."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
SRC = REPO / "access_backend" / "app" / "services"
DEST = ROOT / "app" / "hybrid"

COPIES = {
    SRC / "quality_shadow" / "classical.py": DEST / "classical.py",
    SRC / "quality_shadow" / "feedback_rules.py": DEST / "feedback_rules.py",
    SRC / "quality_shadow" / "feedback_generator.py": DEST / "feedback_generator.py",
    SRC / "color_quality_criteria.py": DEST / "color_quality_criteria.py",
}


def _patch(path: Path, text: str) -> str:
    text = text.replace(
        "from app.services.quality_shadow.feedback_rules import",
        "from app.hybrid.feedback_rules import",
    )
    text = text.replace(
        "from app.services.color_quality_criteria import",
        "from app.hybrid.color_quality_criteria import",
    )
    if path.name == "color_quality_criteria.py":
        text = re.sub(
            r"from app\.services\.opencv_quality import decode_image\n\n",
            "",
            text,
            count=1,
        )
        if "_decode_bgr" not in text:
            helper = '''
def _decode_bgr(content: bytes) -> np.ndarray | None:
    if cv2 is None or not content:
        return None
    arr = np.frombuffer(content, dtype=np.uint8)
    return cv2.imdecode(arr, cv2.IMREAD_COLOR)


'''
            text = text.replace(
                "def analyze_color_criteria_bytes(content: bytes)",
                helper + "def analyze_color_criteria_bytes(content: bytes)",
            )
            text = text.replace(
                "bgr = decode_image(content) if content else None",
                "bgr = _decode_bgr(content) if content else None",
            )
    return text


def main() -> int:
    DEST.mkdir(parents=True, exist_ok=True)
    for src, dest in COPIES.items():
        if not src.is_file():
            raise SystemExit(f"missing source: {src}")
        dest.write_text(_patch(src, src.read_text(encoding="utf-8")), encoding="utf-8")
        print(f"synced {src.name} -> {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
