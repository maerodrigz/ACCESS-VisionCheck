# SPAQ low-storage access plan

**Status:** investigation only. No archive, ZIP part, or image was downloaded. Production scoring, APIs, XP, Flutter, and React Admin were not changed. No ratings were fabricated. No replacement images were generated.

**Date:** 2026-11-07.  
**Constraint:** C: has about **18.1 GB** free. No second disk. Full SPAQ compressed payload is about **34.8 GB**.

---

## 1. Local annotation spreadsheet (verified)

File: `tools/quality_validation/workspace/datasets/spaq/MOS and Image attribute scores.xlsx` (576,801 bytes).

| Item | Value |
|------|--------|
| Sheet | `Sheet1` only |
| Rows | 1 header + **11,125** data rows |
| Filenames | `00001.jpg` … `11125.jpg` (11,125 unique) |
| MOS | min **2.0**, max **96.0**, mean **50.32**, median **50.2** (0–100 scale) |
| Empty attribute cells | none in the seven columns |

Exact headers (row 1):

| Column | Header |
|--------|--------|
| A | `Image name` |
| B | `MOS` |
| C | `Brightness` |
| D | `Colorfulness` |
| E | `Contrast` |
| F | `Noisiness` |
| G | `Sharpness` |

Sample row `00001.jpg`: MOS 48.86, Brightness 47.43, Colorfulness 55.57, Contrast 55.71, Noisiness 37.86, Sharpness 42.57.

Polarity (Fang et al. supplementary, unchanged): **Noisiness high = more noise** (invert for ACCESS Noise). **Sharpness is inversely proportional to blur** (no separate Blur label). Low Brightness = poorly exposed. Low Contrast = reduced contrast. Colorfulness is not an ACCESS criterion. MOS is overall-only.

Mapping JSON (headers filled, still no images): `templates/import_mapping.spaq.example.json` and `workspace/datasets/spaq/import_mapping.spaq.json`.

---

## 2. Hugging Face SPAQ: can we pull individual originals?

Two community mirrors exist. Neither is a Hugging Face **streaming image dataset** (no per-row Parquet of JPEGs). The dataset viewer for `AaronCIH/IQA_dataset` **fails** (`DatasetGenerationError`). There is no supported API that returns `00001.jpg` by ID.

### 2.1 `chaofengc/IQA-PyTorch-Datasets` `spaq.tgz`

