# Phase 4B: Live MUSIQ restore attempt

**Status:** blocked (runtime restored at package level; native load refused by OS policy)  
**Freeze id:** `phase4a_freeze_20261113` (unchanged)  
**Date:** 2026-11-13  
**Live MUSIQ on holdout:** **0 / 100** (full run refused after failed 3-image smoke)  
**Human ratings:** not collected; MUSIQ validation is **not** complete.

Production EfficientNet-B0, hybrid thresholds, feedback rules, API, XP, Flutter, DB, PROBE-DINOv2, WaveRep G4, and `QUALITY_SHADOW_ENABLED` were **not** changed. Shadow remains **false** (default / `.env.example`).

---

## Root cause

### Layer A (Phase 4B machine eval)

Live MUSIQ was unavailable because the scoring interpreter had **no importable `tensorflow`** (backend venv and `.venv_musiq_official_phase1` had `tensorflow_hub` only). Error recorded in per-image JSON:

`MUSIQ runtime unavailable: tensorflow / tensorflow_hub not installed in this environment`

### Layer B (this restore attempt)

An isolated research venv was created and packages installed successfully:

| Package | Version |
|---------|---------|
| Python | 3.12.10 (Win11 10.0.26200) |
| tensorflow | 2.21.0 |
| tensorflow-hub | 0.16.1 |
| numpy | 2.2.6 |
| setuptools | 80.9.0 |

`import tensorflow` then fails:

`DLL load failed while importing _dtypes: An Application Control policy has blocked this file.`  
(`OSError` / WinError **4551**)

Windows Code Integrity Operational log (events **3033** / **3077**) states the load of  
`...\.venv_musiq_phase4b\Lib\site-packages\tensorflow\python\framework\_dtypes.pyd`  
did not meet **Enterprise signing level** requirements.

Registry: `HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy`

| Value | Observed |
|-------|----------|
| `VerifiedAndReputablePolicyState` | **1** (enforcement) |
| `SAC_PreviousState` | 2 |
| `SAC_EnforcementReason` | 1 |

NumPy / Pillow load normally; only TensorFlow native `.pyd` is blocked. This matches Smart App Control / Verified-and-Reputable Code Integrity enforcement, not a missing pip package.

A prior research run on this host (2026-11-06/07) successfully used TF 2.21.0 + the same TF Hub handle when SAC was not yet enforcing (`SAC_PreviousState=2`).

---

## Dependency / runtime changes made

| Change | Detail |
|--------|--------|
| New venv | `tools/quality_validation/.venv_musiq_phase4b/` |
| Installed | `tensorflow==2.21.0`, `tensorflow-hub==0.16.1`, `numpy<2.3`, Pillow, scipy, pandas, `setuptools==80.9.0` |
| Runner | `tools/quality_validation/run_phase4b_live_musiq.py` (MUSIQ-only; separate output dir) |
| Not changed | production venv, API, shadow flag, freeze, `machine_scores.csv` |

---

## Model provenance and licensing

| Item | Value |
|------|-------|
| Handle | `https://tfhub.dev/google/musiq/paq2piq/1` |
| Model id | `tfhub:google/musiq/paq2piq/1` |
| Local cache | `.../official_musiq_engine_verification/cache/tfhub/a5e1c51ceccb5074aa6e1ed774b7ba4f4c79bbee/` |
| Descriptor | Downloaded 2026-11-07 on `DESKTOP-QFC7BS8` |
| `saved_model.pb` | 221,131,781 bytes; SHA-256 `593a91775a8455c2f12c0dad4ecefeb19cc770db89c695022a29c51adae86b3b` |
| Variables shard | 82 bytes (metadata stubs; weights carried in SavedModel protobuf for this Hub export) |
| TF Hub / Kaggle license label | **Apache 2.0**; output declared **[0, 100]** |
| GCS `paq2piq_ckpt.npz` | **Not used** (weights license not established) |
| Training-data note | PaQ-2-PiQ / FLIVE upstream dataset/code is **CC BY-NC-SA 4.0**; counsel should review commercial use |
| pyiqa | **Not substituted**; historical CSV not used |

No alternate MUSIQ implementation or model variant was switched in.

---

## Three-image smoke test

| Image | Status | Score | Finite | Deterministic repeat |
|-------|--------|-------|--------|----------------------|
| INDVAL-001 | unavailable | null | no | no |
| INDVAL-002 | unavailable | null | no | no |
| INDVAL-003 | unavailable | null | no | no |

Smoke **failed**. Full 100-image live run was **not** started (policy: refuse holdout after failed smoke). Cached historical MUSIQ scores were **not** substituted.

---

## Holdout live predictions

**0 / 100** successful live predictions (run gated).

---

## Research output paths

| Path | Role |
|------|------|
| `workspace/phase4a_indval/machine_output/musiq_live_20261113T134900Z_restore_attempt/` | Versioned restore attempt |
| `.../run_meta.json` | Env, artifact inventory, smoke summary, blocker |
| `.../smoke_test_3.json` | Per-image smoke detail |
| `.../env_and_artifact_probe.json` | TF/Hub/cache probe |
| `workspace/phase4a_indval/machine_output/machine_scores.csv` | **Preserved** (SHA-256 `9145890EA08C815D9A32CF0BC0865B2E5E737D384CBD29D9B48D39A7DFDC9FC6`) |
| `phase4a_freeze_manifest.json` | **Preserved** |

---

## Remaining blocker and recommended resolution

**Blocker:** Windows Code Integrity / Smart App Control enforcement blocks loading unsigned TensorFlow `_dtypes.pyd` (WinError 4551; CI events 3033/3077). Packages are installed; inference cannot start.

**Environment-specific options (operator action required):**

1. **Preferred on this PC:** Set Smart App Control to Off or Evaluation (Windows Security → App & browser control → Smart App Control), reboot if required, then re-run:
   ```text
   tools\quality_validation\.venv_musiq_phase4b\Scripts\python.exe ^
     tools\quality_validation\run_phase4b_live_musiq.py
   ```
   Output will land under a new `musiq_live_<timestamp>/` directory without overwriting `machine_scores.csv`.

2. **Alternate:** Install a WSL2 distro and run the same official TF Hub PaQ-2-PiQ path under Linux (WSL is present but **no distro** is installed today).

3. **Enterprise:** Add a Code Integrity allow rule for the research venv TensorFlow path / publisher (IT-managed).

Do **not** bypass by substituting pyiqa, GCS npz, or historical CSVs. Do **not** claim MUSIQ or hybrid validation complete without human reference ratings.
