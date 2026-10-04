"""Build ACCESS launcher PNGs from the official org seal (1024 safe zone)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "images" / "access-org-seal.jpg"
CANVAS = 1024
# Fits full seal + ring text inside Android adaptive mask (with 20% xml inset).
MAX_FRAC = 0.78


def _load_seal() -> Image.Image:
    return Image.open(SRC).convert("RGBA")


def _scaled_seal(seal: Image.Image) -> Image.Image:
    w, h = seal.size
    limit = int(CANVAS * MAX_FRAC)
    scale = min(limit / w, limit / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    return seal.resize((nw, nh), Image.Resampling.LANCZOS)


def _paste_center(canvas: Image.Image, layer: Image.Image) -> None:
    x = (CANVAS - layer.width) // 2
    y = (CANVAS - layer.height) // 2
    canvas.paste(layer, (x, y), layer)


def main() -> None:
    if not SRC.is_file():
        raise SystemExit(f"Missing source seal: {SRC}")

    seal = _load_seal()
    scaled = _scaled_seal(seal)

    fg = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    _paste_center(fg, scaled)
    fg_path = ROOT / "assets" / "images" / "access_launcher_foreground.png"
    fg.save(fg_path, "PNG")

    legacy = Image.new("RGBA", (CANVAS, CANVAS), (255, 255, 255, 255))
    _paste_center(legacy, scaled)
    legacy_path = ROOT / "assets" / "images" / "access_app_icon.png"
    legacy.save(legacy_path, "PNG")

    print(f"Wrote {fg_path.name} ({scaled.width}x{scaled.height} seal on transparent)")
    print(f"Wrote {legacy_path.name} (white background)")


if __name__ == "__main__":
    main()
