# ACCESS VisionCheck — Seven-metric research consolidated report

**Status:** documentation only. Not an implementation approval.  
**Compiled:** 2026-11-08.  
**Constraint:** saved research reports and JSON/CSV summaries only. No new inference. SPAQ-200 images were not opened for this document. Production scoring, APIs, Flutter, weights, and `_soft_score` were not changed.

No candidate is production-ready. No winning algorithm is selected.

---

## 0. How to read this document

| Class | Meaning | Allowed claim |
|-------|---------|----------------|
| **Human-rated SPAQ proxy** | Spearman vs a SPAQ attribute or MOS on the locked 200 | Related-proxy rank agreement on that set. Not ACCESS-native 1–5. Do not fit 1–5 maps on those 200. |
| **Exploratory prototype** | Tenengrad / residual Noise at 1024 px; readiness report only | Stronger SPAQ-proxy correlation than ENET on those axes. Not deployed. Needs an a priori ladder and ACCESS humans. |
| **Automated diagnostic** | Controlled knobs, LIVEC 200, histograms, engine disagreement | Construct and saturation behavior. Not perceptual accuracy for ACCESS badges. |
| **Technical only** | No matching human attribute | Sensitivity and overlap only. No accuracy claim. |

ACCESS member badges are integers 1–5, higher = better. Amount heads (noise, blur, blocking, ringing) are inverted before `_soft_score`. `overall_score` is the **mean of those seven integers**.

Production map (unchanged):

```
boosted = clip(q * 0.5 + 0.42, 0, 1)
```

Bins: 5 if ≥ 0.80, 4 if ≥ 0.64, 3 if ≥ 0.46, 2 if ≥ 0.28, else 1.  
For any `q` in [0, 1], badge **1 is unreachable** (needs `q < −0.28`). Badge 2 needs `q < 0.08`.

Independent ACCESS 1–5 ratings: **not collected**. `HUMAN_RATING_RUBRIC.md` and `HUMAN_VALIDATION_PROTOCOL.md` exist. `workspace/human_pilot/` is empty of scores.

---

## 1. Shared production path

Preferred engine: EfficientNet-B0, seven sigmoid heads, 224×224. Fallback: `opencv_quality.analyze_bgr`. Display: `media_evaluator._photo_criteria`.

| Badge | Raw head | Quality `q` before `_soft_score` |
|-------|----------|----------------------------------|
| Sharpness | `sharpness` | `sharpness` |
| Blur | `blur` (amount) | `1 − blur` |
| Noise | `noise` (amount) | `1 − min(noise, 0.85)` |
| Brightness | `brightness` (luma-like) | triangle around 0.48 |
| Contrast | `contrast` | `min(contrast, 1)` |
| Blocking Artifacts | `blocking_artifacts` (amount) | `1 − blocking` |
| Ringing Artifacts | `ringing_artifacts` (amount) | `1 − ringing` |

OpenCV is a **different construct** on several axes (especially Blur = 1 − Sharpness, Blocking = 8×8 flatness). Engine must stay logged. Do not treat ENET and OpenCV as interchangeable.

---

## 2. Criterion summaries

### 2.1 Sharpness

**Class:** human-rated SPAQ proxy (Phase 10–12) plus exploratory Tenengrad prototype. **Frozen, not deployed.**

**Production:** ENET sharpness head; OpenCV Laplacian variance / 420. Display `_soft_score(sharpness)`.

**Samples:** SPAQ-200 machine scores (Phase 10/11/12, n=200); Phase 8 Gaussian ladder (10 originals + variants); Tenengrad prototype n=200 at 1024 px (0 failures, 111.6 s). SPAQ images were not re-opened for this consolidation.

**Findings:**

