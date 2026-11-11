# Pretrained Noise and Ringing Detector Feasibility Assessment

**Date:** 2026-11-09  
**Status:** Research only. Awaiting approval before any download, install, or test run.  
**Context:** Independent NR001–NR015 validation finished **KEEP UNVALIDATED / NO-GO**. Locked ratings and images must not be used for model selection or tuning.

---

## 1. Existing detector limitations

### Production path (FastAPI)

| Piece | Location | Behavior |
|-------|----------|----------|
| Primary scorer | `access_backend/app/services/efficientnet_b0_scorer.py` | ImageNet EfficientNet-B0 + 7-head sigmoid regression (`ml/efficientnet_b0_heads.pt`) |
| Fallback | `access_backend/app/services/opencv_quality.py` | Classical Laplacian residual noise; Canny-edge oscillation ringing |
| Mapping | `media_evaluator._photo_criteria` + `_soft_score` | Continuous `[0,1]` → badge 1–5 via fixed soft bins (`metric*0.5+0.42`) |
| Storage quirk | `quality_score_display` | DB `noise_score` stores `1 - Noise/5` (inverted vs other criteria) |
| Runtime deps | PyTorch + torchvision + PIL; OpenCV for fallback | CPU-capable; model already loaded in production path |

EfficientNet emits separate `noise` and `ringing_artifacts` channels, but they are **joint multi-task heads on a general quality backbone**, not artifact-specialized estimators. On NR001–NR015, C-prod failed M1 for both criteria (near-zero / negative Spearman).

### Research classical path (already exhausted for this cycle)

Frozen candidates C-v2 / C-combined (Noise v2, Ringing v2/v3) and later Noise/Ringing v4 diagnostics all failed human rank alignment. Shared failure modes:

- **Noise:** texture leakage or over-clean ceilings; residual / PCA σ̂ does not track ACCESS perceptual Noise.
- **Ringing:** sharp clean edges vs bipolar halos confused; v3/v4 harsh floors; no validated halo-specific pretrained alternative in-repo.

**Implication:** Another classical retune on locked sets is out of scope. Only externally pretrained, documented approaches are considered here, and only behind a bounded feasibility gate.

---

## 2. Candidate comparison table

| ID | Criterion target | Measures required artifact directly? | Pretrained weights | PyTorch | License (practical) | FastAPI fit | Verdict |
|----|------------------|--------------------------------------|--------------------|---------|---------------------|-------------|---------|
| **CLIP noisiness antonyms** (CLIP-IQA paper method) | Noise | **Yes** (documented fine-grained noisiness via antonym prompts) | OpenAI CLIP / OpenCLIP ViT or RN50 | Yes | CLIP weights commonly usable; **IceClear CLIP-IQA code + pyiqa wrappers are non-commercial** | Medium: new dep + ~150–340 MB weights; CPU OK but slower | **Top Noise candidate** if implemented **without** pyiqa / IceClear redistribution |
| **LIQE** (Zhang et al., CVPR 2023) | Noise (partial) | **Partial**: predicts dominant distortion type including `noise`, plus overall quality | Official Google Drive `LIQE.pt` | Yes | **Official repo MIT** | Medium: CLIP ViT-B/32 + checkpoint; CPU feasible | **Second Noise candidate**; categorical type ≠ continuous Noise badge |
| CBDNet noise-estimation subnet | Noise (σ map) | Partial: blind noise-level map for denoising, not ACCESS Noise rubric | Official MatConvNet; unofficial PyTorch ports | Yes (ports) | Apache-2.0 official; MIT unofficial ports | Medium–high integration cost; port provenance risk | Credible BNE, weaker perceptual fit |
| FBCNN predicted JPEG QF | Ringing? | **No**: JPEG quality / mixed blocking+ringing proxy | Yes (`fbcnn_color.pth`) | Yes | Apache-2.0 | Easy-ish CNN | **Reject for Ringing** (and Blocking already covered elsewhere) |
| WASD SR artifact mask | Ringing? | **No** for ACCESS: needs LR+SR pair | Hugging Face | Yes | Check model card | Poor API fit | **Reject** |
| MANIQA / HyperIQA / TOPIQ / general NR-IQA | Both? | **No**: single overall MOS-like score | Often via pyiqa | Yes | Many **pyiqa weights CC BY-NC-SA**; HyperIQA official MIT but still overall IQA | Heavy | **Reject as Noise/Ringing substitutes** |
| Dedicated ringing / oversharpening net | Ringing | **None found** with usable single-image pretrained severity head for general photos | — | — | — | — | **None credible** |

