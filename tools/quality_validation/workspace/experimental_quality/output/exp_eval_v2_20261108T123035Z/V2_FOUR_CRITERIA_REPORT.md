# experimental_classical_v2 — Blur / Noise / Blocking / Ringing

**Parent baseline preserved:** `experimental_classical_v1`  
**Candidate:** `experimental_classical_v2`  
**Evaluation package:** `exp_eval_v2_20261108T123035Z`  
**Production / human CSVs / Run 002:** unmodified

## Diagnoses addressed

| Criterion | v1 failure | v2 technical change |
|-----------|------------|---------------------|
| Blur | Absolute edge-grad near ceiling (mostly badge 5) | `log1p(Laplacian variance)` after 1024 resize |
| Noise | Texture confuses residual; ACCESS pilot wrong-signed | Homogeneous-region residual only |
| Blocking | Ratio after resize destroyed JPEG lattice; oversensitive | Native multiple-of-8 smooth-weighted seam \|Δ\| |
| Ringing | Edge \|Laplacian\| tracked sharpness (wrong-signed) | Smooth-side near-edge second-difference oscillation |

Scales remain a priori from synthetic ladders. SPAQ and ACCESS pilot were **not** used to choose thresholds.

## Synthetic / controlled evidence

- Blur: Gaussian sigma ladder on textured synthetic is monotone in raw Laplacian variance; CTRL `gaussian_blur` badges `[2,1,1,1,1]`.
- Noise: AWGN on flat panels monotone; texture alone < strong AWGN on flat.
- Blocking: smooth-gradient JPEG Q95→Q20 increases seam strength and lowers badge; CTRL jpeg badges `[4,4,3,3,3]`.
- Ringing: clean step oscillation ≈ 0; sinc Gibbs kernel raises oscillation. Still a weak proxy.

Unit tests: `tools/quality_validation/tests/test_experimental_criteria_v2.py`.

## SPAQ-200 vs production baseline (proxy attributes only)

| Pair | Production ρ | v2 ρ |
|------|-------------:|-----:|
| Sharpness | 0.086 | 0.749 |
| Noise cleanliness | 0.264 | 0.319 |
| Brightness | 0.045 | 0.410 |
| Contrast | −0.028 | 0.325 |
| Overall vs MOS (exploratory) | −0.067 | 0.591 |

Blur/Blocking/Ringing have **no** SPAQ attribute labels.

Badge spread: Blur and Blocking no longer collapsed; Ringing no longer stuck at low scores.

## Frozen ACCESS pilot secondary check (not for tuning)

| Criterion | Production ρ | v2 ρ | Verdict |
|-----------|-------------:|-----:|---------|
| Blur | 0.160 | **0.824** | Improved (descriptive) |
| Noise | −0.275 | −0.253 | Still wrong-signed / inconclusive |
| Blocking | 0.001 | −0.331 | Worsened / inconclusive |
| Ringing | 0.013 | −0.402 | Still wrong-signed |

Do **not** claim human validation success from these pilot correlations.

## Recommendation

1. **Keep production unchanged.**
2. **Keep v1 frozen** as the previous research checkpoint.
3. **Adopt v2 as the active research candidate** for Blur (strong synthetic + descriptive pilot gain) and for Blocking lattice handling (synthetic/CTRL improved; ACCESS still inconclusive).
4. **Noise and Ringing remain unresolved** for ACCESS-criterion alignment; do not ship.
5. Next step: collect new ACCESS-rubric labels on a disjoint set emphasizing noise/compression/halos; re-score with frozen v2 scales (no retuning on that set).