- ENET Sharpness badges on SPAQ-200: **0 / 1 / 154 / 45 / 0**. Pile at 3. Never 5.
- ENET raw vs SPAQ `attr_sharpness`: Spearman **0.117** (CI includes 0). Badge **0.086**.
- OpenCV Laplacian/420 vs SPAQ sharpness: **0.571**. Classical Tenengrad: **0.734** (Phase 12, beats ENET under the predeclared rule). Prototype Tenengrad at 1024: **0.753** (CI 0.679–0.799).
- Tenengrad vs ENET raw sharpness: **~0.07**. A swap would **rerank** photos, not rescale them.
- Laplacian/420 at 1024 px saturates (p95 = max = 1.0). `/420` is mis-scaled at that resize.
- Phase 8: ENET raw sharpness vs Gaussian σ **−1.00**. Integers still compress.

**Limitations:** SPAQ sharpness is “inversely related to blur” (Fang et al.). It is not ACCESS Sharpness ≠ Blur. Tenengrad is unbounded and cannot use `_soft_score` without a new a priori ladder. ACCESS-native 1–5 Sharpness ratings do not exist.

**Claim:** related-proxy rank agreement for Tenengrad/OpenCV vs SPAQ sharpness on 200 photos. **Not** ACCESS 1–5 accuracy. **Not** production-ready.

---

### 2.2 Noise

**Class:** human-rated SPAQ proxy (noisiness, high = more noise) plus exploratory residual prototype. **Exploratory, not deployed.**

**Production:** ENET amount head; OpenCV residual std / 36. Display `_soft_score(1 − min(noise, 0.85))`. Cap 0.85 floors worst-case cleanliness. Stored `noise_score` polarity is inverted vs the badge (admin dumps are easy to misread).

**Samples:** SPAQ-200 (n=200); Phase 8 AWGN; residual prototype n=200 at 1024 px.

**Findings:**

- ENET Noise badges on SPAQ-200: **0 / 0 / 67 / 129 / 4**. No 1–2.
- ENET raw amount vs SPAQ noisiness: **0.290**. Cleanliness badge vs noisiness: **−0.264** (correct invert, weak).
- OpenCV residual / classical residual vs noisiness: **0.600**. Immerkaer: **0.369**.
- Phase 8: ENET raw noise vs AWGN **+0.94**; integers mostly saturated. AWGN **raises** ENET raw sharpness (**+0.77**): grain as “detail.”
- Feeding residual cleanliness through `_soft_score` collapses to badge 5 (illustrative 175/200). A **new ladder** is required.

**Limitations:** SPAQ noisiness ≠ ACCESS grain vs texture. Residual std responds to texture. Prototype is not calibrated. Humans missing.

**Claim:** residual amount tracks SPAQ noisiness better than ENET on this 200. **Not** ACCESS Noise accuracy. **Not** production-ready.

---

### 2.3 Brightness

**Class:** SPAQ proxy (weak) plus **automated diagnostic** (controlled KonIQ 40×7, LIVEC 200, low-key review). **No candidate approved.**

**Production:** ENET/OpenCV luma proxy then triangle `_brightness_metric` at 0.48, then `_soft_score`.

**Samples:** 560 ENET/OpenCV controlled rows (0 failures); 280 candidate rows B1/B2; LIVEC 200, seed `20261108`, 200/200 ok; 14 low-key B2 flags reviewed. SPAQ-200 not used in the B/C phase.

**Findings:**

- ENET Brightness on severe underexposure (mean luma 0.104): mean badge **4.725**. Direction severe_under ≤ 2: **0/40**. Spearman(ENET raw, luma) **0.154**.
- OpenCV raw brightness vs luma **1.0** by construction; still a global mean, not subject exposure.
- LIVEC ENET Brightness: **0 / 0 / 1 / 50 / 149**, mean 4.74, **74.5% at 5**.
- SPAQ: ENET badge vs `attr_brightness` **0.045**; triangle @ 0.48 **0.427** (beats ENET; still a proxy). SPAQ does not split over vs under.
- B2 tracks under-exposure knobs (40/40) but **false-positives night/low-key** (14 LIVEC cases): triangle on mean luma, not clip spikes. ENET stayed 4–5. MOS can still be high (e.g. 1041, 1092).

