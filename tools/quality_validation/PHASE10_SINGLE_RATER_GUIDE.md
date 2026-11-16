# ACCESS VisionCheck Phase 10: Single-rater guide

**Status:** preparation complete. No human scores have been collected.  
**Role:** one academic pilot rater (`DEV`). Results are **exploratory** and can be biased if the rater has seen EfficientNet outputs, Run 002 reports, or KonIQ MOS.

This is not the three-rater protocol in `HUMAN_VALIDATION_PROTOCOL.md`. Use that protocol later for IRR. Do not treat this session as production accuracy.

Production scoring, XP, APIs, Flutter, React Admin, PROBE, WaveRep, Gemini, and MUSIQ are unchanged.

---

## 1. What you will rate

Blind pack: `tools/quality_validation/workspace/human_pilot/rater_pack/`

| Item | Use |
|------|-----|
| `images/PILOT-001.jpg` … `PILOT-030.jpg` | Photographs only. Anonymous IDs. |
| `rating_sheet.html` | Preferred: one photo ID and seven empty 1–5 fields |
| `ratings_DEV.csv` | Same fields in a spreadsheet |
| `PHASE10_SINGLE_RATER_SHEET.csv` | Copy of the empty CSV at the toolkit root |
| `HUMAN_RATING_RUBRIC.md` | Full anchors |

Do **not** open `workspace/human_pilot/facilitator/` until the sheet is locked. That folder has original filenames, strata, and MOS.

KonIQ MOS is overall-only. It is never a Sharpness/Blur/Noise/… label.

---

## 2. How to score (1–5)

Higher is always better, including Blur and Noise. Integers only. Empty = not yet rated. `N/A` = cannot judge. Never use 3 as “not sure.”

| Score | Meaning |
|------:|---------|
| 1 | Unusable for club documentation on this criterion |
| 2 | Obvious defect; a retake would normally be required |
| 3 | Subject identifiable; defect clearly visible |
| 4 | Minor issues; suitable for ACCESS documentation |
| 5 | No meaningful defect at fit-to-window and at 100% crop |

**Viewing:** sRGB, no extra sharpening. Fit-to-window first for Brightness, Contrast, and overall. Then 100% (200% if needed) for Sharpness, Blur, Noise, Blocking, Ringing.

### The seven technical criteria (keep them separate)

1. **Sharpness.** Fine detail on the *subject* (hair, fabric, text). Not darkness, grain, or JPEG squares.
2. **Blur.** Freedom from motion smear or missed focus. Streaks or bokeh disks on the subject = low Blur score. Do not copy the Sharpness number here.
3. **Noise.** Freedom from grain or chroma splotch. Random speckle, not 8×8 tiles.
4. **Brightness.** Is the subject well exposed? Rate the face or main object, not a dramatic sky.
5. **Contrast.** Usable tone separation without harsh clip as the main look. Foggy or crushed = low.
6. **Blocking artifacts.** Visible compression squares in flat areas (sky, walls, skin). Inspect flats, not only edges.
7. **Ringing artifacts.** Halos or ghost ridges along strong edges. Not defocus, not blocky sky.

**Overall visual quality** is a separate gestalt of documentation usefulness. Do not force it to equal the mean of the seven.

Photos: **flickering** and **motion_stability** stay `N/A`.

---

## 3. Single-rater workflow

1. Close Run 002 reports, `per_image_results.csv`, Phase 8/9 CSVs, and the facilitator folder.
2. Open `rater_pack/rating_sheet.html` in a browser (File, Open). You should see `PILOT-001` first.
3. Rate **one criterion at a time** on that photo (recommended order: Brightness, Contrast, Sharpness, Blur, Noise, Blocking, Ringing, then overall).
4. Leave a field blank if you need to come back. Do not type 3 as a placeholder.
5. Click **Download ratings_DEV.csv** and replace `rater_pack/ratings_DEV.csv`, or type into the CSV directly.
6. Continue through `PILOT-002` … `PILOT-030`.
7. When finished, do not edit scores after you start analysis. That is the lock.

Target: about 2–4 minutes per photo.

---

## 4. How to begin the first photo

1. Open `tools/quality_validation/workspace/human_pilot/rater_pack/images/PILOT-001.jpg`.
2. Open `rating_sheet.html` or row `PILOT-001` in `ratings_DEV.csv`.
3. All seven technical cells and overall should still be **empty**.
4. Fit the photo to the window. Score Brightness, then Contrast.
5. Zoom to 100%. Score Sharpness, Blur, Noise, Blocking, Ringing.
6. Score overall last, without averaging the seven numbers on a calculator.
7. Save the row. Then go to `PILOT-002`.

---

## 5. After lock (do not run this until the sheet is filled)

```powershell
cd C:\Users\Dell\Desktop\access_mobile
$env:PYTHONPATH = "access_backend;."
python tools/quality_validation/analyze_phase10_single_rater.py `
  --i-have-locked-ratings `
  --infer-candidates
```

The analyzer **stops** if every technical cell is still empty. It does not invent scores.

| Metric | When |
|--------|------|
| Spearman (and Pearson) | Human vs production Run 002 integers; vs ENET/OpenCV/classical maps if `--infer-candidates` |
| MAE / RMSE | Only 1–5 integer vs 1–5 integer (production, equal-bin, linear-round) |
| MAE | **Not** reported vs continuous `1+4q`, raw 0–1 heads, or KonIQ MOS as a criterion |
| Distributions | Human 1–5 histograms per criterion |

Outputs go under `workspace/human_pilot/facilitator/analysis/` (private). Label: exploratory single rater, possible developer bias.

---

## 6. Safeguards

- Original Run 002 files were **copied**, not moved (`run_002/images/` still intact).
- Facilitator manifest stays private.
- Do not retrain or recalibrate on these 30 images.
- Synthetic Phase 8/9 knobs are not human criterion accuracy.
- A later three-rater pass is required before any production scoring change.

Stopped for rating. Begin with `PILOT-001`.
