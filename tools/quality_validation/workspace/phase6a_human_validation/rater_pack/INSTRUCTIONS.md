# Phase 6A blinded human evaluation — image quality

You are rating photographs for ACCESS VisionCheck independent validation
(holdout `INDVAL-001` … `INDVAL-100`). This set is disjoint from the 30-image pilot.

## Pack contents (rater-safe)

1. `images/INDVAL-001.jpg` … `INDVAL-100.jpg` — anonymous photos only.
2. `ratings_<YOUR_ID>.csv` — your rating sheet (R1, R2, or R3).
3. `HUMAN_RATING_RUBRIC.md` — 1–5 anchors (same wording as the pilot).
4. Optional: `rating_sheet.html` — open locally to rate in a browser, then download CSV.

## Scale (every criterion)

- **1 = poorest quality**
- **5 = best quality**
- Higher is always better, including **Blur** and **Noise**.
- Integers **1, 2, 3, 4, or 5** only. No halves.
- If you cannot judge a criterion, write `N/A`. Never guess. Never use 3 for unknown.

## Criteria to rate

Sharpness, Blur, Noise, Brightness, Contrast, Blocking artifacts, Ringing artifacts,
and Overall visual quality (independent gestalt; do not force it to equal the mean of the seven technical scores).

Photos: leave `flickering` and `motion_stability` as `N/A` (already prefilled).

## Rules

- Rate **what you see**. Do not judge whether the image is AI-generated.
- Do **not** open facilitator mapping files, machine score folders, KonIQ MOS, or other raters' sheets.
- Do not invent scores. Empty cells mean not yet rated.
- Work alone. Do not discuss scores until all three raters have submitted.
- Return your completed `ratings_R#.csv` to the facilitator.

## Viewing

1. Color-managed viewer, sRGB preferred.
2. Fit-to-window first for brightness, contrast, overall.
3. 100% (and 200% if needed) for sharpness, blur, noise, blocking, ringing.
4. Do not apply sharpening, filters, or auto-enhance.

## Status

Score cells start empty on purpose. Independent validation is **not complete** until
R1, R2, and R3 all submit filled sheets and analysis is run separately.
