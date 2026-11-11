# EfficientNet-B0 Noise and Ringing Head Retraining Feasibility Audit

**Date:** 2026-11-09  
**Status:** Architecture and training-data audit only. No training, no weight changes, no production edits.  
**Context:** Production Noise/Ringing failed NR001–NR015 (KEEP UNVALIDATED). CLIP noisiness feasibility NO-GO. Locked NR15 and pilot-30 must not be used for training or selection.

---

## 1. Actual architecture findings

### Checkpoint

| Field | Value |
|-------|-------|
| Path | `access_backend/ml/efficientnet_b0_heads.pt` |
| Size | 16,364,467 bytes (~15.6 MB) |
| Format | Full `state_dict` (360 tensors) |
| Total parameters | 4,058,580 |
| Head parameters | **8,967** (`head.weight` 7×1280 = 8,960 + `head.bias` 7) |
| Load check | `load_state_dict(..., strict=False)` → **0 missing, 0 unexpected** |

### Model graph (inference)

Source: `access_backend/app/services/efficientnet_b0_scorer.py`

1. Backbone: torchvision EfficientNet-B0 ImageNet-1K (`EfficientNet_B0_Weights.IMAGENET1K_V1`) → `features`
2. `avgpool` → flatten → **1280-D global vector**
3. `Dropout(0.15)` (inactive in `eval()`)
4. **Single** `nn.Linear(1280, 7)` named `head` (not seven separate modules)
5. **Sigmoid** → continuous metrics in `[0, 1]`

`CRITERION_KEYS` order (output index):

| Index | Key | Role |
|------:|-----|------|
| 0 | `sharpness` | high = sharper |
| 1 | `blur` | high = more blur |
| 2 | `noise` | high = more noise |
| 3 | `brightness` | luminance-related |
| 4 | `contrast` | contrast-related |
| 5 | `blocking_artifacts` | high = more blocking |
| 6 | `ringing_artifacts` | high = more ringing |

### Preprocessing

- EXIF-aware PIL load (`oriented_pil_image`)
- Resize **224×224** (`antialias=True`)
- ImageNet normalize mean `(0.485, 0.456, 0.406)`, std `(0.229, 0.224, 0.225)`
- Single global crop/resize (no multi-patch, no local grain/halo branch)

### Badge mapping (post-model; production)

`media_evaluator._photo_criteria` + `_soft_score`:

- Noise badge uses `_soft_score(1 - min(noise, 0.85))` (cleanliness)
- Ringing badge uses `_soft_score(1 - ringing_artifacts)`
- Soft bins: `boosted = clip(metric*0.5+0.42)` then thresholds 0.80/0.64/0.46/0.28 → 5…1

Any future head training should target the **continuous head polarity**, not invent new badge bins in the same pass.

### Existing trainer

`access_backend/scripts/train_efficientnet_heads.py`:

- Dataset: `SyntheticIQADataset` (solid-color 224×224 + rectangles/line + procedural blur/noise/brightness/contrast/JPEG/unsharp)
- Labels = degradation knobs / OpenCV stats, **not human MOS**
- Freezes `model.features`; optimizes `model.head` only (Adam 1e-3, MSE, default 640 samples × 4 epochs, CPU)
- **Maintenance defect:** imports `EfficientNetB0IQA` from the scorer module, but that class is **nested inside `_build_iqa_model()` and is not exported** (`hasattr(..., 'EfficientNetB0IQA') == False`). Re-running the trainer as written would fail until the class is exported or the trainer builds the model the same way as inference. Existing `.pt` still loads in production.

---

## 2. Can Noise and Ringing be retrained independently?

**Yes, technically.**

The shared object is one `Linear(1280, 7)`. Independence is by **row**, not by separate files:

- Freeze `features` (+ optionally `avgpool`, which has no trainable params beyond BatchNorm running stats already in the checkpoint)
- Freeze head rows for indices `{0,1,3,4,5}` (sharpness, blur, brightness, contrast, blocking)
- Train only rows/biases for indices `{2, 6}` (`noise`, `ringing_artifacts`)

Equivalent patterns:

1. **Parameter mask:** zero gradients on frozen head rows each step  
2. **Slice optimizer:** register only `head.weight[2]`, `head.weight[6]`, `head.bias[2]`, `head.bias[6]` as trainable  
3. **Two-output research head** on frozen 1280 features, then **copy rows back** into a full 7-way checkpoint without touching other rows

Any of these keeps the other five outputs numerically identical to production if those rows/biases are never updated and the backbone stays frozen.

**Trainable parameter count if only Noise+Ringing rows move:**  
`2 × 1280 + 2 = 2,562` parameters (vs 8,967 for the full head).

---

## 3. Can the backbone and other five heads remain exactly frozen?

**Yes.**

| Component | Freeze? | Notes |
|-----------|---------|-------|
| `features.*` | Required | Already frozen in the historical trainer |
| BatchNorm running stats in features | Keep eval/frozen | Do not refresh BN on new data unless explicitly approved |
| `head` rows 0,1,3,4,5 | Required | Leave weights/biases untouched |
| `head` rows 2,6 | Train | Noise + Ringing only |
| Soft-score / Flutter / FastAPI | Untouched | Out of scope |

Production deployment of a new `.pt` would still be a **separate product decision** after an independent test; this audit does not authorize that.

---

## 4. Training-data availability and label quality

| Source | Noise labels? | Ringing labels? | Usable for this retrain? |
|--------|---------------|-----------------|--------------------------|
| `SyntheticIQADataset` | Procedural `noise_amount` | Procedural unsharp `ringing_amount` | **No** as sole GT: same family that produced the failing heads |
| SPAQ attributes (local metadata present) | Human `Noisiness` 0–100 | **None** | Noise **proxy only** after invert; weak existing Spearman vs ACCESS Noise (~0.26 on SPAQ-200). No Ringing column |
| KonIQ / LIVE Challenge | Overall MOS only | No | Not criterion GT |
| ACCESS locked NR001–NR015 | Human medians exist | Human medians exist | **Forbidden** (train/tune/select) |
| ACCESS frozen 30-image pilot | Human ratings exist | Human ratings exist | **Forbidden** (optimization) |
| New ACCESS-rubric ratings (disjoint) | Would need collection | Would need collection | **Required** for a serious head retrain |

**Finding:** There is **no ready, leakage-safe, ACCESS-aligned Noise+Ringing ground-truth corpus** outside the locked sets. Ringing has **no** published SPAQ-style attribute in the project datasets. Synthetic labels are available but already shown insufficient for real-photo human agreement.

---

## 5. Risks specific to Noise and Ringing

1. **Global 224 pooled features:** Grain and edge halos are local. A single ImageNet global vector may lack the spatial evidence needed even if the linear rows are perfect. Head-only retrain can still fail M1-style gates.
2. **Construct mismatch:** Synthetic “noise amount” ≠ ACCESS Noise rubric; unsharp amount ≠ human Ringing (pilot/NR already showed classical and current ENET failures).
3. **Soft-score compression:** Even improved continuous ranks can collapse to 2–3 badges; evaluation must report raw head metrics and badges separately.
4. **Joint head history:** Current rows were co-trained with synthetic multi-task MSE; freezing five rows while moving two is sound, but initialization of rows 2/6 may be a poor local minimum for real photos.
5. **Label scarcity / IRR:** Ringing previously needed LIMITED CONSENSUS on NR15 (Fleiss κ ≈ 0.160). Weak labels → unstable head fit.
6. **Leakage temptation:** NR15/pilot-30 are the only ACCESS Noise/Ringing human sets on hand; using them for training would invalidate the independent claim.
7. **Trainer import defect:** Must be fixed before any research training run (export class or duplicate builder); do not “quick-fix” by writing over production `efficientnet_b0_heads.pt`.

---

## 6. Patches / extra features beyond the global backbone?

| Need | Assessment |
|------|------------|
| Current design | Global resize → 1280-D only |
| Noise | Often benefits from flat-region / multi-scale / patch statistics; global ENET may under-resolve fine grain after 224 downsampling |
| Ringing | Halo evidence is edge-local; global pool mixes it with content |