**Limitations:** Rubric is **subject** exposure. Global luma (ENET triangle, B1/B2, OpenCV mean) scores the whole frame. Temporary B/C anchors are unvalidated. No humans.

**Claim:** ENET Brightness is insensitive to severe underexposure on the controlled set and saturates high on LIVEC. B2 is a diagnostic heuristic, not a validated replacement.

---

### 2.4 Contrast

**Class:** SPAQ proxy (ENET **wrong sign**) plus automated diagnostic. **No candidate approved.**

**Production:** ENET/OpenCV RMS-like amount, `_soft_score(min(contrast, 1))`. Higher RMS = higher badge, so harsh clip can score well.

**Samples:** same B/C controlled and LIVEC 200; Phase 8 contrast ladders; Phase 12 SPAQ contrast.

**Findings:**

- SPAQ: ENET raw **−0.147**, badge **−0.028** vs `attr_contrast` (fails declared +). Do **not** invert ENET in production from that set.
- OpenCV RMS **0.319**, Michelson **0.346** (correct sign, beat ENET). Not deployed.
- Phase 8: ENET integers stuck; raw barely tracks RMS. OpenCV/C1 **reward** excessive contrast. C2 drops on 31/40 excessive-contrast variants.
- LIVEC ENET Contrast: **0 / 25 / 173 / 2 / 0**, mean 2.89 (**86.5% at 3**). OpenCV Contrast **53% at 5**. ENET vs OpenCV gap ≥ 2: **115/200**.
- ENET raw vs gray_std on controlled B/C: **−0.191**.

**Limitations:** ACCESS Contrast penalizes harsh clip as the main look. RMS and C1 are magnitude. C2 can punish intentional night/stage contrast. SPAQ contrast ≠ ACCESS 1–5. No humans.

**Claim:** ENET Contrast does not follow the ACCESS/SPAQ construct. OpenCV RMS follows magnitude, not “harsh is bad.” No production swap.

---

### 2.5 Blur

**Class:** **technical only.** No SPAQ Blur attribute. Wave A (saved Phase 8/11/12) + Wave B LIVEC 200 (`run_blur_livec_001`).

**Production:** ENET amount inverted; OpenCV `blur = 1 − sharpness` (exact inverse of Laplacian sharpness).

**Samples:** Phase 8 Gaussian 10+50; Phase 11/12 unlabeled summaries; LIVEC 200, 200/200 ok, 124.7 s. Same keys as B/C.

**Findings:**

- ENET integers **do not move** on Gaussian σ through 8 (0/10 defined Spearman). Raw blur vs σ **+0.94**.
- SPAQ ENET Blur badges **0 / 2 / 180 / 18 / 0**.
- LIVEC ENET Blur **0 / 2 / 178 / 20 / 0**, mean 3.09. OpenCV Blur **0 / 7 / 48 / 28 / 117**, **identical** to OpenCV Sharpness.
- OpenCV `|s + b − 1| = 0`. ENET raw sharpness vs blur LIVEC Spearman **−0.92**.
- ENET vs OpenCV Blur badges: Spearman **0.11**, gap ≥ 2 on **103/200**.
- No code split of bokeh, motion smear, and unwanted defocus.

**Limitations:** LIVEC MOS is overall, not Blur GT. BID/LIVE blur not on disk. Rubric allows high Blur quality with lower Sharpness; trainer labels were `s = 1 − gaussian`.

**Claim:** construct sensitivity and duplication only. **Not** independently human-validated.

---

### 2.6 Blocking Artifacts

**Class:** **technical only.** Wave A + Wave B (`run_block_ring_livec_001`).

**Production:** ENET amount inverted. OpenCV: **fraction of 8×8 patches with variance < 8** (flatness / sky, not DCT boundaries). Classical research metric: 8×8 boundary |Δ| ratio.

**Trainer:** JPEG applied only if `blocking_amount > 0.2`; smaller amounts can be labeled blocked with **no JPEG**. ENET input 224×224 smears the 8×8 grid.

