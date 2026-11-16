"""One-off manifest verification (HTTPS + certifi). Does not download video bodies."""
from __future__ import annotations

import csv
import io
import json
import re
import ssl
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

try:
    import certifi

    SSL_CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    SSL_CTX = ssl.create_default_context()

MANIFEST = Path(__file__).resolve().parents[1] / "docs" / "waverep_g4_validation_manifest_60_PLAN.csv"
VISION_INDEX_URL = "https://lesc.dinfo.unifi.it/VISION/VISION_files.txt"
HF_DATASET_API = "https://huggingface.co/api/datasets/microsoft/AVGen-Bench"
HF_PARQUET_URL = "https://huggingface.co/datasets/microsoft/AVGen-Bench/resolve/main/metadata.parquet"

ERRATA_NAMES = {
    "D03_V_flat_still_0002.mp4",
    "D03_V_flatYT_still_0002.mp4",
    "D03_V_flatWA_still_0002.mp4",
    "D19_V_flat_move_0002.mov",
    "D19_V_flatYT_move_0002.mp4",
    "D19_V_flatWA_move_0002.mp4",
}

NATIVE_VIDEO_EXT = (".mp4", ".mov", ".3gp")


def _fetch(url: str, *, method: str = "GET") -> tuple[int, dict[str, str], bytes]:
    req = urllib.request.Request(
        url,
        method=method,
        headers={"User-Agent": "ACCESS-VisionCheck-manifest-verify/1.0"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120, context=SSL_CTX) as resp:
            headers = {k.lower(): v for k, v in resp.headers.items()}
            body = b"" if method == "HEAD" else resp.read()
            return resp.status, headers, body
    except urllib.error.HTTPError as e:
        headers = {k.lower(): v for k, v in e.headers.items()} if e.headers else {}
        return e.code, headers, b""


def is_native_video_url(url: str) -> bool:
    low = url.lower()
    if "/videos/" not in low:
        return False
    if any(
        x in low
        for x in (
            "flatwa",
            "flatyt",
            "indoorwa",
            "indooryt",
            "outdoorwa",
            "outdooryt",
            "/natfb",
            "/natwa",
        )
    ):
        return False
    if not any(p in low for p in ("/videos/flat/", "/videos/indoor/", "/videos/outdoor/")):
        return False
    if not low.endswith(NATIVE_VIDEO_EXT):
        return False
    fn = url.rsplit("/", 1)[-1]
    return fn not in ERRATA_NAMES


def parse_vision_url(url: str) -> dict[str, str] | None:
    m = re.search(
        r"/D(\d+)_([A-Za-z]+)_([^/]+)/videos/(flat|indoor|outdoor)/([^/]+)$",
        url,
    )
    if not m:
        return None
    return {
        "device_id": f"D{int(m.group(1)):02d}",
        "phone_brand": m.group(2),
        "phone_model": m.group(3),
        "scene_category": m.group(4),
        "filename": m.group(5),
    }


def load_vision_native_index() -> set[str]:
    _, _, body = _fetch(VISION_INDEX_URL)
    lines = body.decode("utf-8", errors="replace").splitlines()
    return {ln.strip() for ln in lines if ln.strip() and is_native_video_url(ln.strip())}


def vision_row(url: str, *, status: str, size: str | int, notes: str) -> dict[str, str]:
    meta = parse_vision_url(url) or {}
    rel = "dataset/" + url.split("/dataset/", 1)[-1]
    return {
        "dataset_source": "VISION",
        "source_url": url,
        "relative_file_path": rel,
        "ground_truth_label": "genuine",
        "phone_brand": meta.get("phone_brand", "unknown"),
        "phone_model": meta.get("phone_model", "unknown"),
        "generation_model": "unknown",
        "scene_category": meta.get("scene_category", "unknown"),
        "file_size_bytes": str(size),
        "sha256": "not_yet_downloaded",
        "verification_status": status,
        "license_or_access_notes": notes,
    }


def http_safe_url(url: str) -> str:
    parts = urllib.parse.urlsplit(url)
    path = urllib.parse.quote(parts.path, safe="/:@")
    return urllib.parse.urlunsplit((parts.scheme, parts.netloc, path, parts.query, parts.fragment))


def head_size(url: str) -> tuple[str, str]:
    status, headers, _ = _fetch(http_safe_url(url), method="HEAD")
    if status != 200:
        return "head_failed", f"http_{status}"
    cl = headers.get("content-length")
    if cl and cl.isdigit():
        return "verified_index_and_head", cl
    return "verified_index_head_no_cl", "unknown"


def load_avgen_paths() -> tuple[set[str], dict[str, dict]]:
    _, _, body = _fetch(HF_DATASET_API)
    info = json.loads(body.decode())
    siblings = {s["rfilename"]: s for s in info.get("siblings", []) if s.get("rfilename")}

    import pyarrow.parquet as pq  # noqa: PLC0415

    _, _, pq_body = _fetch(HF_PARQUET_URL)
    df = pq.read_table(io.BytesIO(pq_body)).to_pandas()
    parquet_paths = set(df["video_path"].astype(str))
    return siblings.keys() | parquet_paths, siblings


def main() -> None:
    native = load_vision_native_index()
    by_brand = defaultdict(list)
    for u in sorted(native):
        p = parse_vision_url(u)
        if p:
            by_brand[p["phone_brand"]].append(u)

    rows = list(csv.DictReader(MANIFEST.open(encoding="utf-8")))
    genuine = [r for r in rows if r["ground_truth_label"] == "genuine"]
    ai = [r for r in rows if r["ground_truth_label"] == "ai_generated"]

    verified_genuine: list[dict[str, str]] = []
    used_urls: set[str] = set()
    for r in genuine:
        url = r["source_url"]
        if url not in native or url in used_urls:
            continue
        used_urls.add(url)
        size_status, size_val = head_size(url)
        verified_genuine.append(
            vision_row(
                url,
                status=size_status,
                size=size_val,
                notes="CC BY-SA 4.0; native flat/indoor/outdoor; social variants and errata excluded",
            )
        )

    # Lenovo native clips are mostly .3gp in VISION (not .mp4); add up to 5 verified clips.
    lenovo_pool = sorted(u for u in native if "/Lenovo_" in u)
    for url in lenovo_pool:
        if sum(1 for x in verified_genuine if x["phone_brand"] == "Lenovo") >= 5:
            break
        if url in used_urls:
            continue
        used_urls.add(url)
        size_status, size_val = head_size(url)
        verified_genuine.append(
            vision_row(
                url,
                status=size_status,
                size=size_val,
                notes="CC BY-SA 4.0; native Lenovo capture (.3gp where device-native); errata excluded",
            )
        )

    target_brands = [
        "Samsung",
        "Huawei",
        "Apple",
        "LG",
        "Sony",
        "Microsoft",
        "Wiko",
        "Asus",
        "Xiaomi",
        "OnePlus",
        "Lenovo",
    ]
    counts = Counter(r["phone_brand"] for r in verified_genuine)
    while len(verified_genuine) < 40:
        progressed = False
        for brand in target_brands:
            if len(verified_genuine) >= 40:
                break
            if counts[brand] >= 5:
                continue
            for url in by_brand.get(brand, []):
                if url in used_urls:
                    continue
                used_urls.add(url)
                size_status, size_val = head_size(url)
                verified_genuine.append(
                    vision_row(
                        url,
                        status=size_status,
                        size=size_val,
                        notes="CC BY-SA 4.0; native flat/indoor/outdoor; added during verification fill",
                    )
                )
                counts[brand] += 1
                progressed = True
                break
        if not progressed:
            break

    if len({r["source_url"] for r in verified_genuine}) < len(verified_genuine):
        raise RuntimeError("duplicate genuine URLs in manifest")

    if len(verified_genuine) != 40:
        raise RuntimeError(f"expected 40 genuine rows, got {len(verified_genuine)}")

    for r in verified_genuine:
        if r["source_url"] not in native:
            raise RuntimeError(f"genuine row not in index: {r['relative_file_path']}")

    hf_paths, hf_siblings = load_avgen_paths()
    verified_ai: list[dict[str, str]] = []
    for r in ai:
        vp = r["relative_file_path"]
        in_parquet = vp in hf_paths
        sib = hf_siblings.get(vp)
        hf_url = http_safe_url(
            f"https://huggingface.co/datasets/microsoft/AVGen-Bench/resolve/main/{vp}"
        )
        if not in_parquet:
            verified_ai.append(
                {
                    **r,
                    "verification_status": "missing_from_hf_index",
                    "file_size_bytes": "unknown",
                }
            )
            continue
        size = "unknown"
        status = "verified_parquet"
        if sib and sib.get("size") is not None:
            size = str(sib["size"])
            status = "verified_parquet_and_hf_api_size"
        else:
            hs, hv = head_size(hf_url)
            if hs.startswith("verified") and hv.isdigit():
                size = hv
                status = "verified_parquet_and_head"
            elif hs == "head_failed":
                status = "verified_parquet_head_failed"
        verified_ai.append(
            {
                "dataset_source": "AVGen-Bench",
                "source_url": hf_url,
                "relative_file_path": vp,
                "ground_truth_label": "ai_generated",
                "phone_brand": "unknown",
                "phone_model": "unknown",
                "generation_model": r.get("generation_model") or vp.split("/")[0],
                "scene_category": r.get("scene_category") or "unknown",
                "file_size_bytes": size,
                "sha256": "not_yet_downloaded",
                "verification_status": status,
                "license_or_access_notes": "MIT (HF tag license:mit); synthetic AVGen-Bench output",
            }
        )

    out_rows = verified_genuine + verified_ai
    fieldnames = [
        "dataset_source",
        "source_url",
        "relative_file_path",
        "ground_truth_label",
        "phone_brand",
        "phone_model",
        "generation_model",
        "scene_category",
        "file_size_bytes",
        "sha256",
        "verification_status",
        "license_or_access_notes",
    ]
    with MANIFEST.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for row in out_rows:
            w.writerow({k: row.get(k, "") for k in fieldnames})

    print("WROTE", MANIFEST)
    print("genuine_brands", dict(Counter(r["phone_brand"] for r in verified_genuine)))
    print("ai_status", dict(Counter(r["verification_status"] for r in verified_ai)))
    g_sizes = [int(r["file_size_bytes"]) for r in verified_genuine if str(r["file_size_bytes"]).isdigit()]
    a_sizes = [int(r["file_size_bytes"]) for r in verified_ai if str(r["file_size_bytes"]).isdigit()]
    print("vision_size_sum_known", sum(g_sizes), "count", len(g_sizes))
    print("avgen_size_sum_known", sum(a_sizes), "count", len(a_sizes))


if __name__ == "__main__":
    main()
