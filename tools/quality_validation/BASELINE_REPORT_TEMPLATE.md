# ACCESS VisionCheck — Baseline Quality Validation Report (Template)

**Date:**  
**Toolkit version:**  
**Git revision:**  
**Analyst:**  

## 1. Executive summary

- Purpose of this baseline (Milestone 1, no production changes).
- Dataset size (dev / held_out, photos / videos).
- Engines evaluated (EfficientNet available? OpenCV available?).
- One-paragraph conclusion: **Do not claim accuracy** without human correlation evidence.

## 2. Reproducibility metadata

| Field | Value |
|-------|--------|
| Weights SHA-256 | |
| Python / NumPy / OpenCV / Torch | |
| Video sample frames | |
| Machine results path | |

## 3. Computational correctness

- Batch runner completed without errors: Yes / No
- Failure rate by engine and media type
- Partial frame errors (video)
- Notes on 422-equivalent failures (weights missing, etc.)

## 4. Repeatability

- Repeat runs (N= ): std dev of overall_score per media/engine
- Pass/fail vs target (example: σ &lt; 0.08 on 1–5 scale)

## 5. Agreement with human judgments

### 5.1 Inter-rater reliability (human only)

| Dimension | Fleiss κ (dev) |
|-----------|----------------|
| overall_documentation | |
| sharpness_blur | |
| … | |

### 5.2 Machine vs human (dev — calibration exploratory)

| Dimension | Engine | Spearman ρ | MAE | QWK | n pairs |
|-----------|--------|------------|-----|-----|---------|
| overall_documentation | efficientnet | | | | |
| overall_documentation | opencv | | | | |

### 5.3 Held-out (generalization — **not used for tuning**)

| Dimension | Engine | Spearman ρ | MAE | n pairs |
|-----------|--------|------------|-----|---------|

### 5.4 Engine comparison (EfficientNet vs OpenCV overall)

| Split | Pearson r | n paired |
|-------|-----------|----------|

## 6. Known limitations observed

- Synthetic-trained EfficientNet heads
- 224px resize, EXIF orientation
- Sparse video frame sampling
- Photography dimensions not machine-scored
- Insufficient-evidence defaults in production (document if seen in machine flags)

## 7. Recommendations (require further validation / approval)

- [ ] Milestone 2 evidence layer / remove misleading defaults
- [ ] Promote supplementary metrics to scored PQ
- [ ] Optical-flow motion scoring
- [ ] Primary engine selection: EfficientNet / OpenCV / hybrid
- [ ] **No recommendation to change production XP/rankings until …**

## 8. Sign-off

- [ ] held_out results reviewed without using them for calibration
- [ ] Ready for Milestone 2 design review: Yes / No / Blocked (reason)