**Samples:** Phase 8 JPEG Q 70→8; Phase 11/12 summaries; LIVEC 200, 200/200 ok, 90.7 s.

**Findings:**

- ENET JPEG integers defined on **2/10**; raw vs severity **+0.43**. Classical 8×8 ratio **+1.00**. OpenCV flat-frac also **+1.00** on that ladder (wrong construct, co-moves).
- OpenCV blocking vs classic flat-frac Spearman **1.0** (same metric).
- SPAQ unlabeled ENET badges **0 / 0 / 131 / 69 / 0**.
- LIVEC ENET Blocking **0 / 1 / 118 / 81 / 0**. OpenCV Blocking **0 / 0 / 32 / 85 / 83**, 41.5% at 5 (clean flats look “uncompressed”).
- ENET vs OpenCV Blocking Spearman **~0**; gap ≥ 2 on **50/200**. ENET vs classic 8×8 ratio **−0.08**.

**Limitations:** No SPAQ label. LIVE JPEG MOS mixes blocking, blur, and ringing. OpenCV Blocking is not 8×8 detection.

**Claim:** technical diagnostic only.

---

### 2.7 Ringing Artifacts

**Class:** **technical only.** Same Wave A/B as Blocking.

**Production:** ENET amount inverted. OpenCV: Canny pixels whose consecutive row diffs **change sign**. Classical: |Laplacian| on Canny. Trainer: unsharp after JPEG if `ringing_amount > 0.25`. No JPEG2000.

**Findings:**

- ENET ringing integers **undefined 10/10** on unsharp. Raw **+0.66**. Continuous quality Δ at max step about **−0.023**.
- Unsharp **raises** ENET raw sharpness (**+0.94**) and raw noise (**+0.77**) on that ladder.
- SPAQ unlabeled: ENET **0 / 0 / 94 / 106 / 0**. OpenCV ringing mean **0.113**, max **0.5** (scale compressed).
- LIVEC ENET Ringing **0 / 0 / 98 / 102 / 0**. OpenCV Ringing **0 / 0 / 0 / 38 / 162**, **81% at 5**.
- ENET vs OpenCV Ringing gap ≥ 2: **76/200**. Spearman **0.09**.

**Limitations:** Phone unsharp ≠ JP2K ringing. Sign flips ≠ halos. Edge Laplacian overlaps Sharpness. No humans.

**Claim:** technical diagnostic only.

---

## 3. Final evidence table

| Criterion | Evidence class | Main n | Production badge pattern | Strongest research signal | Human ACCESS 1–5 | Deploy now? |
|-----------|----------------|--------|--------------------------|---------------------------|------------------|-------------|
| Sharpness | SPAQ proxy + prototype | 200 SPAQ; Phase 8 | Pile at 3 | Tenengrad r≈0.73–0.75 vs SPAQ sharpness | None | **No** |
| Noise | SPAQ proxy + prototype | 200 SPAQ; Phase 8 | 3–4, no 1–2 | Residual std r=0.60 vs noisiness | None | **No** |
| Brightness | Diagnostic + weak SPAQ | 280 ctrl; 200 LIVEC | LIVEC 74.5% at 5 | ENET ignores severe under; B2 night FPs | None | **No** |
| Contrast | Diagnostic + SPAQ wrong sign | 280 ctrl; 200 LIVEC | LIVEC 86.5% at 3 | ENET vs SPAQ negative; OpenCV rewards punch | None | **No** |
| Blur | Technical | Phase 8; 200 LIVEC | LIVEC almost all 3 | Raw tracks Gaussian; badges do not; OpenCV = 1−Sharpness | None | **No** |
| Blocking | Technical | Phase 8 JPEG; 200 LIVEC | 3–4 | Classic 8×8 tracks JPEG; OpenCV is flatness | None | **No** |
| Ringing | Technical | Phase 8 unsharp; 200 LIVEC | 3–4 ENET; OpenCV 5 | Integers flat; unsharp boosts Sharpness | None | **No** |
| Overall MOS | SPAQ/LIVEC overall | 200 SPAQ; 1162 LIVEC | ENET overall vs SPAQ MOS **−0.067** | MUSIQ 0.828 (separate channel, legal/ops gates) | N/A as 7th badge | **No** as badge replacement |