- Size: **34,841,101,349 bytes** (~32.45 GiB / 34.8 GB).
- SHA256: `54e0cb49dc8359f9293e746d452d8b12ec653056c9b12a4f97798a984c7418f7`.
- Author of SPAQ pointed here after Google Drive broke ([h4nwei/SPAQ#38](https://github.com/h4nwei/SPAQ/issues/38)).
- Format: **one gzip-compressed tar**. Gzip is a single stream. You cannot seek to `00001.jpg` without decompressing from the start. Xet chunking does not make tar members independently fetchable through the Hub UI.
- **Verdict:** not usable for remote per-image extraction. Downloading it would need ~35 GB plus extract headroom, more than 18.1 GB free.

### 2.2 `AaronCIH/IQA_dataset` `SPAQ/` (split ZIP)

This is the “split ZIP” layout:

| File | Size |
|------|------|
| `SPAQ.z01` … `SPAQ.z06` | **5,368,709,120 bytes each** (exactly 5 GiB × 6) |
| `SPAQ.zip` | **2,627,971,439 bytes** (~2.45 GiB), last volume |
| `Annotations-20250710T143903Z-1-001.zip` | 2.1 MB (redundant; local xlsx already present) |
| Concatenated | **34,840,226,159 bytes** (~34.8 GB) |

This is a **spanned PKZIP**, not six independent ZIP files of images. The central directory lives in the last volume. A JPEG can straddle two 5 GiB parts. Standard unzip needs **all seven files** sitting together.

| Idea | Feasible on 18.1 GB? | Why |
|------|----------------------|-----|
| Unzip one part only | No | Not a complete ZIP. |
| HTTP Range of one JPEG from the Hub | Not reliable | No file index without the last volume; Xet/LFS range semantics are not a ZIP random-access API; Hub viewer is broken. |
| Download last `SPAQ.zip` (2.45 GB) only to read the central directory, then Range-get members | Speculative, fragile | Still a large download. Offsets are across concatenated volumes. A selected MOS-stratified ID is unlikely to sit only in z01. Could waste 2–7 GB on a failed experiment. **Do not try without explicit approval.** |
| `zip -FF` / Windows unzip of parts | Needs all ~34.8 GB | Exceeds free space. |

**Verdict:** individual original SPAQ JPEGs **cannot** be retrieved legitimately and reliably from these Hub archives without downloading essentially the full payload. Stop. Do not start a 34.8 GB or 5 GiB part download.

License on the community `Readme.txt` is the authors’ original notice: **educational and research purposes only**, not as the basis of a commercial product without permission. Community hosting is a convenience mirror, not a new license.

---

## 3. Label-only subset (no images yet)

Because remote JPEG fetch is not feasible, images were **not** selected onto disk. A **reproducible ID list** was written from the spreadsheet only:

`workspace/datasets/spaq/spaq_mos_stratified_200.csv`

| Rule | Value |
|------|--------|
| Seed | `20261107` |
| n | 200 = 40 per MOS quintile |
| Cuts (empirical MOS) | 2.00 / 29.43 / 42.25 / 58.86 / 71.82 / 96.00 |
| Hash | `sha256(f"{seed}\0{filename}")` via existing `deterministic_subset` |
| Columns | `media_id`, `source_media_key`, MOS + five attributes, stratum, `image_on_disk=False` |

This preserves official IDs and human attributes. It does **not** create pixels. Estimated size **if** those 200 JPEGs were later obtained: 34.8 GB / 11,125 ≈ **3.1 MB compressed each** → about **0.6–0.8 GB** for 200 files, plus a small CSV. That would fit **after** a legitimate per-file source exists. It does not justify downloading a 5 GiB ZIP part.

Do not treat this CSV as a scored validation set.

---

## 4. Smaller reputable sets with technical attributes

These are alternatives **if SPAQ images stay blocked**. Storage figures are Hub/Zenodo advertised sizes. Nothing below was downloaded.

| Dataset | Packed size | n | Human technical labels | Fit in 18.1 GB? | ACCESS use | Leakage |
|---------|------------:|--:|------------------------|-----------------|------------|---------|
| **CID2013** ([Zenodo 2647033](https://zenodo.org/records/2647033) `CID2013.7z`) | **608 MB** | 474 (480 evals) | MOS, **sharpness, graininess, lightness, color saturation** | Yes (~0.6–1.2 GB with extract) | Best **low-storage** attribute set. Graininess ≈ Noise after polarity check. Lightness ≠ ACCESS exposure triangle. No Blocking/Ringing. No Blur vs Sharpness split. | Not used to train ACCESS EfficientNet. |
| BID (`chaofengc` `BID.zip`) | 457 MB | authentic blur | Usually **one blur MOS** | Yes | Blur **proxy only**. Not Sharpness. | Not ACCESS training data. |
| CSIQ (`csiq.tgz`) | 379 MB | 866 | DMOS + distortion **type** | Yes | Typed overall MOS (JPEG/blur/noise/contrast). **Not** seven attributes. | Synthetic; ACCESS trainer used similar knobs, **not** CSIQ images. |
| LIVE IQA (`live.tgz`) | 721 MB | 779 | DMOS + type | Yes | Same limitation as CSIQ. Research license, cite LIVE. | Same. |
| LIVEC (`live_challenge.tgz`) | 326 MB | 1162 | Overall MOS only | Yes | **Forbidden** as criterion GT (already used for MUSIQ overall). | Overall track only. |
| TID2013 | 1.23 GB | 3000 | Typed MOS | Tight but possible | Same as CSIQ. | Not ACCESS images. |
| KADID-10k | 3.07 GB | 10125 | Typed MOS | Possible | Same. | Not ACCESS images. |

**CID2013 license (Zenodo / Helsinki notice):** research use with copyright notice and citation (Virtanen et al., TIP 2015). Individual images must not be used for marketing. Confirm the notice on download.

CSIQ/LIVE/TID/KADID remain **partial** (overall MOS of one synthetic distortion), not criterion badges.

---

## 5. Storage budget (do not download yet)

| Action | Disk need | vs 18.1 GB free |
|--------|-----------|-----------------|
| Full `spaq.tgz` or split ZIP | ~35 GB compressed, more to extract | **Does not fit** |
| One `SPAQ.z01` part | 5.0 GiB | Fits numerically, **useless alone** |
| Last `SPAQ.zip` + one part (fragile CD experiment) | ~7.5 GiB + extract | Fits only if nothing else grows; **high waste risk** |
| 200 SPAQ JPEGs, if individually available | ~0.6–0.8 GB | Fits |
| CID2013.7z | 608 MB + extract ≈ 1 GB | Fits |
| BID.zip | 457 MB | Fits |
| Labels + mapping + 200-ID CSV | already on disk (~1 MB) | Done |

Keep ≥5 GB free for Windows/temp. Do not start a Hub fetch that cannot finish.

---

## 6. Provenance, license, leakage

- Official SPAQ: Fang et al., CVPR 2020; authors’ research/educational notice. Hub copies are redistributions (`chaofengc` endorsed by h4nwei for the tgz; `AaronCIH` is community).
- ACCESS EfficientNet heads: `SyntheticIQADataset` only. **No SPAQ/CID2013/LIVE image training.**
- Do **not** evaluate SPAQ-trained MUSIQ/MT-A on SPAQ (train/test leak).
- Do **not** copy SPAQ MOS into Sharpness/Blur/Noise columns.
- Do **not** use KonIQ/LIVEC MOS as criterion GT.
- Community ZIP/tgz does not grant commercial product rights.

---

## 7. Feasible options (ranked)

1. **Do not download SPAQ archives** on this disk. Remote per-image access is not available.
2. **Preferred low-storage validation:** after review, download **CID2013.7z (608 MB)** from Zenodo. Map sharpness / graininess (invert if needed) / lightness as **proxies**. n=474 is enough for Spearman with CIs. Still not Blocking/Ringing/ACCESS Blur.
3. **Optional typed-MOS stress tests** (not attribute validation): CSIQ 379 MB or LIVE IQA 721 MB, JPEG/blur/noise **subsets only**, labeled partial.
4. **SPAQ later:** wait for a disk ≥80 GB (archive + extract + workspace) or a source that serves `00001.jpg` as a single HTTP object. Then fetch only the 200 IDs in `spaq_mos_stratified_200.csv`.
5. **Do not** unzip split volumes, generate fake photos, or treat Phase 8 knobs as human GT.

---

## 8. Exact next steps (after review)

Nothing in this list has been started.

1. Decide: **CID2013 (608 MB)** vs wait for SPAQ disk. Default recommendation: CID2013.
2. If CID2013: download only `CID2013.7z` from Zenodo 2647033 into `workspace/datasets/cid2013/`. Keep the 7z until extract is verified, then delete the archive if space is tight.
3. Confirm graininess polarity on the CID score sheet **before** correlating with ACCESS Noise.
4. Run Phase 9 candidates with `run_public_attribute_validation.py` extended for CID, or a dedicated CID script. Freeze seed `20261107`. No retraining.
5. If SPAQ disk appears later: download **neither** tgz nor all ZIP parts until a per-file path exists; then fetch the 200 listed IDs only.

Stopped for review. No large files were downloaded.
