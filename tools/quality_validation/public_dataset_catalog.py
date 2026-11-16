"""Catalog of public datasets for ACCESS criterion validation. Research only."""

from __future__ import annotations

from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
DATASETS_ROOT = _TOOLKIT / "workspace" / "datasets"

# ACCESS criteria that can be claimed only with matching human attribute labels.
ACCESS_CRITERIA = (
    "Sharpness",
    "Blur",
    "Noise",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Ringing Artifacts",
)

CATALOG: list[dict[str, Any]] = [
    {
        "id": "spaq",
        "name": "SPAQ (Smartphone Photography Attribute and Quality)",
        "official_source": "https://github.com/h4nwei/SPAQ",
        "paper": "Fang et al., CVPR 2020. Open access: https://openaccess.thecvf.com/content_CVPR_2020/html/Fang_Perceptual_Quality_Assessment_of_Smartphone_Photography_CVPR_2020_paper.html",
        "download": "Google Drive folder and Baidu Yun (code b29m) linked from the GitHub README. Annotations are not in the git tree.",
        "n_images": 11125,
        "annotations": (
            "Overall MOS (0-100); attributes brightness, colorfulness, contrast, noisiness, sharpness (0-100); "
            "scene categories; EXIF."
        ),
        "license": (
            "GitHub issue discussion treats the dataset as MIT-licensed; use remains research evaluation only "
            "in this project. Do not ship SPAQ-trained weights in ACCESS. Do not train production heads on SPAQ "
            "in this phase."
        ),
        "access_map": {
            "Sharpness": "related_proxy: SPAQ sharpness; paper says it is inversely proportional to blur level (no Blur split).",
            "Blur": "not_mapped: collapsed into SPAQ sharpness.",
            "Noise": "directly_comparable_after_invert: noisiness high = more sensor noise.",
            "Brightness": "related_proxy: low = poorly exposed; overexposure coding not split from underexposure.",
            "Contrast": "related_proxy: low = reduced contrast; no harsh-clip penalty in the published definition.",
            "Blocking Artifacts": "not_mapped",
            "Ringing Artifacts": "not_mapped",
        },
        "overlap": (
            "ACCESS EfficientNet heads: SyntheticIQADataset only, not SPAQ. "
            "MUSIQ PaQ-2-PiQ checkpoint is not SPAQ-trained. A separate SPAQ MUSIQ/MT-A checkpoint exists; do not use it here."
        ),
        "expected_layout": "workspace/datasets/spaq/images/*.jpg and workspace/datasets/spaq/metadata/MOS_and_attributes.csv or .xlsx",
    },
    {
        "id": "cid2013",
        "name": "CID2013",
        "official_source": "https://doi.org/10.5281/zenodo.2647032",
        "paper": "Virtanen et al., CID2013 camera image database.",
        "download": "Zenodo. Research use with citation.",
        "n_images": 480,
        "annotations": "Overall MOS plus sharpness, graininess, lightness, color saturation scales.",
        "license": "Freely available for the research community; cite the paper. Confirm Zenodo terms before redistribution.",
        "access_map": {
            "Sharpness": "related_proxy: CID sharpness scale; may still mix focus and texture.",
            "Blur": "not_mapped: no separate motion/defocus scale.",
            "Noise": "related_proxy: graininess (invert if high = more grain; confirm on the score sheet before use).",
            "Brightness": "related_proxy: lightness, not ACCESS subject-exposure triangle.",
            "Contrast": "not_mapped",
            "Blocking Artifacts": "not_mapped",
            "Ringing Artifacts": "not_mapped",
        },
        "overlap": "Not used in ACCESS EfficientNet training.",
        "expected_layout": "workspace/datasets/cid2013/",
    },
    {
        "id": "bid",
        "name": "Blurred Image Database (BID)",
        "official_source": "Literature: Ciancio et al. / related authentic-blur IQA sets. Locate the authors' current host before use.",
        "paper": "Authentic blur MOS (often a single blur quality score).",
        "download": "Author request / project page. Not on this machine.",
        "n_images": None,
        "annotations": "Typically one blur-centric MOS per photo, not Sharpness vs Blur.",
        "license": "Follow the host lab terms. Usually research-only.",
        "access_map": {
            "Sharpness": "not_mapped_without_sheet: do not copy blur MOS into Sharpness.",
            "Blur": "related_proxy_if_mos_is_blur_quality: invert if the published score is blur amount.",
            "Noise": "not_mapped",
            "Brightness": "not_mapped",
            "Contrast": "not_mapped",
            "Blocking Artifacts": "not_mapped",
            "Ringing Artifacts": "not_mapped",
        },
        "overlap": "Not used in ACCESS EfficientNet training.",
        "expected_layout": "workspace/datasets/bid/",
    },
    {
        "id": "live_iqa",
        "name": "LIVE Image Quality Assessment Database Release 2",
        "official_source": "https://www.colorado.edu/lab/live/live-image-quality-assessment-database",
        "paper": "Sheikh, Sabir, Bovik TIP 2006; Wang et al. SSIM TIP 2004.",
        "download": "Free for research after agreeing to LIVE terms. JPEG 169, JP2K 175, Gaussian blur 145, WN 145, fast-fading 145.",
        "n_images": 779,
        "annotations": "DMOS for the whole image. Distortion type is known. Not seven ACCESS attributes.",
        "license": "Research use; cite LIVE. Not a commercial product license.",
        "access_map": {
            "Sharpness": "not_mapped: no sharpness attribute.",
            "Blur": "partial: Gaussian-blur subset DMOS is overall quality of a blurry image, not ACCESS Blur 1-5.",
            "Noise": "partial: white-noise subset DMOS similarly overall.",
            "Brightness": "not_mapped",
            "Contrast": "not_mapped",
            "Blocking Artifacts": "partial: JPEG subset DMOS; JPEG also blurs and rings.",
            "Ringing Artifacts": "partial: JPEG2000 subset DMOS (codec ringing, not phone unsharp).",
        },
        "overlap": "Not used in ACCESS EfficientNet training. Synthetic trainer used Gaussian/AWGN/JPEG knobs, not LIVE images.",
        "expected_layout": "workspace/datasets/live_iqa/",
    },
    {
        "id": "tid2013",
        "name": "TID2013",
        "official_source": "https://qualinet.github.io/databases/image/tampere_image_database_tid2013/",
        "paper": "Ponomarenko et al. TID2013.",
        "download": "Free for scientific use from the authors' host.",
        "n_images": 3000,
        "annotations": "MOS on 24 distortion types × 5 levels × 25 references. One overall MOS per distorted image.",
        "license": "Scientific use; cite TID2013.",
        "access_map": {
            "Sharpness": "not_mapped",
            "Blur": "partial: Gaussian blur type MOS.",
            "Noise": "partial: additive noise types MOS.",
            "Brightness": "partial: intensity shift / mean shift types, still overall MOS.",
            "Contrast": "partial: contrast-change type MOS; may reward or punish opposite to ACCESS harsh-clip rule.",
            "Blocking Artifacts": "partial: JPEG type MOS.",
            "Ringing Artifacts": "partial: JPEG2000 type MOS.",
        },
        "overlap": "Not ACCESS training images.",
        "expected_layout": "workspace/datasets/tid2013/",
    },
    {
        "id": "csiq",
        "name": "CSIQ",
        "official_source": "http://vision.eng.shizuoka.ac.jp/mod/page/view.php?id=23 (historical CSIQ page; confirm current host).",
        "paper": "Larson and Chandler, CSIQ.",
        "download": "Research download from the authors.",
        "n_images": 866,
        "annotations": "DMOS; JPEG, JP2K, AWGN, blur, contrast, pink noise.",
        "license": "Research; cite CSIQ.",
        "access_map": {
            "Sharpness": "not_mapped",
            "Blur": "partial: blur subset DMOS.",
            "Noise": "partial: AWGN subset DMOS.",
            "Brightness": "not_mapped",
            "Contrast": "partial: contrast subset DMOS.",
            "Blocking Artifacts": "partial: JPEG subset DMOS.",
            "Ringing Artifacts": "partial: JP2K subset DMOS.",
        },
        "overlap": "Not ACCESS training images.",
        "expected_layout": "workspace/datasets/csiq/",
    },
    {
        "id": "kadid10k",
        "name": "KADID-10k",
        "official_source": "https://database.mmsp-kn.de/kadid-10k-database.html",
        "paper": "Lin, Hosu, Saupe. 81 pristine × 25 distortions × 5 levels; 30 DCR ratings.",
        "download": "MMSP Konstanz page. Pristine photos Pixabay license; distorted set per database terms.",
        "n_images": 10125,
        "annotations": "Crowdsourced DCR MOS per distorted image. Distortion type known (blurs, JPEG, JP2K, noises, brightness, contrast, pixelate, etc.).",
        "license": "Follow MMSP Konstanz terms. Pristine Pixabay images are redistributable; ratings follow the database license.",
        "access_map": {
            "Sharpness": "not_mapped as a separate attribute.",
            "Blur": "partial: Gaussian/lens/motion blur subsets.",
            "Noise": "partial: white/impulse/multiplicative noise subsets.",
            "Brightness": "partial: brighten/darken subsets (overall MOS).",
            "Contrast": "partial: contrast-change subsets.",
            "Blocking Artifacts": "partial: JPEG / pixelate / color-blocking subsets.",
            "Ringing Artifacts": "partial: JPEG2000 subset.",
        },
        "overlap": "Not ACCESS training images.",
        "expected_layout": "workspace/datasets/kadid10k/",
    },
    {
        "id": "koniq10k",
        "name": "KonIQ-10k",
        "official_source": "https://database.mmsp-kn.de/koniq-10k-database.html",
        "paper": "Hosu et al. TIP 2020.",
        "download": "Already present locally for overall-MOS work. Do not reuse as criterion GT.",
        "n_images": 10073,
        "annotations": "Overall MOS and score counts c1-c5. Not Sharpness/Blur/Noise/…",
        "license": "Follow MMSP / DaRUS terms. Already used for overall MUSIQ/ENET overall comparisons.",
        "access_map": {c: "forbidden: overall MOS is not a criterion label" for c in ACCESS_CRITERIA},
        "overlap": "Used in this repo for overall MOS experiments. Not EfficientNet-head training data.",
        "expected_layout": "workspace/datasets/koniq10k/",
        "use_for_this_phase": False,
    },
    {
        "id": "livec",
        "name": "LIVE Challenge (LIVEC)",
        "official_source": "LIVE Challenge database (Ghadiyaram & Bovik).",
        "paper": "In-the-wild overall MOS.",
        "download": "Present locally for MUSIQ overall validation only.",
        "n_images": 1162,
        "annotations": "Overall MOS only.",
        "license": "LIVE research terms.",
        "access_map": {c: "forbidden: overall MOS is not a criterion label" for c in ACCESS_CRITERIA},
        "overlap": "Not EfficientNet training data. Used for official MUSIQ overall Spearman 0.770.",
        "expected_layout": "workspace/datasets/livec/",
        "use_for_this_phase": False,
    },
]


