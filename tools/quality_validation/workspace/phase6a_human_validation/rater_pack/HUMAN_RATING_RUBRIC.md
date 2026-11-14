# ACCESS VisionCheck — human rating rubric (1–5)

Use with `HUMAN_RATING_TEMPLATE.csv` and `HUMAN_VALIDATION_PROTOCOL.md`.

Rate **what you see** on the displayed photograph. Do not judge whether the image is AI-generated. Authenticity (PROBE, WaveRep, Gemini) is out of scope.

Higher is always better, including Blur and Noise.

Do not look at machine scores, published KonIQ MOS, stratum labels, or other raters' sheets.

If you cannot judge a criterion, write `N/A`. Never guess. Never use 3 as a stand-in for unknown.

This rubric does **not** claim that the production model is scientifically validated.

---

## Scale anchors (every criterion)

| Score | Label | Anchor |
|---|---|---|
| 1 | Poor | Unusable for club documentation on this criterion. The defect dominates the subject. |
| 2 | Needs improvement | Obvious defect. A retake would normally be required. |
| 3 | Fair | The subject is identifiable, but the defect is clearly visible and below a strong submission. |
| 4 | Good | Only minor issues. Suitable for ACCESS documentation. |
| 5 | Excellent | No meaningful defect on this criterion at normal viewing and at 100% crop. |

Use integers **1, 2, 3, 4, or 5** only. Do not use 2.5 or ranges.

Photos: set **flickering** and **motion_stability** to `N/A`.

**overall_visual_quality** is an independent impression of documentation usefulness. Do not force it to equal the mean of the seven technical scores. The system overall *is* that mean. The two quantities are compared separately.

---

## The seven photo criteria

### 1. Sharpness

**Question:** How much fine detail and edge texture remain in the *intended subject*?

| Score | What you should see |
|---|---|
| 5 | Hair, fabric weave, text, or foliage micro-detail is crisp at 100% on the subject. |
| 4 | Subject detail is clear; slight softness only in unimportant regions. |
| 3 | Subject is recognizable; fine texture is muted. |
| 2 | Detail is washed out; you cannot read small markings on the subject. |
| 1 | No usable subject detail. |

**Not sharpness:** overall darkness (Brightness), milky fog (Contrast), grain (Noise), JPEG squares (Blocking), or edge halos (Ringing).

### 2. Blur (quality of *low* blur)

**Question:** How free is the subject of motion smear or defocus (out-of-focus) blur?

| Score | What you should see |
|---|---|
| 5 | Subject edges are frozen and in focus. No smear in the direction of motion. |
| 4 | Tiny softness or a small missed-focus region that does not hide the subject. |
| 3 | Visible defocus or modest motion trail; subject still identifiable. |
| 2 | Strong smear or large out-of-focus area. A retake is needed. |
| 1 | Subject is a smear or completely missed focus. |

**Sharpness versus Blur (read before rating):**

- **Blur** is optical or motion: the lens missed focus, or the camera/subject moved during exposure. Edges look *streaked* or *softly defocused* (specular highlights become disks).
- **Sharpness** is remaining *micro-contrast and texture* after any blur. An in-focus image can still look unsharp if it is heavily processed, low-resolution, or mildly noisy.
- If the subject is streaked or has bokeh disks on what should be sharp, that is primarily **Blur**, not Sharpness.
- If the subject is in focus but texture looks "plastic" or low-frequency, that is primarily **Sharpness**, not Blur.
- You may score both low on the same image (severe defocus also destroys texture). You may score Blur high and Sharpness lower (focused but mushy detail). Do not copy one score onto the other automatically.

### 3. Noise (quality of *low* noise)

**Question:** How free is the image of grain, speckle, or chroma splotches that hide the subject?

| Score | What you should see |
|---|---|
| 5 | Clean tones; no distracting grain at 100%. |
| 4 | Mild grain in shadows only. |
| 3 | Grain visible in midtones; subject still clear. |
| 2 | Heavy luminance or color noise; texture is partly invented by grain. |
| 1 | Noise dominates; subject is hard to separate from speckle. |

**Not noise:** JPEG 8×8 squares (Blocking), edge halos (Ringing), or a uniformly soft lens (Blur).

### 4. Brightness

**Question:** Is the *important subject* well exposed?

| Score | What you should see |
|---|---|
| 5 | Subject tones are readable; highlights hold detail; shadows are not crushed on the subject. |
| 4 | Slightly dark or bright, still fully usable. |
| 3 | Noticeable under- or over-exposure; some subject detail lost. |
| 2 | Large clipped regions on the subject. |
| 1 | Subject is a black silhouette or a white blob. |

Rate the subject, not the artistic background. A backlit portrait with a readable face can still score 4.

### 5. Contrast

**Question:** Is there usable tonal separation between subject and surroundings, without harsh clipping as the *main* look?

| Score | What you should see |
|---|---|
| 5 | Clear separation; midtones carry shape. |
| 4 | Slightly flat or slightly punchy, still readable. |
| 3 | Foggy or a bit harsh; shape is reduced. |
| 2 | Very flat haze, or extreme crush/clip that flattens the subject. |
| 1 | No usable tone range on the subject. |

**Not contrast:** a single overexposed patch (Brightness), or local grain (Noise).

### 6. Blocking artifacts

**Question:** Are compression squares visible in flat areas (sky, walls, skin)?

| Score | What you should see |
|---|---|
| 5 | No 8×8 (or similar) blocks at 100–200% on flat regions. |
| 4 | Traces only if you hunt at 200%. |
| 3 | Blocks visible in sky or walls at 100%. |
| 2 | Obvious tiling across large areas. |
| 1 | Heavy blockiness; the image looks like a mosaic. |

**Not blocking:** random grain (Noise) or ringing fringes along edges (Ringing). Inspect flat regions, not only edges.

### 7. Ringing artifacts

**Question:** Are there halos or "ghost" ridges along high-contrast edges (sharpening or codec ringing)?

| Score | What you should see |
|---|---|
| 5 | Clean edges; no light/dark halo. |
| 4 | Faint halo only at 200% on a few edges. |
| 3 | Visible fringe around high-contrast edges at 100%. |
| 2 | Strong double edges or glowing outlines. |
| 1 | Halos dominate and look like a cutout. |

**Not ringing:** the subject being out of focus (Blur) or blocky sky (Blocking).

---

## Video-only (not used in the KonIQ photo pilot)

### Flickering

Exposure or color pumping between moments. 5 = stable. 1 = severe flicker. Photos: `N/A`.

### Motion stability

Camera shake and jitter. 5 = smooth. 1 = unusable shake. Photos: `N/A`.

---

## Viewing

1. Display in a color-managed viewer, sRGB, window light off the screen.
2. First pass at **fit-to-window** for Brightness, Contrast, and overall.
3. Second pass at **100%** (and 200% if needed) for Sharpness, Blur, Noise, Blocking, and Ringing.
4. Do not apply extra sharpening, filters, or "auto enhance" in the viewer.

## File format

One row per `(media_id, rater_id)`. Rater IDs: `R1`, `R2`, `R3`. See `HUMAN_RATING_TEMPLATE.csv`.
