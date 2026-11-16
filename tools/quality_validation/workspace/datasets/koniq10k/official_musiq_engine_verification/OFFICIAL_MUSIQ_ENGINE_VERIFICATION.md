# Official MUSIQ engine verification (Phase 5)

**Status: complete.** Research comparison only. Production FastAPI, EfficientNet-B0, the seven technical criteria, `overall_score`, XP, recommendations, Flutter, React Admin, PostgreSQL, PROBE, WaveRep, and Gemini were not modified. The official engine was **not** deployed.

Generated: 2026-11-06T20:01:09Z  
Artifacts: `tools/quality_validation/workspace/datasets/koniq10k/official_musiq_engine_verification/`  
Script: `tools/quality_validation/official_musiq_engine_verification.py`  
Isolated venv: `tools/quality_validation/.venv_musiq_official/` (gitignored)

This is **not** a scientific validation of EfficientNet-B0, MUSIQ, or ACCESS technical badges. LIVEC was not used.

---

## Verdict (against predeclared tolerance)

| Gate | Threshold (frozen before judging) | Observed | Pass? |
|------|-----------------------------------|----------|-------|
| Success rate | 1.00 | **24 / 24** | yes |
| Pearson r | ≥ 0.999 | **0.99975** | yes |
| Spearman r | ≥ 0.999 | **0.99217** | **no** |
| mean \|diff\| | ≤ 0.50 | **0.0735** | yes |
| max \|diff\| | ≤ 2.0 | **0.263** | yes |
| Strict max \|diff\| | ≤ 0.05 | 0.263 | no |

**Primary equivalent: false** (Spearman 0.992 < 0.999).  
**Strict float equivalent: false.**

Numeric residuals are small on the 0–100-like scale (mean absolute difference **0.07**, RMSE **0.10**, max **0.26** on KONIQ-001). Rank correlation missed the 0.999 Spearman gate because several images sit within ~0.1 of each other, so tiny framework residuals swap adjacent ranks. Pearson still exceeds 0.999.

Do not treat this as a production swap. Do not loosen the gate after seeing the number.

---

## 1. Official source, checkpoint, dependencies, license

### 1.1 Code (established)

| Item | Finding |
|------|---------|
| Repository | `google-research/google-research/musiq` |
| License | **Apache License 2.0** (repo `LICENSE`; file headers on `run_predict_image.py`, `preprocessing.py`) |
| Inference entry | `python3 -m musiq.run_predict_image --ckpt_path=... --image_path=...` |
| Pinned deps (`musiq/requirements.txt`) | `flax==0.3.3`, `ml-collections==0.1.0`, `tensorflow>=2.0.0-beta1`, `jax>=0.1.55`, `jaxlib>=0.1.37`, plus chex/clu/einops/absl-py/numpy/pandas |
| Preprocess (GitHub) | JPEG decode, map **[0, 255] → [-1, 1]**, patch 32 / stride 32, `longer_side_lengths=[224, 384]`, native resolution with `max_seq_len_from_original_res=-1`, HSE grid 10 |
| Model (GitHub) | hidden 384, 14 transformer layers, 6 heads, 3 scales |

Repo README also states datasets *inside that GitHub tree* are **CC BY 4.0**. That clause does not license PaQ-2-PiQ / FLIVE / KonIQ / SPAQ / AVA training sets, and it does not by itself license GCS `.npz` files (those files are **not** in the git tree).

### 1.2 Weights: do not assume code license covers checkpoints

GCS listing `https://storage.googleapis.com/storage/v1/b/gresearch/o?prefix=musiq/` (2026-11-06) contains **only** `.npz` objects. There is **no** `LICENSE`, `NOTICE`, or README object next to:

- `musiq/paq2piq_ckpt.npz` (162,945,940 bytes, created 2021-12-01)
- siblings: `ava_ckpt.npz`, `koniq_ckpt.npz`, `spaq_ckpt.npz`, `imagenet_pretrain.npz`, plus `full_size_single_scale/` copies

**Production rights for `paq2piq_ckpt.npz` are not established.** Apache on the Python sources is not treated here as a weights license.

### 1.3 TF Hub / Kaggle SavedModel (separate artifact, license labeled)

Official notebook `musiq/Inference_with_MUSIQ.ipynb` (Apache header) loads:

`https://tfhub.dev/google/musiq/paq2piq/1`

Kaggle variation page `google/musiq` → TensorFlow2 / **paq2piq** / 1 states:

- **License: Apache 2.0**
- Output range **[0, 100]**
- “Exported using the released checkpoints … trained on PaQ-2-PiQ”
- Handle: `https://www.kaggle.com/models/google/musiq/TensorFlow2/paq2piq/1`

This is the weights artifact used in this run. It is **not** the pyiqa `.pth`. It is **not** the unlabeled GCS npz (npz was not downloaded).

Counsel still needs to review commercial use of a model **trained** on PaQ-2-PiQ / FLIVE, whose original dataset/code (`baidut/PaQ-2-PiQ`) is **CC BY-NC-SA 4.0**. That training-data term is separate from the TF Hub Apache label.

pyiqa 0.1.16 remains **PolyForm-Noncommercial**; converted `musiq_paq2piq_ckpt-364c0c84.pth` remains noncommercial. It was used only as the **saved reference CSV**, not re-run.

---

## 2. Can the official stack run on this CPU host?

Host: Windows 11, Python **3.12.10**, no CUDA.

