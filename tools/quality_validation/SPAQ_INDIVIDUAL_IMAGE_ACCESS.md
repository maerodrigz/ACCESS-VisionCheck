# SPAQ individual image access investigation

**Status:** investigation only. No SPAQ archive, ZIP volume, Kaggle dump, or cloud VM was started. No file larger than 500 MB was downloaded. Production scoring, APIs, XP, Flutter, and React Admin were not changed. No images or ratings were invented.

**Date:** 2026-11-07.

**Question:** Can ACCESS obtain **100–200 original SPAQ photographs** whose filenames match `spaq_mos_stratified_200.csv` and the local MOS spreadsheet, **without** storing the full ~34.8 GB dataset on C: (~18.1 GB free, no second disk)?

**Answer:** **No public HTTP, Hugging Face, GitHub, or Kaggle source currently exposes verified original SPAQ JPEGs by image ID.** The only historically documented per-file layout is the authors’ Baidu Yun share (not independently fetchable from this machine). Cloud extraction of the 200 IDs is technically possible, but it still **transfers the entire 34.8 GB archive** onto a remote disk. That was not started.

---

## 1. Local ground truth (already on disk)

| Asset | Path | Role |
|-------|------|------|
| MOS + attributes | `workspace/datasets/spaq/MOS and Image attribute scores.xlsx` (576,801 B) | 11,125 rows: `00001.jpg` … `11125.jpg` |
| Selected IDs | `workspace/datasets/spaq/spaq_mos_stratified_200.csv` | 200 IDs, 40 per MOS quintile, seed `20261107`, `image_on_disk=False` |
| Mapping | `workspace/datasets/spaq/import_mapping.spaq.json` | Header map only |

Spreadsheet columns: `Image name`, `MOS`, `Brightness`, `Colorfulness`, `Contrast`, `Noisiness`, `Sharpness`. MOS 2.0–96.0 (mean 50.32).

First selected IDs include `06664.jpg`, `02949.jpg`, `07312.jpg`. None of the selected 200 names are `00914.jpg` or `05293.jpg` (the only photo-like files on the official GitHub).

**Match rule used below:** a candidate photograph is “genuine SPAQ original” only if (a) the filename is exactly `NNNNN.jpg` from the spreadsheet / 200-ID list, and (b) the bytes come from an author-pointed or author-packaged SPAQ image tree, not a similarly named file from another dataset. PNG demos, scene-filtered subsets without a listing, and undersized dumps fail this rule.

Estimated payload if 200 originals were obtained: compressed SPAQ is 34.8 GB / 11,125 ≈ **3.1 MB per image**, so 200 files ≈ **0.6–1.0 GB**. That **would** fit on C:. The blocker is access, not the 200-file size.

---

## 2. Hugging Face repositories checked

Hub dataset search `SPAQ` returned **`[]`**. SPAQ pixels are not published as a named streaming dataset. They appear only as **blob archives** inside IQA collections, plus one **metadata-only** tree, plus one **gated** scene subset.

### 2.1 `chaofengc/IQA-PyTorch-Datasets` (`spaq.tgz`)