Hard rule applied: a general quality model is **not** counted as a separate Noise or Ringing detector.

---

## 3. Verified model sources and licenses

| Candidate | Paper / docs | Weights source | Code license | Weights / packaging caveats |
|-----------|--------------|----------------|--------------|-----------------------------|
| CLIP-IQA method | Wang, Chan, Loy, AAAI 2023, [arXiv:2207.12396](https://arxiv.org/abs/2207.12396) | Base CLIP checkpoints (OpenAI / OpenCLIP) | IceClear repo: **NTU S-Lab non-commercial**; pyiqa: **PolyForm-NC** + weights often **CC BY-NC-SA** | Feasibility must use **OpenCLIP or OpenAI CLIP + local antonym scoring**, not pyiqa `create_metric('clipiqa')`, if a commercial path is ever contemplated |
| LIQE | Zhang et al., CVPR 2023, [paper](https://openaccess.thecvf.com/content/CVPR2023/html/Zhang_Blind_Image_Quality_Assessment_via_Vision-Language_Correspondence_A_Multitask_Learning_Perspective_CVPR_2023_paper.html) | [Google Drive LIQE.pt](https://drive.google.com/file/d/1GoKwUKNR-rvX11QbKRN8MuBZw2hXKHGh/view) | Official [zwx8981/LIQE](https://github.com/zwx8981/LIQE): **MIT** | Prefer official MIT path over pyiqa `liqe` packaging |
| CBDNet | Guo et al., CVPR 2019 | Official `.mat`; PyTorch community ports | Official **Apache-2.0** | Prefer documented port + checksum if ever tested |
| FBCNN | Jiang et al., ICCV 2021 | GitHub releases | **Apache-2.0** | Useful for JPEG QF only; not Ringing |

---

## 4. Best candidate for Noise (if any)

### Primary: CLIP noisiness antonyms (method from CLIP-IQA)

**Why**

- Paper explicitly evaluates fine-grained **noisiness**, not only overall good/bad.
- pyiqa’s CLIP-IQA prompt list includes `Noise-free image` / `noisy image` as a dedicated pair; that continuous softmax score maps more naturally to ACCESS Noise than a generic MOS.
- Backend already runs PyTorch; no need to replace EfficientNet for a first feasibility probe.

**Limitations**

- Prompt sensitivity and linguistic ambiguity remain.
- Texture, compression grain, and ISO noise may be conflated.
- Official CLIP-IQA / pyiqa stacks are **non-commercial**; any isolated test should use OpenCLIP/OpenAI CLIP + local prompt pairing only.
- Still not ACCESS-rubric trained; synthetic success ≠ human validation.

### Secondary: LIQE (official MIT)

**Why**

- Distortion-aware BIQA with an explicit **`noise`** class among eleven distortion types.
- Official MIT code + published weights; better license posture than pyiqa.

**Limitations**

- Primary outputs are overall quality + **argmax distortion type**, not a calibrated 1–5 Noise cleanliness scale.
- Useful as a diagnostic prior (“is noise the dominant distortion?”) more than as a drop-in Noise badge.

**Not ranked in top two for this report:** CBDNet (σ̂ useful, perceptual mapping weak, MatConvNet/port friction).

---

## 5. Best candidate for Ringing (if any)

### None.

No technically credible **pretrained, single-image, ringing/oversharpening severity detector** with documented weights was found that:

1. Targets ringing/halos specifically (not overall quality or JPEG QF), and  
2. Applies to ordinary photographs without an LR/reference pair, and  
3. Is practical to wire beside the FastAPI stack without inventing a new task head.

Rejected substitutes:

- **FBCNN QF:** compression severity; mixes blocking and ringing.
- **WASD:** SR artifact localization; requires source LR.
- **General NR-IQA / CLIP overall quality:** used elsewhere as a coarse filter for haloing tiles, but that is a **proxy**, not a Ringing criterion model.
- **Classical Ringing v2–v4:** already failed; not pretrained.

**Report clearly:** do not pretend a general IQA or JPEG model is a Ringing detector.

---

## 6. CPU / GPU feasibility

| Item | Estimate |
|------|----------|
| Current prod EfficientNet-B0 | Already CPU-deployed in ACCESS |
| CLIP ViT-B/32 noisiness probe | ~150–340 MB weights; roughly 0.3–2 s/image CPU, much faster on GPU |
| LIQE (CLIP + joint text bank) | Similar or slightly heavier than plain CLIP-IQA (many text templates, multi-patch) |
| CBDNet / FBCNN | Smaller CNNs; CPU-friendly if a clean port is used |
| FastAPI practicality | Feasible as an **isolated research sidecar**, not as an in-request replacement without latency budgeting |

For a one-shot feasibility test, CPU-only is acceptable if the image count stays small (tens, not thousands).

---

## 7. Proposed next test (bounded; approval required)

### Scope

**Single isolated Noise feasibility test only.**  
No Ringing pretrained track. No production, Flutter, sandbox scoring, weight, or criteria changes. No NR001–NR015, no frozen 30-pilot, no SPAQ re-fit.

### Materials (new only)

1. **Controlled sanity set (required):**  
   - AWGN ladder on flat + mild-texture panels: σ ∈ {0, 5, 10, 20, 40}  
   - Clean high-texture panel without added noise (false-harsh check)  
   - Optional chroma-noise / JPEG-only ladders as diagnostics (must not be used to claim Noise success alone)
2. **Optional small real development set:** ≤12 open-license photos **disjoint** from NR001–NR015 and the pilot-30, with known qualitative noise notes (not full three-rater protocol yet).

### Candidate under test

- **Only:** CLIP noisiness antonym score (OpenCLIP or OpenAI CLIP + fixed prompt pair).  
- **Optional parallel diagnostic (not a second promotion track):** LIQE `noise` probability / type flag, reported separately.

### Pre-registered stopping criteria

| Gate | Pass | Fail action |
|------|------|-------------|
| S1 Monotone AWGN | Spearman(score_noise_amount, σ) ≥ 0.80 on flat ladder | **STOP**; abandon CLIP noisiness for ACCESS |
| S2 Texture false-harsh | Clean textured σ=0 scored as “noisy” no worse than AWGN-5 equivalent | **STOP** or mark unavailable |
| S3 Dispersion | ≥3 distinct mapped bins on combined ladders | Fail → no further review |
| S4 No locked-set peek | Confirmed unused NR/pilot ratings | Process fail |
| S5 Synthetic≠success | Even if S1–S3 pass, outcome is only “eligible for a later disjoint human micro-study” | Do not promote |

**Estimated runtime after approval:** weight download once (~5–15 min depending on network) + controlled ladder inference **≈10–30 minutes CPU** (or a few minutes GPU) + write-up. Cap wall time at **2 hours**; stop if packaging/license/runtime blocks appear.

**Explicit non-goals:** no threshold fitting on any human-rated ACCESS set; no Noise v5 / Ringing v5 module names; no production hook.

---

## 8. GO / NO-GO for one isolated feasibility test

| Track | Recommendation |
|-------|----------------|
| Noise pretrained probe (CLIP noisiness antonyms, isolated) | **GO** — single bounded test after approval |
| Ringing pretrained probe | **NO-GO** — no credible dedicated pretrained detector |
| Production / Flutter / scoring changes | **NO-GO** |
| Using NR001–NR015 or pilot ratings for selection | **NO-GO** |
| Downloading models in this session | **NO-GO** until explicit approval |

### Final recommendation

**Approve one isolated Noise feasibility test of CLIP noisiness antonyms (non-pyiqa implementation path).**  
**Do not open a Ringing pretrained workstream.**  
Even a Noise S1–S3 pass only unlocks a later disjoint human micro-study; it does **not** authorize production deployment.

---

*Stop here. Wait for approval before implementing or running any candidate.*