**Audit conclusion:** Isolated linear-head retrain is the **minimum** experiment and is worth considering **only after real labels exist**. If that fails on a proper holdout, the next architecture step is **not** more epochs on the same head, but a local/patch or multi-scale branch (new research track). Do not start that branch in this audit.

---

## 7. Leakage-safe split proposal (future; do not collect yet)

If product later approves a **new** labeled pool (suggested scale: hundreds of real photos with ACCESS Noise and Ringing medians from ≥3 raters; IRR gates before fitting):

| Split | Share | Use |
|-------|------:|-----|
| Train | ~70% | Fit Noise+Ringing head rows only |
| Development validation | ~15% | Early stopping, LR, loss form. **One** pass of choices |
| Independent test | ~15% | Frozen once; report M1-style metrics. No tuning |

**Hard exclusions from all splits:** NR001–NR015; frozen pilot-30; any image used to change the rubric after rating.

**Optional weak pretrain (explicitly secondary):** SPAQ noisiness → Noise row only, then fine-tune on ACCESS Noise labels. Never treat SPAQ as Ringing. Never mix synthetic labels into the human train split as if they were human GT.

**Write research checkpoints** under a new path (e.g. `tools/.../research_checkpoints/`), never overwrite `ml/efficientnet_b0_heads.pt` during experiments.

---

## 8. One recommended bounded head-only approach (if later approved)

**Name:** Research Noise+Ringing row retrain on frozen EfficientNet-B0 features  

1. Export `EfficientNetB0IQA` (or build identically to `_build_iqa_model`) in a **research** trainer; do not change production scoring.  
2. Load current `efficientnet_b0_heads.pt` as initialization.  
3. `requires_grad=False` for all `features` parameters and for head rows `{0,1,3,4,5}`.  
4. Optimize only indices `{2,6}` with MSE or smooth-L1 on continuous targets in the same polarity as the head (noise/ringing high = more artifact), mapped from human medians via a **pre-registered** 1–5→[0,1] map.  
5. Early-stop on development Spearman/MAE for Noise and Ringing separately.  
6. One locked independent test; compare to frozen production rows on the same test (paired).  
7. Stop. No badge remapping, no backbone unfreeze, no production swap in the same phase.

### Compute and runtime (estimate)

| Item | Estimate |
|------|----------|
| Device | CPU acceptable for 2,562 params; GPU optional |
| Memory | Similar to current ENET inference (~hundreds of MB) |
| Time | On the order of **minutes to a few hours** for a few thousand 224² samples × tens of epochs on CPU; dominated by **label collection**, not optimization |
| Storage | New research `.pt` ≈ 16 MB |

### Stopping criteria (pre-register before any train)

| Gate | Fail action |
|------|-------------|
| No disjoint ACCESS Noise+Ringing labels | **Do not train** |
| Dev Spearman vs human median &lt; 0.30 for either criterion | Stop; do not peek at independent test for retuning |
| Independent test fails the same spirit as locked M1 (ρ and significance) for either criterion | Keep production weights; archive research checkpoint |
| Any use of NR15 / pilot-30 in train/val/selection | Invalidate run |
| Change to the other five head rows or backbone | Out of scope; abort |

---

## 9. Clear GO / NO-GO decision

| Question | Decision |
|----------|----------|
| Is isolated Noise/Ringing head-row retraining **architecturally possible** while freezing backbone + five other outputs? | **YES** |
| Do suitable, leakage-safe Noise **and** Ringing ground-truth labels already exist for training? | **NO** |
| Should training start now? | **NO-GO** |
| Overall recommendation | **NO-GO for training.** Architecture is feasible later; data is the blocker. |

### Summary recommendation

Do **not** retrain EfficientNet Noise/Ringing heads yet. The shared `Linear(1280→7)` design supports a future **row-frozen** research retrain (~2.5k params) without touching the other five criteria, but the only ACCESS-aligned human Noise/Ringing labels on hand are **locked**, SPAQ lacks Ringing, and synthetic labels already failed.  

**Next approval-worthy step (separate from this audit):** collect a new disjoint ACCESS-rubric Noise/Ringing labeled set with IRR gates. Only then revisit the bounded head-only plan above.

---

*Stop here. Wait for approval before any training, weight write, or production change.*
