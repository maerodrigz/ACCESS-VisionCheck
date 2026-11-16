# Phase 4A: Independent Validation Preparation

Research-only. Does not enable production shadow scoring or change EfficientNet/PROBE/WaveRep/UI/XP.

## Deliverables map

| Deliverable | Path |
|-------------|------|
| Dataset selection report | `PHASE4A_DATASET_SELECTION_REPORT.md` |
| Frozen protocol | `PHASE4A_FROZEN_PROTOCOL.md` |
| Freeze manifest | `phase4a_freeze_manifest.json` |
| Holdout selector | `select_phase4a_holdout.py` |
| Machine eval runner | `run_phase4a_machine_eval.py` |
| Human pack builder | `prepare_phase4a_human_packs.py` |
| Analysis script | `analyze_phase4a_results.py` |
| Issue taxonomy | `phase4a_issue_taxonomy.py` |
| Chapter 4 templates | `PHASE4A_CHAPTER4_RESULT_TEMPLATES.md` |
| Working outputs | `workspace/phase4a_indval/` |

## Quick start

```bash
cd tools/quality_validation
python select_phase4a_holdout.py
python run_phase4a_machine_eval.py          # or --skip-musiq / --skip-enet
python prepare_phase4a_human_packs.py --copy-images
# ... human rating ...
python analyze_phase4a_results.py
```

## Remaining before actual evaluation is “done”

1. Three raters submit complete image-quality, issue-label, and feedback-quality sheets.
2. Machine eval completed under freeze id `phase4a_freeze_20261113`.
3. Analysis run **without** `--allow-empty`.
4. Optional but recommended: ACCESS-native photo pack for ecological validity.