| Item | Value |
|------|--------|
| File | `spaq.tgz` only (no JPEG siblings, no Parquet) |
| Size | 34,841,101,349 bytes (~34.8 GB) |
| SHA256 | `54e0cb49dc8359f9293e746d452d8b12ec653056c9b12a4f97798a984c7418f7` |
| Hub license tag | collection card `cc-by-sa-4.0` (does **not** replace SPAQ author terms) |
| Access | public, not gated |
| Author pointer | [h4nwei/SPAQ#38](https://github.com/h4nwei/SPAQ/issues/38) (2026-03): Google Drive dead; use this tgz |

Format is **one gzip tar**. Gzip is a single stream. Xet chunking does not expose tar members as Hub files. There is no `resolve/main/00001.jpg` URL.

**Verdict:** genuine SPAQ packaging (author-endorsed mirror). **Not** individual-image access. Full download exceeds C: free space.

### 2.2 `AaronCIH/IQA_dataset` (`SPAQ/`)

Hub tree (`recursive=1`) contains **no JPEGs and no Parquet**:

| Path | Size |
|------|------|
| `SPAQ.z01` … `SPAQ.z06` | 5,368,709,120 bytes each (exactly 5 GiB) |
| `SPAQ.zip` | 2,627,971,439 bytes |
| `Annotations-20250710T143903Z-1-001.zip` | 2,102,537 bytes |
| `Readme.txt` | 1,516 bytes (author research/educational notice) |

Concatenated payload ≈ 34.84 GB. This is a **spanned PKZIP**. Volumes are not independent image shards. Dataset viewer generation fails. `Readme.txt` tells Linux users to `zip -FF SPAQ.zip` then unzip, which needs **all seven files**.

**Verdict:** same original database, unusable for per-ID HTTP GET. Do not download any 5 GiB volume without approval.

### 2.3 `zhiyuanyou/Data-DeQA-Score` (`SPAQ/`)

Tree is **metas only**:

- `SPAQ/metas/mos.json` (885 KB)
- `SPAQ/metas/split.json` (234 KB)
- `SPAQ/metas/test_spaq_2k.json` (514 KB)
- `SPAQ/metas/train_spaq_9k.json` (8.2 MB)

`test_spaq_2k.json` records (fetched, under 500 MB) use keys such as `"image": "SPAQ/images/00001.jpg"` and `"gt_score": 48.86`. That **agrees** with local spreadsheet row `00001.jpg` / MOS 48.86. It **does not** ship pixels. The dataset card tells users to download SPAQ images themselves.

**Verdict:** ID/MOS format confirmed. Zero photographs.

### 2.4 `dfgfhdhhhghg/spaq-cityscape-indoor-scene`

Earlier public card text claimed unmodified SPAQ copies filtered to Cityscape **or** Indoor, ~16.8 GB. **Now:** Hub dataset page and API both return **401 Unauthorized**. File tree cannot be listed. Even if it re-opens as individual JPEGs, a **scene filter cannot cover** a MOS-stratified 200 drawn from all 11,125 IDs unless a listing proves every selected filename is present.

**Verdict:** not accessible; not treated as a verified match source.

### 2.5 Other Hub hits

| Repo | What it is | SPAQ originals? |
|------|------------|-----------------|
| `VQA-CityU/smooth_compare-koniq-spaq-kadid` (and `-full`) | model weights | No images |
| Hub `datasets?search=SPAQ` | empty | n/a |

No Parquet image dataset (`datasets` Arrow/Parquet with embedded JPEGs) was found for SPAQ.

---

## 3. Official GitHub `h4nwei/SPAQ`

[`/images`](https://github.com/h4nwei/SPAQ/tree/master/images) (GitHub Contents API):

| File | Bytes | Notes |
|------|-------|--------|
| `00914.png` | 550,443 | Demo for BL models |
| `05293.png` | 471,343 | Demo |
| `icon_pdf.png` / `icon_zip.png` | tiny | UI icons |

These are **PNG**, not `NNNNN.jpg`. Neither name is in `spaq_mos_stratified_200.csv`. They are not a 200-image original set and must not be substituted for the selected IDs.

README still lists **Baidu Yun (code `b29m`)** and **Google Drive**. Issue #38: Drive “cannot be accessed”; author redirected to the 34.8 GB Hugging Face tgz. Issue #8 (2020): Baidu originally held **individual image files**; authors later posted a Baidu zip (`pan.baidu.com/s/1JzwZxwSOpIqcc16cOliBVw`, code `8og5`). 2023: authors stated there is **no client-independent URL**.

**Verdict:** GitHub is not an image host for the 11,125 JPEGs.

---

## 4. Kaggle `anamikakumari22/spaq-dataset`

| Item | Value |
|------|--------|
| Version | 2 |
| Advertised size | **190.55 MB** |
| License on card | Unknown |
| Usability | 1.76 |
| Description | none |
| Data Explorer (fetched) | “This directory is empty” under `SPAQ_Dataset` |

If this dump really contained 11,125 photographs, mean size would be ~17 KB/file. Original SPAQ smartphone JPEGs average ~3 MB compressed in `spaq.tgz`. **Size alone rules out originals.** Similar filenames, if any, are **not** accepted as verified matches. The dump was **not** downloaded (under 500 MB, but useless as originals and would not prove identity).

---

## 5. Other hosts

| Host | Finding |
|------|---------|
| Zenodo / Academic Torrents | No SPAQ 11,125-image deposit located in this search |
| ModelScope / OpenDataLab | No confirmed SPAQ JPEG tree; generic platform docs only |
| Google Drive (official) | Broken as of 2026-01 / 2026-03 (issue #38) |
| Baidu Yun (official, code `b29m`) | Only remaining **documented** individual-file layout (2020). Requires Baidu account; no HTTP API from this environment. Live listing **not verified** here. A later Baidu **zip** is a full archive, not per-ID HTTP. |

---

## 6. Are any available bytes genuine SPAQ originals for the 200 IDs?

| Source | Bytes available without >500 MB download | Match to 200 IDs |
|--------|------------------------------------------|------------------|
| Local xlsx | labels only | IDs/MOS yes, pixels no |
| DeQA JSON | labels / paths | `00001.jpg` MOS 48.86 agrees; no pixels |
| GitHub PNGs | 2 demos | Wrong format; not in the 200 list |
| HF tgz / spanned ZIP | none fetched | Would be genuine **if** fully extracted; not individually addressable |
| Kaggle 190.55 MB | not fetched | **Cannot** be the original 11,125 photos |
| Scene-subset HF | 401 | Unlisted; scene-filtered; unverified |

**No verified original JPEG for any of the 200 selected IDs is on this disk or fetchable as a small independent object.**

---

## 7. Cloud extraction (not started)

Goal of a remote job: download `spaq.tgz` **on the VM**, stream-extract only the 200 names from `spaq_mos_stratified_200.csv`, copy a ~0.6–1.0 GB zip to Drive / notebook output, then (optionally) download that zip to C:.

| Environment | Typical free disk | Fits 34.8 GB + 1 GB extract? | Direct $ cost | Persistence / risk |
|-------------|-------------------|------------------------------|---------------|--------------------|
| Google Colab (free CPU) | ~80–110 GB ephemeral `/content` | Yes, if `df` shows ≥40 GB free | $0; GPU unused | 12 h cap, idle disconnect; Drive 15 GB free is enough for the 200-file zip, **not** the tgz |
| Kaggle Notebook | often ~73 GB | Borderline-yes | $0 | Session limits; output quotas usually allow a <1 GB zip |
| Hugging Face Spaces | small unless paid persistent disk | Unpaid: no | paid disk if used | Overkill |
| GCP/AWS trial VM | operator-sized | Yes if disk ≥50 GB | trial then ~few USD + egress | Most reliable; not free after trial |

**Important:** gzip tar is not randomly seekable. The VM must **read the entire 34.8 GB stream** even if it writes only 200 files. That is a full archive transfer, not “download 200 JPEGs.” Local equivalent (`curl \| tar -xz --files-from=list`) would keep C: usage ~1 GB but still pulls 34.8 GB over the network. That was **not** run (user: do not download the full archive).

**License / ToS:** SPAQ author notice (copied in AaronCIH `Readme.txt`): educational and research use only; not as the basis of a commercial product without permission. Colab/Kaggle use for ACCESS research is consistent with that notice if the 200 files stay in the research toolkit and are not shipped in the product. Hub collection `cc-by-sa-4.0` does not widen SPAQ rights. Baidu/Drive require their own accounts. No extra pixel license fee was found; cost is compute/storage/time.

**Permissions:** `chaofengc` tgz is public (no HF token required for download). The 401 scene repo is not. Kaggle needs a Kaggle login even for small dumps.

---

## 8. Ranked options

Rank is **reliability of getting the exact 200 originals**, then **cost**, then **C: storage**.

| Rank | Option | Reliability | Cost | C: storage | Do now? |
|------|--------|-------------|------|------------|---------|
| 1 | Official Baidu Yun **individual** files (code `b29m`), download only the 200 `NNNNN.jpg` names, then SHA/filename check against the spreadsheet | **Unknown until a human opens the share.** Historically the only per-file official layout. | $0 + Baidu account | ~0.6–1.0 GB | User login only. Not automatable here. |
| 2 | **Approved** Colab or Kaggle job: stream `spaq.tgz`, extract the 200 names, copy zip to Drive/output, then to C: | Medium (timeout / disk variance). Author-endorsed bytes if SHA256 of tgz matches. | $0 if it finishes | ~0.6–1.0 GB after transfer | **Not started.** Needs explicit approval (full 34.8 GB network transfer). |
| 3 | Paid VM (≥50 GB disk), same extract | High | USD for VM + egress | ~0.6–1.0 GB | Not started. |
| 4 | Local `curl \| tar` extract of 200 members | High if the pipe completes | $0 bandwidth/time | ~1 GB written, 34.8 GB transferred | **Forbidden** under current download cap. |
| 5 | Download HF spanned ZIP or full tgz onto C: | N/A | $0 | **Does not fit** 18.1 GB | No |
| 6 | Kaggle 190.55 MB or GitHub PNGs | High that they are **not** the 200 originals | $0 | small | **Reject** as SPAQ originals |
| 7 | Gated scene-subset repo | Inaccessible (401) | n/a | n/a | No |

**There is no Rank-0 option:** no Hub/Kaggle/GitHub URL returns `06664.jpg` (or any other selected ID) as an original JPEG under 500 MB.

---

## 9. Limitation (explicit)

Under the constraints of this investigation (no full archive, no file >500 MB, no cloud deployment, C: ~18.1 GB free):

1. **No workable public source of individual original SPAQ JPEGs matching the 200 IDs exists** in the repositories that can be listed without authentication.
2. Labels for those IDs **do** exist locally and are internally consistent with DeQA metadata for overlapping names (example: `00001.jpg` MOS 48.86).
3. Unblocking pixels requires **one** of: (a) a successful Baidu per-file download of the 200 names, (b) user approval to run a **full 34.8 GB** transfer on a cloud VM or via a local stream extract, or (c) more free disk so the full archive can land on C:.
4. Until then, SPAQ criterion validation against human attribute scores **cannot run**. Do not substitute KonIQ MOS, GitHub PNGs, Kaggle undersized files, or synthetic images.

---

## 10. What was not done (by request)

- No `spaq.tgz`, ZIP volume, or Kaggle zip download.
- No Colab / Kaggle / GCP / Spaces deployment.
- No production code edits.
- No fabricated photographs or ratings.
