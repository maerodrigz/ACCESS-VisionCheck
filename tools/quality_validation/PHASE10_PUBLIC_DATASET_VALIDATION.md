# ACCESS VisionCheck Phase 10 alternative: public criterion-label validation

**Status:** research complete for what is locally available. Production scoring, APIs, database, Flutter, React Admin, XP, recommendations, PROBE, WaveRep, Gemini, and MUSIQ were not modified. The 30-photo human pilot pack was not overwritten. No reference ratings were fabricated. No AI-generated labels were used.

**Date:** 2026-11-07.  
**Discovery run:** `workspace/datasets/public_attribute_validation/output/run_001/` (`summary.json`, `dataset_discovery.json`, `dataset_catalog.json`).  
**Scripts:** `public_dataset_catalog.py`, `run_public_attribute_validation.py` (reuses Phase 9 `scoring_candidates.py`).  
**Seed:** `20261107` (reserved for bootstrap and any future SPAQ subset; no mapping was fitted).

Headline: **no public dataset with independent criterion-specific human labels is installed on this machine**, so there are **no new Spearman/Pearson tables vs human attributes**. SPAQ is the right next download. KonIQ and LIVEC are present and were **not** used as Sharpness/Blur/Noise/… ground truth.

---

## 1. What was reviewed

| Document / artifact | Used as |
|---------------------|---------|
| `TECHNICAL_QUALITY_CRITERIA_AUDIT.md` | Construct definitions and known instrument failures |
| `CONTROLLED_DISTORTION_RESULTS.md` | Knob sensitivity only (370 files) |
| `TECHNICAL_SCORING_CANDIDATES.md` | Phase 9 maps: `_soft_score`, equal-bin, linear-continuous; ENET / OpenCV / classical |
| `HUMAN_VALIDATION_PROTOCOL.md`, `HUMAN_RATING_RUBRIC.md`, `PHASE10_SINGLE_RATER_GUIDE.md` | Human protocol exists; this phase avoids developer rating |
| `comparisons.py`, `importers/spaq.py`, `scale_mapping.py` | Existing SPAQ pairing and noisiness invert |
| Phase 8/9 CSVs | Not re-labeled as human accuracy |

Phase 9 candidates reused (not replaced): EfficientNet raw heads with explicit invert of defect amounts; OpenCV; classical Laplacian, Immerkaer, exposure×clip, RMS×clip, 8×8 boundary ratio, edge-Laplacian; maps `baseline_soft_int`, `equal_bin_int`, `linear_round_int`, `linear_continuous`.

---

## 2. Dataset research (sources, labels, license, coverage)

### 2.1 SPAQ (priority)

