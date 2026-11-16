"""Non-destructive four-criterion video quality diagnostic (read-only vs DB).

Generates matched synthetic clips, calls existing evaluate_video, writes JSON only
under this folder. Does not modify scoring, weights, APIs, or PostgreSQL.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "assets"
OUT = ROOT / "out"
BACKEND = Path(__file__).resolve().parents[3] / "access_backend"

W, H, FPS, DUR = 640, 360, 10, 2.0
CRITERIA = ("Color Balance", "Color Saturation", "Motion Stability", "Flickering")


def _ensure_backend_path() -> None:
    sys.path.insert(0, str(BACKEND))
    os.chdir(BACKEND)


def make_base_still(path: Path) -> None:
    """Neutral documentation-like still with color variation and detail."""
    img = np.zeros((H, W, 3), dtype=np.uint8)
    # Soft sky / ground gradient (BGR).
    for y in range(H):
        t = y / max(H - 1, 1)
        img[y, :] = (
            int(210 - 40 * t),
            int(180 - 20 * t),
            int(140 + 30 * t),
        )
    # Colored subject blocks + texture for ENET/heuristic detail.
    cv2.rectangle(img, (80, 90), (220, 260), (60, 90, 210), -1)  # warm red-ish
    cv2.rectangle(img, (250, 110), (390, 280), (70, 170, 80), -1)  # green
    cv2.rectangle(img, (420, 100), (560, 270), (200, 120, 50), -1)  # blue-ish
    cv2.circle(img, (320, 180), 42, (40, 40, 40), -1)
    noise = np.random.default_rng(42).integers(0, 18, (H, W, 3), dtype=np.uint8)
    img = cv2.add(img, noise)
    # Edge detail
    cv2.putText(
        img,
        "ACCESS",
        (200, 330),
        cv2.FONT_HERSHEY_SIMPLEX,
        1.1,
        (30, 30, 30),
        2,
        cv2.LINE_AA,
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(path), img)


def run_ffmpeg(args: list[str]) -> None:
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args]
    subprocess.run(cmd, check=True)


def still_to_mp4(still: Path, out: Path) -> None:
    run_ffmpeg(
        [
            "-loop",
            "1",
            "-i",
            str(still),
            "-t",
            str(DUR),
            "-r",
            str(FPS),
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "18",
            str(out),
        ]
    )


def _reencode_h264(src: Path, out: Path) -> None:
    run_ffmpeg(
        [
            "-i",
            str(src),
            "-t",
            str(DUR),
            "-r",
            str(FPS),
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "18",
            "-an",
            str(out),
        ]
    )


def write_frames_mp4(frames: list[np.ndarray], out: Path) -> None:
    tmp = out.with_suffix(".tmp.mp4")
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(tmp), fourcc, FPS, (W, H))
    if not writer.isOpened():
        raise RuntimeError(f"Could not open VideoWriter for {out}")
    try:
        for frame in frames:
            writer.write(frame)
    finally:
        writer.release()
    _reencode_h264(tmp, out)
    tmp.unlink(missing_ok=True)


def write_variable_blur_mp4(still: Path, out: Path) -> None:
    """Alternate sharp vs heavily blurred frames (stress test for sharpness-delta proxy)."""
    base = cv2.imread(str(still))
    if base is None:
        raise RuntimeError(f"Could not read still: {still}")
    n = int(DUR * FPS)
    sharp = base
    blurry = cv2.GaussianBlur(base, (31, 31), sigmaX=18.0)
    frames = [sharp if (i // 2) % 2 == 0 else blurry for i in range(n)]
    write_frames_mp4(frames, out)


def write_extreme_flicker_mp4(still: Path, out: Path) -> None:
    """Alternate dark/bright frames so sampled brightness deltas are large."""
    base = cv2.imread(str(still))
    if base is None:
        raise RuntimeError(f"Could not read still: {still}")
    n = int(DUR * FPS)
    dark = np.clip(base.astype(np.float32) * 0.15, 0, 255).astype(np.uint8)
    bright = np.clip(base.astype(np.float32) * 1.55 + 40, 0, 255).astype(np.uint8)
    frames = [dark if (i // 2) % 2 == 0 else bright for i in range(n)]
    write_frames_mp4(frames, out)


def filter_mp4(src: Path, out: Path, vf: str) -> None:
    run_ffmpeg(
        [
            "-i",
            str(src),
            "-vf",
            vf,
            "-t",
            str(DUR),
            "-r",
            str(FPS),
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "18",
            "-an",
            str(out),
        ]
    )


def generate_clips() -> dict[str, Path]:
    ASSETS.mkdir(parents=True, exist_ok=True)
    still = ASSETS / "base_still.png"
    make_base_still(still)

    clips: dict[str, Path] = {}
    baseline = ASSETS / "01_baseline_neutral.mp4"
    still_to_mp4(still, baseline)
    clips["baseline_neutral"] = baseline

    # Color Balance: strong cool/magenta-green cast via hue rotate.
    tint = ASSETS / "02_color_strong_tint.mp4"
    filter_mp4(baseline, tint, "hue=h=140:s=1.2")
    clips["color_strong_tint"] = tint

    # Temporal tint (first half neutral-ish, second half strong tint) — mid-frame probe.
    temporal = ASSETS / "03_color_temporal_tint.mp4"
    filter_mp4(
        baseline,
        temporal,
        "hue=h='if(lt(t,1),0,140)':s='if(lt(t,1),1,1.25)'",
    )
    clips["color_temporal_tint"] = temporal

    # Saturation variants.
    desat = ASSETS / "04_sat_desaturated.mp4"
    filter_mp4(baseline, desat, "eq=saturation=0.12")
    clips["sat_desaturated"] = desat

    oversat = ASSETS / "05_sat_oversaturated.mp4"
    filter_mp4(baseline, oversat, "eq=saturation=2.6")
    clips["sat_oversaturated"] = oversat

    # Motion: geometric shake (crop oscillation) — may not change sharpness proxy.
    shake_geo = ASSETS / "06_motion_geometric_shake.mp4"
    filter_mp4(
        baseline,
        shake_geo,
        "crop=620:340:10+10*sin(4*2*PI*t):10+8*cos(5*2*PI*t),scale=640:360",
    )
    clips["motion_geometric_shake"] = shake_geo

    # Motion: sharpness proxy stimulus — OpenCV time-varying Gaussian blur.
    shake_blur = ASSETS / "07_motion_variable_blur.mp4"
    write_variable_blur_mp4(still, shake_blur)
    clips["motion_variable_blur"] = shake_blur

    # Flickering: mild FFmpeg eq (may be missed by sparse sampling + soft_score).
    flicker_mild = ASSETS / "08_flicker_brightness_mild.mp4"
    filter_mp4(baseline, flicker_mild, "eq=brightness='0.45*sin(2*PI*t*5)'")
    clips["flicker_brightness_mild"] = flicker_mild

    # Flickering: extreme alternating exposure (diagnostic for proxy sensitivity).
    flicker_ext = ASSETS / "09_flicker_brightness_extreme.mp4"
    write_extreme_flicker_mp4(still, flicker_ext)
    clips["flicker_brightness_extreme"] = flicker_ext

    return clips


def pick_criteria(payload: dict) -> dict:
    by_name = {c["name"]: c for c in payload.get("criteria") or [] if isinstance(c, dict)}
    out = {}
    for name in CRITERIA:
        c = by_name.get(name) or {}
        out[name] = {
            "score": c.get("score"),
            "available": c.get("available"),
            "label": c.get("label"),
            "estimate_kind": c.get("estimate_kind"),
            "explanation": (c.get("explanation") or "")[:160],
        }
    return out


def evaluate_clip(path: Path, *, repeats: int = 2) -> dict:
    from app.services.media_evaluator import evaluate_video

    content = path.read_bytes()
    runs = []
    for i in range(repeats):
        payload = evaluate_video(
            content,
            ext=".mp4",
            file_name=path.name,
            include_authenticity=False,
        )
        if payload is None:
            runs.append({"ok": False})
            continue
        analysis = payload.get("analysis") or {}
        runs.append(
            {
                "ok": True,
                "quality_engine": analysis.get("quality_engine"),
                "opencv_fallback": analysis.get("opencv_fallback"),
                "efficientnet_used": analysis.get("efficientnet_used"),
                "ffmpeg_used": analysis.get("ffmpeg_used"),
                "frames_analyzed": analysis.get("frames_analyzed"),
                "criteria": pick_criteria(payload),
            }
        )
    return {"path": str(path), "bytes": path.stat().st_size, "runs": runs}


def score_of(clip_result: dict, name: str) -> int | None:
    runs = clip_result.get("runs") or []
    if not runs or not runs[0].get("ok"):
        return None
    c = (runs[0].get("criteria") or {}).get(name) or {}
    if c.get("available") is False:
        return None
    s = c.get("score")
    return int(s) if isinstance(s, (int, float)) and s is not None else None


def verdict(baseline: int | None, altered: int | None, expect: str) -> str:
    if baseline is None or altered is None:
        return "inconclusive"
    if expect == "lower":
        if altered < baseline:
            return "pass"
        if altered == baseline:
            return "inconclusive"
        return "fail"
    if expect == "higher_or_equal":
        if altered >= baseline:
            return "pass"
        return "fail"
    if expect == "na_or_lower":
        # Desaturation may yield N/A (treated as success for muted look) or lower score.
        return "pass"  # caller handles N/A specially
    return "inconclusive"


def main() -> int:
    _ensure_backend_path()
    OUT.mkdir(parents=True, exist_ok=True)
    clips = generate_clips()

    from app.services.media_evaluator import preferred_quality_engine
    from app.services.ffmpeg_frames import ffmpeg_available

    results = {
        "preferred_quality_engine": preferred_quality_engine(),
        "ffmpeg_available": ffmpeg_available(),
        "clip_params": {"width": W, "height": H, "fps": FPS, "duration_s": DUR, "codec": "libx264"},
        "source": "Synthetic still (OpenCV colorful documentation-like scene) + FFmpeg transforms",
        "clips": {},
    }

    for key, path in clips.items():
        print(f"Evaluating {key} ...", flush=True)
        results["clips"][key] = evaluate_clip(path, repeats=2)

    b = results["clips"]["baseline_neutral"]
    comparisons = []

    def add(criterion: str, altered_key: str, expect: str, note: str) -> None:
        base_s = score_of(b, criterion)
        alt = results["clips"][altered_key]
        alt_s = score_of(alt, criterion)
        alt_avail = True
        if alt["runs"] and alt["runs"][0].get("ok"):
            c = alt["runs"][0]["criteria"][criterion]
            alt_avail = c.get("available") is not False
        if expect == "na_or_lower":
            if not alt_avail:
                v = "pass"
                actual = "N/A"
            elif alt_s is not None and base_s is not None and alt_s < base_s:
                v = "pass"
                actual = f"{base_s}->{alt_s} (lower)"
            elif alt_s == base_s:
                v = "inconclusive"
                actual = f"{base_s}->{alt_s} (unchanged)"
            else:
                v = "fail"
                actual = f"{base_s}->{alt_s}"
        else:
            v = verdict(base_s, alt_s, expect)
            actual = f"{base_s}->{alt_s}"
            if expect == "lower":
                if alt_s is not None and base_s is not None:
                    if alt_s < base_s:
                        actual += " (lower, as expected)"
                    elif alt_s > base_s:
                        actual += " (higher, unexpected)"
                    else:
                        actual += " (unchanged)"
        comparisons.append(
            {
                "criterion": criterion,
                "altered_clip": altered_key,
                "baseline_score": base_s,
                "altered_score": alt_s if alt_avail else "N/A",
                "expected": expect,
                "actual": actual,
                "verdict": v,
                "note": note,
            }
        )

    add(
        "Color Balance",
        "color_strong_tint",
        "lower",
        "Strong global hue cast should lower heuristic Color Balance vs neutral mid-frame.",
    )
    add(
        "Color Balance",
        "color_temporal_tint",
        "lower",
        "Second-half tint only; mid sampled frame may miss early neutral or late tint.",
    )
    add(
        "Color Saturation",
        "sat_desaturated",
        "na_or_lower",
        "Muted/near-mono may score N/A or lower than typical-range baseline.",
    )
    add(
        "Color Saturation",
        "sat_oversaturated",
        "lower",
        "Heavy oversaturation should leave typical-range (5) toward 3 or 2.",
    )
    add(
        "Motion Stability",
        "motion_geometric_shake",
        "lower",
        "Crop/shake without blur: sharpness proxy may not detect pure translation.",
    )
    add(
        "Motion Stability",
        "motion_variable_blur",
        "lower",
        "Time-varying blur should increase frame-to-frame sharpness deltas.",
    )
    add(
        "Flickering",
        "flicker_brightness_mild",
        "lower",
        "Mild FFmpeg brightness oscillation; sparse samples + soft_score may keep score at 5.",
    )
    add(
        "Flickering",
        "flicker_brightness_extreme",
        "lower",
        "Extreme alternating dark/bright frames (stress test for brightness-delta proxy).",
    )

    # Determinism check
    determinism = {}
    for key, clip in results["clips"].items():
        runs = clip.get("runs") or []
        if len(runs) < 2 or not runs[0].get("ok") or not runs[1].get("ok"):
            determinism[key] = "incomplete"
            continue
        same = True
        for name in CRITERIA:
            a = runs[0]["criteria"][name]
            b2 = runs[1]["criteria"][name]
            if (a.get("score"), a.get("available")) != (b2.get("score"), b2.get("available")):
                same = False
                break
        determinism[key] = "identical" if same else "differed"

    report = {
        "meta": {
            "preferred_quality_engine": results["preferred_quality_engine"],
            "ffmpeg_available": results["ffmpeg_available"],
            "source": results["source"],
            "clip_params": results["clip_params"],
            "db_writes": False,
            "authenticity": "deferred (include_authenticity=False)",
        },
        "clips": results["clips"],
        "determinism": determinism,
        "comparisons": comparisons,
    }

    out_json = OUT / "four_criterion_video_validation.json"
    out_json.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"wrote": str(out_json), "comparisons": comparisons, "determinism": determinism}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
