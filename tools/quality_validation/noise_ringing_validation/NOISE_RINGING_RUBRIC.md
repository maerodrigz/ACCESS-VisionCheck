# ACCESS VisionCheck — Noise and Ringing human rating rubric (1–5)

**Scope:** Independent validation of **Noise** and **Ringing Artifacts** only.  
**Higher is always better** (5 = clean / free of the defect).  
**Integers 1–5 only.** Use `N/A` if you cannot judge. Never use 3 as “unknown.”

Do not look at machine scores, SPAQ labels, KonIQ MOS, stratum tags, or other raters’ sheets.

This rubric expands the general ACCESS photo rubric. It does **not** claim any detector is validated.

---

## Global viewing rules

1. Color-managed viewer, sRGB preferred. No auto-enhance, sharpening, or denoise in the viewer.
2. Pass A: fit-to-window (context).
3. Pass B: **100%** crop on flat midtones/shadows for Noise; on high-contrast edges for Ringing.
4. Pass C (if needed): **200%** only to confirm faint grain or faint halos. Do not invent defects that vanish at 100%.
5. Rate the **documentation usefulness** of the photo for ACCESS (club/event record), not artistic preference.

---

## Shared scale anchors

| Score | Label | Anchor (both criteria) |
|------:|-------|------------------------|
| 5 | Excellent | No meaningful defect at normal view and at 100% crop. |
| 4 | Good | Only minor defect; still suitable for ACCESS documentation. |
| 3 | Fair | Defect clearly visible; below a strong submission but subject remains usable. |
| 2 | Needs improvement | Obvious defect; a retake would normally be required. |
| 1 | Poor | Defect dominates; unusable for club documentation on this criterion. |

---

## Criterion A — Noise (freedom from noise)

### What Noise means here

Visible **sensor grain / luminance speckles** or **chroma (color) blotches** that are not part of the real scene texture and that reduce clean tonal areas or subject readability.

Typical places to look: shadows, under-exposed walls, night sky, smooth skin, out-of-focus blur disks, flat painted surfaces.

### 1–5 visual definitions

| Score | What you should see |
|------:|---------------------|
| 5 | Clean tones. No distracting grain or color splotches at 100%. |
| 4 | Mild luminance grain mainly in deep shadows; chroma mostly clean. |
| 3 | Grain visible in midtones or mild chroma blotches; subject still clear. |
| 2 | Heavy luminance and/or chroma noise; texture partly invented by grain. |
| 1 | Noise dominates; subject hard to separate from speckle. |

### Example-selection guidance (for facilitators building packs)

| Severity stratum | Prefer images that show |
|------------------|-------------------------|
| Clean | Well-lit, ISO-like clean flats; little shadow grain at 100% |
| Mild | Night/indoor with grain only in shadows |
| Moderate | Grain into midtones or mild purple/green blotches |
| Severe | High-ISO style chaos; subject submerged in speckles |

Include both **luminance-dominant** and **chroma-dominant** examples in calibration (not in the locked validation set).

---

## Criterion B — Ringing Artifacts (freedom from ringing)

### What Ringing means here

**Light/dark halos, ghost ridges, or oscillatory fringes** along high-contrast edges, usually from oversharpening or codec/compression edge ringing. Looks like a bright or dark outline that does not belong to the object.

Typical places: text edges, building silhouettes against sky, high-contrast logos, hard shadow boundaries after aggressive sharpening.

### 1–5 visual definitions

| Score | What you should see |
|------:|---------------------|
| 5 | Clean edges; no light/dark halo at 100%. |
| 4 | Faint halo only at 200% on a few edges. |
| 3 | Visible fringe around high-contrast edges at 100%. |
| 2 | Strong double edges or glowing outlines on many edges. |
| 1 | Halos dominate; subject looks cut-out or cartoon-outlined. |

### Example-selection guidance

| Severity stratum | Prefer images that show |
|------------------|-------------------------|
| Clean | Natural edges without outline glow |
| Mild | Subtle halo only on strongest edges at 200% |
| Moderate | Clear fringe at 100% on several edges |
| Severe | Strong double-edge / glowing outline across the frame |

---

## Confusion matrix — do not mix these constructs

Rate **each construct separately**. An image can be noisy without ringing, blocky without noisy, etc.

| What you see | Call it | Do **not** score as |
|--------------|---------|---------------------|
| Random speckles / sand-like grain in flats or shadows | **Noise (luminance)** | Ringing, Blocking, Texture |
| Purple/green/magenta blotches in shadows or smooth areas | **Noise (chroma)** | Ringing, Blocking |
| Real fabric weave, foliage, hair, carpet detail that stays coherent when you zoom | **Scene texture** (not a defect by itself) | Noise |
| Soft / streaked subject from defocus or motion | **Blur** (out of scope here → `N/A` if only rating Noise/Ringing) | Noise, Ringing |
| Low micro-detail while edges are still locked in focus | **Sharpness** (out of scope here) | Noise |
| 8×8 (or similar) **squares / tiles** in flat sky, walls, skin | **Blocking** | Noise, Ringing |
| Bright/dark **halo or ghost ridge along an edge** | **Ringing** | Blocking, Noise, Texture |
| A single clipped white/black region | **Brightness/exposure** | Noise |

### Decision rules (use these when unsure)

1. **Grain vs texture:** If the pattern is *random* and changes appearance like sand when zooming, prefer Noise. If it is *structured* and matches the object (threads, leaves), it is texture, not Noise.
2. **Chroma noise vs color bokeh / branding:** Isolated brand colors on a jersey are not chroma noise. Scattered color speckles in what should be smooth grey/black are chroma noise.
3. **Blocking vs ringing:** Blocking lives in **flat interiors** as a grid of squares. Ringing lives **on edges** as parallel fringe/halo. Do not mark blocky sky as Ringing.
4. **Blocking vs noise:** Squares that align to a lattice → Blocking. Speckle without lattice → Noise. You may see both; score each on its own criterion if both are rated.
5. **Sharp edge vs ringing:** A clean high-contrast edge with no light/dark companion ridge is **not** ringing. Only score Ringing down when a halo/ghost ridge is visible.
6. **Oversharpened crunch:** Crunchy texture plus edge glow usually means Ringing (and maybe Noise) — do not dump everything into Noise.

---

## Focused study scoring policy

For the independent Noise/Ringing validation:

- Required columns: `noise`, `ringing_artifacts`
- Other ACCESS criteria may be left `N/A` unless the facilitator explicitly requests a full seven-criterion pass
- `overall_visual_quality` is optional for this focused study; if filled, it must be independent (not the mean of Noise and Ringing)

---

## Integrity reminders

- Measurement existence in a machine report does **not** prove the badge is correct.
- Agreement between two machines does **not** prove human accuracy.
- Do not infer photographer skill from Noise or Ringing scores.