| | |
|--|--|
| **Official** | [h4nwei/SPAQ](https://github.com/h4nwei/SPAQ). Paper: Fang et al., CVPR 2020. |
| **Download** | Google Drive / Baidu Yun (code `b29m`) from the README. The git repo has demo code and weights, **not** the 11,125 images or MOS/attribute spreadsheet. |
| **n** | 11,125 smartphone photos (66 devices). |
| **Annotations** | Overall MOS 0–100; attributes brightness, colorfulness, contrast, noisiness, sharpness 0–100 (lab study); scene labels; EXIF. |
| **License** | Use here is **offline research evaluation only**. Do not ship SPAQ-trained weights in ACCESS. Do not train production EfficientNet heads on SPAQ in this phase. |
| **Local status** | **Blocked.** `workspace/datasets/spaq` does not exist. `run_spaq` reason: `SPAQ score table not found`. |
| **Training overlap** | ACCESS EfficientNet = `SyntheticIQADataset` only. PaQ-2-PiQ MUSIQ is not SPAQ-trained. A separate SPAQ MUSIQ/MT-A checkpoint exists; it was **not** run (would mix a SPAQ-trained model into SPAQ evaluation). |

Supplementary text (Fang et al.): low brightness = poorly exposed; high noisiness = much sensor noise; sharpness is **inversely proportional to blur level**; reduced contrast gets a low contrast score.

### 2.2 Other attribute-like sets

| Dataset | Official | n | Human labels | ACCESS use | Local |
|---------|----------|--:|--------------|------------|-------|
| CID2013 | [Zenodo 2647032](https://doi.org/10.5281/zenodo.2647032) | 480 | MOS + sharpness, graininess, lightness, saturation | Sharpness/Noise/Brightness **proxies** if scales are confirmed | Missing |
| BID | Author host (authentic blur) | varies | Usually one blur MOS | Blur proxy only; not Sharpness | Missing |
| LIVE IQA R2 | [LIVE IQA](https://www.colorado.edu/lab/live/live-image-quality-assessment-database) | 779 | **DMOS** + distortion type (JPEG, JP2K, GBlur, WN, FF) | Typed **overall** MOS, not 7 attributes. Research license, cite Sheikh/Bovik | Missing |
| CSIQ | Chandler lab | 866 | DMOS + type | Same limitation | Missing |
| TID2013 | [Qualinet / Ponomarenko](https://qualinet.github.io/databases/image/tampere_image_database_tid2013/) | 3000 | MOS × 24 types | Same limitation. Scientific use | Missing |
| KADID-10k | [MMSP Konstanz](https://database.mmsp-kn.de/kadid-10k-database.html) | 10125 | Crowdsourced DCR MOS × 25 types | Same limitation. Pristine Pixabay; follow MMSP terms | Missing |

LIVE/TID/CSIQ/KADID MOS on a JPEG image is **not** a Blocking 1–5 badge. It is overall quality of a synthetically compressed picture (blocking + blur + ringing mixed). Subset ranking is at most **partial**.

### 2.3 Present locally but forbidden as criterion GT

| Dataset | What is on disk | Why not used here |
|---------|-----------------|-------------------|
| KonIQ-10k | 40 JPEGs in `koniq10k/images/` plus score table; Run 002 100-image set | **Overall MOS only.** `c1`–`c5` are MOS bin counts, not ACCESS raters. |
| LIVEC | Prior official MUSIQ run (overall Pearson 0.805 / Spearman 0.770, n=1,162) | **Overall MOS only.** |
| Phase 8 ladders | 370 controlled files | Distortion **knobs**, not human criterion ratings. |
| 30-photo pilot | `workspace/human_pilot/` | Preserved. Empty DEV sheet. Not filled. Not overwritten. |

---

## 3. Criterion-to-label mapping

Only maps whose published definition matches the ACCESS rubric closely enough to compare. Higher ACCESS display = better.

| ACCESS criterion | Independent human reference | Comparability | Notes |
|------------------|-----------------------------|---------------|-------|
| Sharpness | SPAQ sharpness 0–100; CID sharpness if obtained | **related_proxy** | SPAQ sharpness **includes blur**. Do not treat as ACCESS Sharpness≠Blur. |
| Blur | SPAQ: **none**. BID/CID blur MOS or LIVE/KADID Gaussian/motion **subset MOS** | SPAQ: **NOT HUMAN-VALIDATED**. Others: **partial** | OpenCV Blur = 1 − Sharpness. SPAQ does not split the constructs. |
| Noise | SPAQ noisiness inverted (`100 − noisiness` → 1–5 quality) | **directly_comparable after invert** (when SPAQ is present) | CID graininess is a proxy after polarity check. |
| Brightness | SPAQ brightness (low = poorly exposed) | **related_proxy** | Does not separately code over- vs underexposure the way ACCESS coaching needs. |
| Contrast | SPAQ contrast (low = reduced contrast) | **related_proxy** | No published harsh-clip penalty. Phase 9 classical RMS×clip is a different construct. |
| Blocking Artifacts | No attribute dataset. LIVE/TID/KADID **JPEG subset MOS** | **NOT HUMAN-VALIDATED** as a Blocking score; **partial** typed MOS only | |
| Ringing Artifacts | No attribute dataset. JP2K subset MOS | **NOT HUMAN-VALIDATED** as a halo score; **partial** typed MOS only | Phone unsharp ≠ JPEG2000 ringing. |
| Colorfulness | SPAQ colorfulness | **not an ACCESS criterion** | Listed so it is not silently copied into Contrast. |
| Overall MOS | SPAQ/KonIQ/LIVEC MOS | **not a criterion** | Already studied for MUSIQ overall. Not repeated as Sharpness/Noise/… |

Sharpness and Blur are **not** interchangeable. SPAQ’s own definition ties sharpness to blur level. ACCESS rubric allows in-focus but mushy texture (high Blur quality, lower Sharpness). That pair cannot be validated from SPAQ.

MAE policy (when SPAQ later runs): MAE only for **Noise** human 1–5 (after invert) vs integer maps (`_soft_score`, equal-bin, linear-round). No MAE vs continuous `1+4q` or raw 0–1. No MAE for Sharpness/Brightness/Contrast (scale and construct mismatch). No MAE vs KonIQ MOS.

---

## 4. Pipeline (reproducible, no overwrite)

Place SPAQ yourself (this repo does not download it):

```
tools/quality_validation/workspace/datasets/spaq/
  images/          # official JPEGs
  metadata/
    MOS_and_attributes.csv   # or .xlsx
    import_mapping.spaq.json # copy templates/import_mapping.spaq.example.json and fill real headers
```

Then:

```powershell
cd C:\Users\Dell\Desktop\access_mobile
$env:PYTHONPATH = "access_backend;."
python tools/quality_validation/run_public_attribute_validation.py
python tools/quality_validation/run_public_attribute_validation.py --infer
```

Discovery-only (this session) does **not** call EfficientNet. `--infer` scores Phase 9 candidates on matched files, writes `spaq_candidate_scores.csv` and bootstrap Spearman CIs (seed `20261107`). Output stays under `workspace/datasets/public_attribute_validation/`. It refuses to write into `workspace/human_pilot/`.

---

## 5. Actual experimental results (this machine)

**Runnable attribute or typed sets: 0.**  
**SPAQ status: blocked** (`SPAQ score table not found`).  
**Candidate vs human-attribute Spearman: not computed (n=0).**  
**Pearson: not computed.**  
**MAE: not reported.**  
**Missing data:** entire SPAQ, CID2013, BID, LIVE IQA, CSIQ, TID2013, KADID-10k image+label trees.

KonIQ (40 local JPEGs + score table) and LIVEC (prior overall run) were inspected and **excluded** from criterion tables.

No comparison table of ENET vs OpenCV vs classical vs continuous maps vs **human attributes** can be filled without inventing numbers. That table is deferred until SPAQ (or CID2013) is on disk.

### 5.1 What is already known, and what it is not

Phase 8/9 **knob** results remain the only numerical candidate comparison. They are **controlled-distortion-tested only**.

| Family | Human criterion? | ENET `_soft_score` | ENET continuous | Classical equal-bin |
|--------|------------------|-------------------:|----------------:|--------------------:|
| Gaussian blur | No | undefined (n=0) | −0.943 | −0.845 |
| AWGN | No | −0.655 (n=2) | −0.829 | −0.941 |
| Underexposure | No | 0.00 | −0.10 | −0.975 |
| Overexposure | No | +0.35 | +0.40 | −0.894 |
| High contrast | No | undefined | +0.10 | −0.866 (clip penalty) |
| JPEG | No | −0.655 (n=2) | −0.086 | −0.971 (8×8 boundary) |
| Ringing | No | undefined | −0.60 | −0.828 |

Do **not** pick a production winner from this table. Classical JPEG and Immerkaer **track knobs**; that is not ACCESS perceptual accuracy.

---

## 6. Evidence class per ACCESS criterion

| Criterion | Class | Why |
|-----------|-------|-----|
| Sharpness | **Controlled-distortion-tested only** | SPAQ sharpness would be a related proxy; dataset missing. Laplacian tracks Gaussian σ. Grain raises Laplacian. |
| Blur | **Not independently human-validated** | No public attribute that matches ACCESS motion/defocus vs texture. OpenCV Blur is Sharpness inverted. |
| Noise | **Controlled-distortion-tested only**; **ready for independent validation** once SPAQ is installed | Closest public match (inverted noisiness). Not computed here. |
| Brightness | **Controlled-distortion-tested only** | SPAQ brightness is a related proxy (poor exposure), missing locally. ENET EV ladders fail; classical triangle×clip follows knobs. |
| Contrast | **Controlled-distortion-tested only** | SPAQ contrast is a related proxy without clip penalty. Missing locally. |
| Blocking Artifacts | **Not independently human-validated** | No blocking attribute. JPEG-subset MOS would be partial and is not on disk. |
| Ringing Artifacts | **Not independently human-validated** | No halo attribute. JP2K MOS would be a different artifact. |

Nothing in this phase is **independently human-validated**. Noise is the only criterion with a **clear public path** (SPAQ noisiness invert) that was not blocked by construct mismatch.

Limitations: smartphone SPAQ domain ≠ ACCESS club documentation; SPAQ sharpness≡blur; brightness/contrast definitions differ; synthetic IQA MOS mixes artifacts; ACCESS EfficientNet 224×224 vs SPAQ native resolution; developer never rated the 30-photo pack in this alternative.

---

## 7. Recommendations for the next phase

1. **Install SPAQ locally** (official Drive/Baidu), fill `import_mapping.spaq.json` with real Excel headers, run `run_public_attribute_validation.py --infer`. Report Noise first (invert + Spearman CI). Treat Sharpness/Brightness/Contrast as proxies. Leave Blur/Blocking/Ringing unmarked.
2. **Do not** use KonIQ MOS, LIVEC MOS, or MUSIQ as criterion evidence.
3. **Do not** use SPAQ-trained MT-A / SPAQ MUSIQ as the ACCESS candidate (train/test leak).
4. Optional second set: CID2013 graininess/sharpness after polarity check; LIVE/KADID JPEG **subset** only as a blocking **stress test**, labeled partial.
5. ACCESS human ratings remain required for Blur vs Sharpness, Blocking, Ringing, and any production change.
6. Do not retrain on SPAQ or on the 30-photo pack in the same step that evaluates them.

---

## 8. Files

| Path | Role |
|------|------|
| `tools/quality_validation/PHASE10_PUBLIC_DATASET_VALIDATION.md` | This report |
| `tools/quality_validation/public_dataset_catalog.py` | Sources, maps, licenses |
| `tools/quality_validation/run_public_attribute_validation.py` | Discovery + optional SPAQ scoring |
| `tools/quality_validation/tests/test_public_attribute_validation.py` | Invert, bootstrap, KonIQ exclusion |
| `workspace/datasets/public_attribute_validation/output/run_001/` | Actual discovery JSON |

Production unchanged. Pilot pack unchanged. Stopped for review.
