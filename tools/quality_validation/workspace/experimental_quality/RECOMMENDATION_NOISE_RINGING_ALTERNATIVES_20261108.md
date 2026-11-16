# Recommendation: Alternative Noise and Ringing detectors (no implementation yet)

**Date:** 2026-11-08  
**Status:** Proposal only. Awaiting approval.  
**Constraints:** Do not retune v2/v3 thresholds; do not modify production or existing experimental engines; do not download models or add dependencies until approved; do not use the frozen 30-photo pilot for fitting.

---

## 1. What already failed (do not repeat)

| Detector | Mechanism | Documented failure |
|----------|-----------|-------------------|
| Noise v2 | Homogeneous-region \|Y−blur\| std | Texture leakage; pilot under-detection (ceiling badge 5); ρ ≈ −0.25 |
| Noise v3 | Flat-block Laplacian MAD + chroma + homog max | Synthetic OK; SPAQ fragile without homog channel; pilot still negative / ceiling; not promoted |
| Ringing v2 | Near-edge \|d²\| on “smooth” side | Under-detects real halos; ρ ≈ −0.40; MAE better than v3 but **not** validated |
| Ringing v3 | Plateau overshoot + side residual osc. | Over-fires on clean sharp edges (floor badge 1); ρ ≈ −0.42; **not recommended** |

Root issues: Noise methods struggle to separate grain from texture under weak human reliability; Ringing methods confuse sharp monotonic edges with halos, or miss true bipolar rims.

---

## 2. Method survey (research-only)

### Noise

| Family | Idea | Texture vs noise | Fit for ACCESS |
|--------|------|------------------|----------------|
| Wavelet HH MAD (Donoho) | σ ≈ median\|HH₁\|/0.6745 | Better than global residual; strong texture still inflates HH | Good baseline; may need flat-mask or weak-texture selection |
| Patch PCA / SVD BNE | Noise from smallest eigenvalues of weak-texture patches (Liu–Tanaka–Okutomi class) | Explicit weak-texture patch selection | **Best lightweight classical match** to our failure mode |
| Immerkaer / Laplacian | Fast global σ from Laplacian kernel | Weak on textured photos | Too close to prior residual thinking |
| Pretrained NR-IQA / artifact CNNs | Learned | Potentially strong | Heavier; new weights/deps; defer until classical fails controlled gates |

### Ringing

| Family | Idea | Sharp edge vs halo | Fit for ACCESS |
|--------|------|--------------------|----------------|
| ESF / edge-spread width | Transition width | Measures blur more than ringing | Alone: insufficient |
| Plateau overshoot (v3-like) | Excess beyond L/R levels | Clean steps can still look “high” if sampling/guards fail | Already failed as primary |
| Bipolar halo lobes | Require bright **and** dark flanking extrema on the smooth side of a strong step, after subtracting a monotone ESF fit | Clean sigmoid → low; unsharp/Gibbs → high | **Best lightweight halo-specific candidate** |
| Pretrained sharpening/compression nets | Learned halos | Possibly good | Same deferral as Noise CNNs |

---

## 3. Recommended candidates (one each)

### Noise — **Patch PCA blind noise-level estimate (weak-texture patches)**  
**ID (proposed):** `experimental_noise_v4_pca` (new module only; do not overwrite v2/v3)

- Tile image (e.g. 8×8 after longest-side resize ≤1024).
- Score texture weakness (gradient energy / patch variance).
- Keep weakest-texture subset; form patch covariance / centered matrix; take smallest eigenvalue(s) → σ̂.
- Optional second channel: chroma PCA or HH MAD on the same weak patches (still classical).
- Map σ̂ → cleanliness with **a priori** REF from synthetic AWGN (flat + mild texture), never from the frozen pilot.

**Why this over wavelet-first:** Patch PCA is designed for blind σ under structured content; wavelet HH alone is simpler but closer to “high-pass energy,” which already failed us on texture/ceiling behavior. Wavelet HH MAD remains a **fallback A/B** if PCA is unstable on tiny flats.

### Ringing — **Monotone-ESF residual + bipolar halo lobe score**  
**ID (proposed):** `experimental_ringing_v4_halo` (new module only; do not overwrite v2/v3)

