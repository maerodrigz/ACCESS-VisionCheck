"""Build a tiny synthetic development set (disjoint from NR001–NR015 and pilot)."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 512
SIGMAS = (0, 5, 10, 20, 40)
RNG_SEED = 20261109


def _flat(size: int = SIZE) -> np.ndarray:
    return np.full((size, size, 3), 128, dtype=np.uint8)


def _mild_texture(size: int = SIZE, rng: np.random.Generator | None = None) -> np.ndarray:
    rng = rng or np.random.default_rng(RNG_SEED)
    yy, xx = np.mgrid[0:size, 0:size]
    base = 110 + 35 * np.sin(xx / 48.0) + 25 * np.cos(yy / 64.0)
    blobs = 18 * np.sin((xx + yy) / 90.0) * np.cos(xx / 70.0)
    gray = np.clip(base + blobs, 0, 255).astype(np.uint8)
    rgb = np.stack([gray, gray, np.clip(gray.astype(np.int16) + 4, 0, 255).astype(np.uint8)], axis=-1)
    # Tiny deterministic dither so CLIP does not see a pure gradient cartoon.
    dither = rng.integers(-2, 3, size=rgb.shape, dtype=np.int16)
    return np.clip(rgb.astype(np.int16) + dither, 0, 255).astype(np.uint8)


def _rich_texture(size: int = SIZE, rng: np.random.Generator | None = None) -> np.ndarray:
    rng = rng or np.random.default_rng(RNG_SEED + 1)
    # Multi-scale procedural texture (not photographic Commons content).
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    field = (
        40 * np.sin(xx / 7.0)
        + 35 * np.cos(yy / 5.5)
        + 28 * np.sin((xx + 2 * yy) / 11.0)
        + 22 * np.cos((3 * xx - yy) / 9.0)
        + 18 * np.sin(xx * yy / 18000.0)
    )
    noise = rng.normal(0.0, 8.0, size=(size, size))
    gray = np.clip(128 + field + noise, 0, 255).astype(np.uint8)
    chroma = rng.integers(-6, 7, size=(size, size, 3), dtype=np.int16)
    rgb = np.clip(gray.astype(np.int16)[..., None] + chroma, 0, 255).astype(np.uint8)
    return rgb


SOURCES = {
    "DEV-FLAT": _flat,
    "DEV-MILD": _mild_texture,
    "DEV-TEX": _rich_texture,
}


def add_gaussian_noise(rgb: np.ndarray, sigma: float, rng: np.random.Generator) -> np.ndarray:
    if sigma <= 0:
        return rgb.copy()
    noise = rng.normal(0.0, float(sigma), size=rgb.shape)
    return np.clip(rgb.astype(np.float64) + noise, 0, 255).astype(np.uint8)


def build_dev_set(out_dir: Path) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    sources_dir = out_dir / "sources"
    noisy_dir = out_dir / "noisy"
    sources_dir.mkdir(exist_ok=True)
    noisy_dir.mkdir(exist_ok=True)

    rng = np.random.default_rng(RNG_SEED)
    manifest_rows: list[dict] = []

    for source_id, maker in SOURCES.items():
        clean = maker()
        src_path = sources_dir / f"{source_id}.png"
        Image.fromarray(clean, mode="RGB").save(src_path)
        for sigma in SIGMAS:
            noisy = add_gaussian_noise(clean, sigma, rng)
            name = f"{source_id}_sigma{int(sigma):02d}.png"
            path = noisy_dir / name
            Image.fromarray(noisy, mode="RGB").save(path)
            manifest_rows.append(
                {
                    "image_id": f"{source_id}_s{int(sigma)}",
                    "source_id": source_id,
                    "sigma": int(sigma),
                    "path": str(path.relative_to(out_dir)).replace("\\", "/"),
                    "source_path": str(src_path.relative_to(out_dir)).replace("\\", "/"),
                    "disjoint_from_nr001_015": True,
                    "disjoint_from_frozen_pilot": True,
                    "generation": "synthetic_procedural_rgb",
                }
            )

    payload = {
        "description": "CLIP noise feasibility development set (synthetic; not NR/pilot).",
        "sigmas": list(SIGMAS),
        "sources": list(SOURCES.keys()),
        "seed": RNG_SEED,
        "images": manifest_rows,
    }
    (out_dir / "dev_manifest.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return payload


if __name__ == "__main__":
    root = Path(__file__).resolve().parent / "dev_set"
    build_dev_set(root)
    print(f"Wrote {root}")
