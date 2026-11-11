# Research-only CLIP noisiness feasibility

Isolated one-time test of CLIP-IQA-style noisiness antonyms (OpenCLIP ViT-B/32 + fixed prompts).  
**Does not modify production, Flutter, EfficientNet, sandbox scoring, or locked NR validation assets.**

## Result

See `CLIP_NOISE_FEASIBILITY_REPORT.md` → **NO-GO**.

## Layout

| Path | Role |
|------|------|
| `MODEL_PREFLIGHT.md` | License / size / dep check before download |
| `clip_noisiness.py` | Minimal antonym scorer |
| `build_dev_set.py` | Synthetic DEV-FLAT / DEV-MILD / DEV-TEX + AWGN ladder |
| `run_feasibility.py` | Single controlled run |
| `dev_set/` | Generated development images |
| `output/` | Timestamped CSV / JSON / report copies |

Do not re-run for prompt or model shopping without a new approved plan.