- Probe strong edges; sample 1-D normal profile.
- Fit a **monotone step/ESF** (e.g. robust logistic or cumulative Gaussian) to the profile.
- Residual = profile − fit.
- Score only if residual shows **paired opposite-sign lobes** within ~1–5 px of the edge (classic overshoot/undershoot), with amplitude above local plateau noise floor.
- Reject probes with high far-side texture or weak step contrast.
- Aggregate robust high quantile over probes; invert to cleanliness with a priori REF from unsharp/sinc ladders.

**Why this over more overshoot tuning:** v3 already measured overshoot/oscillation and floored clean edges. Requiring **bipolar structure after removing a monotone ESF** is the halo-specific constraint that clean sharp edges lack.

### Pretrained models
Appropriate only as a **later optional track** (e.g. small artifact CNN or strong NR-IQA) if v4 classical candidates fail controlled gates. **Do not download weights or add pip deps in this phase.** Prefer NumPy / OpenCV / existing SciPy only for v4.

---

## 4. Expected cost

| | Noise v4 PCA | Ringing v4 halo |
|--|--------------|-----------------|
| Runtime (target, 1024 long side) | ~20–80 ms typical; up to ~150 ms if many patches / full SVD | ~30–100 ms (edge subsample + 1-D fits) |
| Complexity | Medium (patch select + covariance/SVD) | Medium (edge probes + robust 1-D fit + lobe logic) |
| Dependencies | NumPy; SciPy SVD OK if already present; OpenCV for resize/gray | NumPy + OpenCV; SciPy curve_fit optional |
| Limitations | Few flat regions → unstable σ̂; processed/denoised photos may under-report; not semantic “ACCESS Noise” if raters disagree | Misses mild one-sided glow; Gibbs far from edge may under-score; still proxy, not psychophysics |

Combined with existing v2 five-heads + Blocking v3, expect research path still on the order of seconds per large SPAQ still if Blocking crop caps remain; Noise/Ringing v4 alone should stay sub-second.

---

## 5. Controlled test design (no frozen-pilot tuning)

**Hard rule:** Frozen ACCESS 30 is **secondary check only** after scales are frozen. Never choose REF/thresholds from it.

### Noise v4 gates (synthetic + texture)
1. AWGN ladder on flat panel: σ ∈ {0,5,10,20,40} → amount monotone nondecreasing.
2. Chroma-only noise ladder → responds (v2 was blind).
3. Low-light × noise ladder → generally worsens.
4. Clean textured synthetic / lightly compressed texture → amount ≪ AWGN-20 on flat.
5. Optional diagnostic: SPAQ `attr_noisiness` Spearman **after** a priori freeze (not for fitting).

### Ringing v4 gates
1. Clean step / anti-aliased step → high cleanliness badge (≥4).
2. Unsharp amount ladder → generally worsens vs clean.
3. Mild Gibbs/sinc ladder → generally worsens; no collapse to “clean” at mid strength.
4. Natural texture without strong steps → not false-strong ringing.
5. Heavy JPEG alone → must not be scored as strong ringing (Blocking’s job).

### Process
- Implement as **new files only**.
- Unit tests + lightweight runner (like Blocking/Ringing v3 lightweight).
- Full SPAQ / new human set only after approval and a priori scale freeze.
- Independent ACCESS-rubric set (disjoint from the 30) remains the real human target, with clearer Noise/Ringing definitions.

---

## 6. Implementation plan (after approval)

1. Add `experimental_noise_v4_pca.py` and `experimental_ringing_v4_halo.py` (estimators only).
2. Add thin engines or a research `combined` fork that swaps only these heads; **do not edit** v2/v3/combined_v1 sources.
3. Add `tests/test_experimental_noise_v4.py` and `tests/test_experimental_ringing_v4.py` implementing the gates above.
4. Add lightweight runners with progress prints; no silent long jobs.
5. Freeze a priori REFs from synthetic ladders; write a short PASS/FAIL note.
6. Only if lightweight PASS: optional diagnostic SPAQ noisiness for Noise; optional secondary frozen-pilot check (report only).
7. Stop for review before any production discussion.

---

## 7. Recommendation summary

| Head | Candidate | Action now |
|------|-----------|------------|
| Noise | Patch PCA weak-texture BNE (`experimental_noise_v4_pca`) | Approve to implement classical module + controlled tests |
| Ringing | ESF-fit + bipolar halo lobes (`experimental_ringing_v4_halo`) | Approve to implement classical module + controlled tests |
| Pretrained nets | Deferred | No download / no new deps until classical path fails |
| Frozen pilot | Not for tuning | Secondary only |
| Production / existing engines | Untouched | Preserve |

**Awaiting approval before any implementation.**