MUSIQ remains a **separate MOS channel**. It does not validate any of the seven badges. pyiqa is noncommercial. TF Hub production use needs legal review. Do not average MUSIQ into `overall_score` without a product decision.

---

## 4. Saturation and unreachable 1

Verified across Phase 11 SPAQ ENET, B/C LIVEC, Blur LIVEC, and Blocking/Ringing LIVEC:

- Badge **1 never appears** on production `_soft_score` for `q` in [0, 1].
- Noise `min(raw, 0.85)` further floors worst-case cleanliness.
- Sharpness, Blur, Contrast, Blocking, Ringing **pile at 3**. Brightness piles at **5**. OpenCV Ringing piles at **5** because raw amount is small.
- Phase 8: ENET **integer** Blur, Ringing, and often Blocking **do not move** with severe knobs. Raw heads often do. The display map hides severity.
- Reusing `_soft_score` on Tenengrad/residual **does not** fix compression (prototype illustrative Noise: 175/200 at 5). Any future axis swap needs a **new a priori ladder** that can emit 1–2.

XP and analytics that consume `overall_score` will move if histograms ever spread. Review under a flag, do not change now.

---

## 5. Overlap and double-counting in overall scoring

`overall_score` = mean of seven 1–5 integers (photo). Collinear axes inflate that mean.

| Overlap | Evidence | Effect on overall |
|---------|----------|-------------------|
| OpenCV Sharpness and Blur | Exact inverse | Same Laplacian counted twice |
| ENET Sharpness and Blur | LIVEC raw r ≈ −0.92; Phase 8 r ≈ −0.87 | Strongly overlapping focus axis |
| Unsharp Ringing and Sharpness | Phase 8 ENET raw sharpness vs unsharp **+0.94** | Halo energy scored as “sharp” and as ringing amount |
| JPEG Blocking, Blur, Ringing | Codec mixes defects; ENET blocking vs blur LIVEC **+0.22** | One compression event moves several badges |
| OpenCV Blocking vs texture | Flat-frac; sky/wall → high “blocking amount” | Clean flats can move Blocking and overall |
| OpenCV Ringing vs Noise/texture | Sign flips | Grain/texture can look like ringing |
| AWGN vs Sharpness | Phase 8 ENET raw sharpness vs AWGN **+0.77** | Noise counted as detail |
| Brightness triangle vs Contrast RMS | Both use global gray stats | Dark or punchy frames move two badges |

On LIVEC Blocking/Ringing Wave B, mean signed (`overall_7` − mean of the other five) was about **−0.018**. Small average shift does **not** mean the two badges are harmless: they still occupy two of seven slots and can disagree with the rubric.

Do not advertise seven independent human-validated dimensions.

---

## 6. Problems that hit member-facing 1–5 ratings

1. **Unreachable 1 / mid-band pile-up** from `_soft_score` (all seven).
2. **ENET Brightness stays high** on severe underexposure; members rarely see a low Brightness badge.
3. **ENET Contrast stuck near 3** and wrongly signed vs SPAQ contrast.
4. **Blur badge does not fall** on heavy Gaussian blur; OpenCV Blur is just inverted Sharpness.
5. **OpenCV Blocking** can call a clean wall blocked; ENET Blocking barely tracks JPEG.
6. **OpenCV Ringing** almost always 5; ENET Ringing integers ignore unsharp.
7. **Copy vs construct:** member text talks about motion/defocus, 8×8 blocks, and halos. Fallback metrics do not measure those things.
8. **224×224** smears JPEG grids, fine grain, and halos before ENET sees them.
9. **Trainer knobs ≠ rubric** (Gaussian-only blur, luma-as-brightness, JPEG/unsharp gated by random amount).
10. **No ACCESS-native human 1–5**, so product claims of “quality rating accuracy” are unsupported.