def _layout_present(entry: dict[str, Any]) -> dict[str, Any]:
    root = DATASETS_ROOT / entry["id"]
    images = None
    labels = None
    if root.is_dir():
        img_dir = root / "images"
        meta = root / "metadata"
        n_img = 0
        if img_dir.is_dir():
            n_img = sum(1 for p in img_dir.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".bmp"})
        images = {"dir": str(img_dir), "n": n_img, "exists": img_dir.is_dir()}
        label_files = []
        search = [root, meta] if meta.is_dir() else [root]
        for folder in search:
            if not folder.is_dir():
                continue
            for p in folder.iterdir():
                if p.is_file() and p.suffix.lower() in {".csv", ".xlsx", ".xls", ".json", ".mat"}:
                    label_files.append(p.name)
        labels = {"dir": str(meta if meta.is_dir() else root), "files": label_files}
    return {
        "root": str(root),
        "root_exists": root.is_dir(),
        "images": images,
        "labels": labels,
        "runnable": bool(
            images and images.get("n", 0) > 0 and labels and labels.get("files")
        ),
    }


def discover() -> dict[str, Any]:
    found: list[dict[str, Any]] = []
    missing: list[dict[str, Any]] = []
    for entry in CATALOG:
        loc = _layout_present(entry)
        rec = {"id": entry["id"], "name": entry["name"], **loc, "use_for_this_phase": entry.get("use_for_this_phase", True)}
        if loc["runnable"] and rec["use_for_this_phase"]:
            found.append(rec)
        else:
            missing.append(rec)
    return {
        "runnable_attribute_or_typed_sets": found,
        "not_runnable_or_forbidden": missing,
        "note": "Runnable requires local images plus a score table. KonIQ/LIVEC are present but forbidden as criterion GT.",
    }
