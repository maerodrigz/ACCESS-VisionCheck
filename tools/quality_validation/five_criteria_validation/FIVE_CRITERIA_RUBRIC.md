# ACCESS VisionCheck — Five-criteria human rating rubric (1–5)

**Scope:** Sharpness, Blur, Brightness/Exposure, Contrast, Blocking Artifacts only.  
**Higher is always better** (5 = good / free of the defect).  
**Integers 1–5 only.** Use `N/A` if you cannot judge. Never use 3 as “unknown.”

Do not look at machine scores, SPAQ labels, KonIQ MOS, stratum tags, or other raters’ sheets.

This rubric expands the ACCESS photo rubric for an independent Classical vs production study. It does **not** claim any detector is validated.

---

## Global viewing rules

1. Color-managed viewer, sRGB preferred. No auto-enhance, sharpening, denoise, or contrast stretch in the viewer.
2. Pass A: fit-to-window (context / subject readability).
3. Pass B: **100%** crop on the subject’s important detail (Sharpness/Blur), on midtones for Contrast, on flat areas for Blocking, and judge overall subject exposure for Brightness.
4. Pass C: **200%** only to confirm faint blocking seams or fine edge detail. Do not invent defects that vanish at 100%.
5. Rate **documentation usefulness** for ACCESS (club/event record), not artistic preference.

---

## Shared scale anchors

| Score | Label | Anchor |
|------:|-------|--------|
| 5 | Excellent | No meaningful defect at normal view and at 100% crop. |
| 4 | Good | Only minor defect; still suitable for ACCESS documentation. |
| 3 | Fair | Defect clearly visible; subject still usable. |
| 2 | Needs improvement | Obvious defect; a retake would normally be required. |
| 1 | Poor | Defect dominates; unusable for club documentation on this criterion. |

---

## Criterion 1 — Sharpness (fine detail / micro-contrast)

### What it means

How well **fine subject detail** is resolved when the subject is intended to be sharp (eyes, text, edges of the primary subject).

### 1–5 definitions

| Score | What you should see |
|------:|---------------------|
| 5 | Crisp micro-detail at 100% on the intended subject. |
| 4 | Slight softness; subject still clearly detailed for documentation. |
| 3 | Soft detail; edges rounded; identity still clear. |
| 2 | Soft enough that fine details are hard to read. |
| 1 | Mushy / plastic; subject detail largely lost. |

**Not Sharpness alone:** global motion smear → primarily **Blur**. Shallow artistic bokeh in the background is OK if the **subject** is sharp.

---

## Criterion 2 — Blur (freedom from motion / defocus smear)

### What it means

Freedom from **motion smear**, handshake trails, or unintended **defocus** on the subject.

### 1–5 definitions

| Score | What you should see |
|------:|---------------------|
| 5 | Subject free of smear or unintended soft focus. |
| 4 | Mild softness or tiny streak; still acceptable. |
| 3 | Noticeable smear or defocus; subject still identifiable. |
| 2 | Strong smear / miss-focus; retake preferred. |
| 1 | Subject unreadable due to blur. |

**Sharpness vs Blur:** A photo can be soft (lower Sharpness) without motion trails (Blur still high). Do **not** force `Blur = 6 − Sharpness`.

---

## Criterion 3 — Brightness / Exposure (subject exposure suitability)

### What it means

Whether the **subject** is usable in tone: not crushed in darkness and not blown out. **Both under- and over-exposure lower the score.** High score = good subject exposure for documentation.

### 1–5 definitions

| Score | What you should see |
|------:|---------------------|
| 5 | Subject well exposed; important tones readable. |
| 4 | Slightly dark or bright; subject still clear. |
| 3 | Clearly under- or over-exposed; subject still findable. |
| 2 | Severe under/over; large loss of subject detail. |
| 1 | Subject lost in black or white; unusable exposure. |

**Ambiguous cases:** Artistic silhouette of a whole scene may be `N/A` if there is no intended “subject exposure” to judge. Prefer rating when a person, object, or documentation subject is clear.

**Calibration focus:** Pilot Brightness IRR was near chance. Raters must agree that dark-and-bad and bright-and-bad both score low.

---

## Criterion 4 — Contrast (usable tonal separation)

### What it means

Usable separation between subject and surroundings / midtones, without crushing everything to black/white.

### 1–5 definitions

| Score | What you should see |
|------:|---------------------|
| 5 | Clear, usable tonal separation; subject reads easily. |
| 4 | Mildly flat or mildly punchy; still fine for docs. |
| 3 | Flat or harsh; subject still separable. |
| 2 | Very flat or heavily crushed; hard to read subject. |
| 1 | Nearly no usable range; subject merges into wash or ink. |

**Not Contrast:** Prefer “punchy Instagram” look that destroys shadow detail → lower Contrast. Do not reward harsh clip as “good contrast.”

---

## Criterion 5 — Blocking Artifacts (freedom from compression blocks)

### What it means

Visible **8×8-style blockiness**, mosaic patches, or codec tiling in flat regions (sky, walls, skin), usually from heavy JPEG/compression.

### 1–5 definitions

| Score | What you should see |
|------:|---------------------|
| 5 | No visible blocks at 100% in flats. |
| 4 | Faint tiling only at 200% in a few flats. |
| 3 | Visible blocks in flats at 100%. |
| 2 | Obvious mosaic across large flat areas. |
| 1 | Blocking dominates; looks heavily crushed by compression. |

**Not Blocking:** Film grain / sensor noise → Noise (out of scope here; do not lower Blocking for grain). Natural texture (brick, foliage) is not blocking.

---

## Confusion matrix (read before rating)

| You see… | Prefer criterion | Avoid mistaking for |
|----------|------------------|---------------------|
| Soft subject detail, no streak | Sharpness ↓ | Blur |
| Streaks / double edges from motion | Blur ↓ | Sharpness only |
| Subject too dark or blown | Brightness ↓ | Contrast only |
| Flat gray wash or crushed blacks/whites | Contrast ↓ | Brightness only (unless also under/over) |
| Mosaic tiles in sky/wall | Blocking ↓ | Noise / texture |
| Grain speckles | *(out of scope)* | Do not punish Blocking |
| Edge halos / ringing | *(out of scope)* | Do not invent Blocking |

---

## N/A and ambiguity

Use `N/A` when:

- The construct is not observable (e.g. no flat region at all for Blocking; intentional total silhouette for Brightness).
- The file is corrupt or not a photograph.

Do **not** use `N/A` to avoid hard decisions when the defect is visible. Do not use 3 as “unsure.”

---

## Facilitator severity strata (raters never see these tags)

| Field | Values |
|-------|--------|
| `sharpness_stratum` | clean, mild, moderate, severe |
| `blur_stratum` | clean, mild, moderate, severe |
| `brightness_stratum` | clean, under_mild, under_severe, over_mild, over_severe |
| `contrast_stratum` | clean, flat_mild, flat_severe, harsh_mild, harsh_severe |
| `blocking_stratum` | clean, mild, moderate, severe |

Validation packs must include **both under- and over-exposure** examples and **deliberate blocking severity**, or Brightness/Blocking IRR and rank tests will collapse again.