---

## 7. Ranked research concerns

Severity 1 = most urgent for **honest product claims** and **misleading member badges**. Evidence is from saved studies, not new runs.

| Rank | Concern | Why this rank | Evidence |
|------|---------|---------------|----------|
| 1 | `_soft_score` cannot emit 1 and hides knob severity | Every badge shares the map; XP uses the mean | Phase 8 integers flat for Blur/Ringing/JPEG; Phase 11 reconstruction; LIVEC histograms |
| 2 | Sharpness and Blur are one physical axis in OpenCV and nearly so in ENET | Two badges, one signal; overall double-counts | OpenCV identity 0; ENET raw r ≈ −0.9 |
| 3 | ENET Brightness does not track underexposure; saturates at 5 | Members get “well exposed” on dark frames | Controlled mean 4.725 at luma 0.10; LIVEC 74.5% at 5 |
| 4 | ENET Contrast wrong construct / wrong SPAQ sign; OpenCV rewards harsh RMS | Rubric vs magnitude | SPAQ r −0.147; LIVEC 173/200 at 3; OpenCV excessive-contrast badge 4.725 |
| 5 | OpenCV Blocking is flatness, not 8×8 | Fallback path lies relative to copy | `variance < 8` fraction; LIVEC OpenCV vs 8×8 r=0.33; vs flat-frac r=1 |
| 6 | No ACCESS 1–5 humans for any criterion | Blocks every accuracy claim | Empty human_pilot; protocol unused |
| 7 | Ringing/unsharp confounded with Sharpness and Noise | Halo scored as crispness | Phase 8 sharpness vs unsharp +0.94 |
| 8 | ENET 224×224 and trainer label leaks | Grid/halo/grain never fairly labeled | Phase 7 audit; JPEG only if amount > 0.2 |
| 9 | Sharpness/Noise prototypes need a new ladder and humans | Best SPAQ-proxy candidates still not deployable | Readiness report: `_soft_score` reuse fails; pack empty |
| 10 | MOS/MUSIQ ≠ seven badges | Risk of “accuracy” claims from overall IQA | SPAQ ENET overall −0.067; MUSIQ 0.828 MOS-only |

---

## 8. What can and cannot be claimed

**Can claim (research):**

- Production integers are compressed; badge 1 is unreachable for unit-interval `q`.
- On controlled knobs, several **raw** heads move while **integers** do not.
- On SPAQ-200, Tenengrad and residual noise **rank-agree** with SPAQ sharpness/noisiness better than ENET heads (related proxy).
- On SPAQ-200, ENET Contrast Spearman vs SPAQ contrast is **negative**.
- OpenCV Blur is identically 1 − Sharpness. OpenCV Blocking is 8×8 flatness.
- B1/B2/C1/C2, Tenengrad, residual, 8×8 ratio, and edge-Laplacian are **research diagnostics**, not product scores.
- Official MUSIQ tracks LIVEC/SPAQ **overall MOS** well in research engines, as a separate channel.

**Cannot claim:**

- Any method is perceptually accurate for ACCESS 1–5.
- Any candidate is production-ready or a winner.
- LIVEC/SPAQ MOS is Brightness, Contrast, Blur, Blocking, or Ringing GT.
- Sharpness and Blur are independently validated.
- OpenCV fallback measures the same constructs as ENET or as the member copy.
- Night photos with low B2 are poorly exposed subjects.
- Improving MOS Spearman is improving a technical badge.

---

## 9. Validation gaps (must close before integration)