| Path | Result |
|------|--------|
| GitHub `run_predict_image.py` + `paq2piq_ckpt.npz` + **flax==0.3.3** | **Not run.** Flax 0.3.3 was not present. A probe `pip install flax==0.3.3` resolved to **modern JAX 0.12**, not 2021 jax/flax, and was aborted so it would not pollute the TF venv. The 2021 `Model.partial` API is not a drop-in on current Flax. Historical jaxlib wheels for flax 0.3.3 are not a supported match for CPython 3.12 on Windows. **npz conversion was not attempted.** |
| Official TF Hub SavedModel + TensorFlow CPU | **Ran.** `tensorflow-cpu` / `tensorflow` **2.21.0**, `tensorflow-hub` **0.16.1**, `setuptools==80.9.0` (hub still imports `pkg_resources`; setuptools 84.2 failed with `ModuleNotFoundError: pkg_resources`). GPU hidden (`CUDA_VISIBLE_DEVICES=-1`). |

CPU environment **can** run the **TF Hub** official export. It **cannot** practically run the **2021 Flax npz** runner as pinned.

---

## 3. Isolated environment

Created `tools/quality_validation/.venv_musiq_official` from `requirements-musiq-official.txt`. Not installed into `access_backend`. TF Hub cache forced to the output `cache/tfhub/` folder.

---

## 4. Sample (existing KonIQ, not LIVEC)

Read-only pyiqa CSV: `workspace/datasets/koniq10k/musiq_paq2piq_benchmark/raw_predictions.csv` (Phase 2, 140 ok rows).

- n = **24**
- seed = `20261107_engine`
- Quintile sample of pyiqa raw scores, then sorted by `run_id`, `media_id`
- 6 images from Run 001, 18 from Run 002
- Same JPEG paths as Phase 2

---

## 5. Preprocessing and inference settings

| | pyiqa research (saved) | Official TF Hub (this run) |
|--|------------------------|----------------------------|
| Metric | `musiq-paq2piq` | `tfhub.dev/google/musiq/paq2piq/1` |
| Input | RGB tensor [0,1] → [-1,1], multi-scale patches 32, sides [224, 384] + native | **Raw JPEG bytes** (`tf.constant` of file bytes). Hub docs: no caller-side resize. Internal graph not dumped. |
| Device | CPU (torch 2.15) | CPU (TF 2.21 + XLA host) |
| Calibration | none | none |
| Checkpoint conversion | Hugging Face `.pth` (pyiqa) | Google SavedModel export |

No npz→pth conversion was performed in this phase.

---

## 6. Inference time (CPU)

| Item | Value |
|------|-------|
| Official ok | **24 / 24** |
| Failures | **0** |
| Model load | **14.4 s** (cached Hub after smoke) |
| Mean including first compile | **1986 ms/image** |
| First image (XLA compile) | **9961 ms** (KONIQ-001) |
| Mean excluding first | **~1639 ms/image** |

Phase 2 pyiqa CPU was ~1.62 s/image on 140 files; LIVEC mean was 0.66 s/image after warmup. Official TF CPU here is the same order (~1.6 s after compile), still too slow for a fully synchronous upload without a queue or GPU.

---

## 7. Distributions and differences (n=24)

| Series | min | max | mean |
|--------|-----|-----|------|
| pyiqa raw | 59.130 | 77.299 | 72.183 |
| official raw | 59.141 | 77.287 | 72.158 |

| Statistic | Value |
|-----------|-------|
| Pearson r | **0.99975** (p ≈ 9e-38) |
| Spearman r | **0.99217** (p ≈ 2e-21) |
| mean \|diff\| | **0.0735** |
| max \|diff\| | **0.263** (KONIQ-001: 75.405 vs 75.668) |
| RMSE | **0.102** |

Largest residuals also include KONIQ-003 (0.252) and KONIQ2-034 (0.146). Closest: KONIQ2-041 (0.0003).

---

## 8. Equivalence rule (declared before judging)

Stored in `equivalence_tolerance.json`:

- Pearson ≥ 0.999
- Spearman ≥ 0.999
- mean abs diff ≤ 0.50
- max abs diff ≤ 2.0
- strict max abs diff ≤ 0.05
- success rate = 1.0

**Judgement:** not primary-equivalent because Spearman missed 0.999. Absolute errors would have passed the primary MAE/max gates. Strict float equality failed.

---

## 9. Incompatibilities and licensing limits

1. **GCS `paq2piq_ckpt.npz`:** no accompanying license object. Not used. Not cleared for production.
2. **GitHub Flax 0.3.3 runner:** incompatible with this Python 3.12 Windows CPU environment without an old, unsupported jax/flax pin that was not installed.
3. **tensorflow-hub 0.16.1:** requires `pkg_resources` (pin `setuptools==80.9.0`). Setuptools 84 broke import.
4. **pyiqa `.pth`:** still noncommercial; engine agreement is **close but not** within the Spearman 0.999 gate.
5. **PaQ-2-PiQ training data CC BY-NC-SA:** remaining counsel question even if TF Hub labels the SavedModel Apache 2.0.
6. **AVA TF Hub variant:** wrong task (aesthetics 1–10). Not used.
7. **KonIQ TF Hub / `koniq_ckpt.npz`:** KonIQ-trained; forbidden for this KonIQ image pack.

---

## 10. Production

Unchanged. Official MUSIQ was not copied into `access_backend/ml/`. Feature flags were not added.

---

## Reproduce (research venv only)

```powershell
cd C:\Users\Dell\Desktop\access_mobile
.\tools\quality_validation\.venv_musiq_official\Scripts\python.exe `
  tools\quality_validation\official_musiq_engine_verification.py
```

Stopped for review.