1. ACCESS-native 1–5, ≥3 blinded raters, rubric, no MOS/machine on screen (`HUMAN_VALIDATION_PROTOCOL.md`).
2. A priori 1–5 ladders that can emit 1, **not** fit on SPAQ-200, **not** `_soft_score`.
3. Explicit product decision: one focus axis vs two (Sharpness vs Blur).
4. Subject-centric Brightness vs whole-frame luma (include the 14 LIVEC low-key IDs).
5. Contrast: magnitude vs harsh-clip penalty (humans, not C2 vs MOS).
6. Labeled blocking/ringing/blur sets (LIVE/TID/BID) only after download + protocol; still **partial** MOS, not ACCESS 1–5.
7. Engine policy: when ENET fails, OpenCV must not silently change construct.
8. Video: all photo evidence here. Do not transfer Spearman to frame sampling.
9. XP / `overall_score` impact if any axis ever changes.
10. MUSIQ: legal review, ops, MOS-only sidecar. Not a seventh-badge replacement.

---

## 10. Prioritized research roadmap (approval required per step)

Do not start these until explicitly approved. Do not fit on locked SPAQ-200. Do not overwrite frozen outputs (`run_bc_livec_001`, `run_blur_livec_001`, `run_block_ring_livec_001`, Phase 8/11/12, Sharpness/Noise prototype).

| Priority | Work | Purpose | Depends on |
|----------|------|---------|------------|
| P0 | Collect ACCESS 1–5 on a locked subset of LIVEC 200 (and/or real member photos), stratified: night, flat, harsh, blurry, blocky | Only path to accuracy claims | Raters |
| P1 | Pre-register a 1–5 ladder that can reach 1; validate on P0, do not refit on the same photos | Fixes display compression if an axis ever changes | P0 or a declared split |
| P2 | Product: Sharpness vs Blur (keep both as technical, or one axis + copy change) | Stops double-counting | P0 for Blur types |
| P3 | If still desired: Tenengrad Sharpness and residual Noise **behind a default-off flag**, new ladder, XP review | Strongest SPAQ-proxy candidates | P0+P1; readiness report section 6 |
| P4 | Brightness/Contrast humans on B/C LIVEC slice (include 14 low-key IDs); do not ship B2/C2 | Resolve night-sky vs subject | P0 |
| P5 | Wave C public JPEG/JP2K/blur subsets after dataset approval, labeled **partial MOS** | Stress tests only | Download + protocol |
| P6 | MUSIQ MOS sidecar after legal/ops | Overall IQA, not seven badges | Counsel |

**Not on the roadmap without new evidence:** invert ENET Contrast; replace OpenCV Blocking with “8×8” in copy; treat LIVEC MOS as a winner rule; Wave C without approval.

---

## 11. Frozen artifacts (do not overwrite)

- Sharpness/Noise: `SHARPNESS_NOISE_PROTOTYPE_READINESS.md`, `workspace/datasets/spaq/output/sharpness_noise_prototype/`
- Phase 8–13: `CONTROLLED_DISTORTION_RESULTS.md`, `PHASE11_SCORING_DIAGNOSTICS.md`, `PHASE12_*`, `PHASE13_RUNTIME_BENCHMARK_REPORT.md`
- Brightness/Contrast: `BRIGHTNESS_CONTRAST_RESEARCH_FINAL_REPORT.md`, `run_bc_livec_001/`
- Blur: `run_blur_livec_001/`
- Blocking/Ringing: `run_block_ring_livec_001/`

Production scorer hashes recorded on Blur and Blocking/Ringing LIVEC runs (unchanged during those evals):

- `efficientnet_b0_scorer.py` `747589dee3f3357e2b407bcecec28769522aaf959beb33520a276973950fec3f`
- `opencv_quality.py` `c36c5c933258a121df128e0cfc15b9477060128ca239af3a2ea192857838ea04`
- `media_evaluator.py` `d61836dbfcc3743537c35efcd4e63438867d4f54c2cf293e8071e7e0005c03d7`
- `efficientnet_b0_heads.pt` `ec5df6ce013cbcbcef78fe6d83e00a70786539bd9d34b5333cacfcf2156d38cc`

---

## 12. Stop line

Automated research phases for all seven member badges are **documented**. Production remains frozen. **No candidate is approved for integration.**

Wait for explicit approval before humans, Wave C, ladder design, or any production change.
