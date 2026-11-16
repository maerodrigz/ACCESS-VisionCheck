# Phase 6B — Online Human Quality Evaluation Portal

Lightweight FastAPI + mobile-friendly static UI for the Phase 6A **100-image** independent holdout (`INDVAL-001`…`100`).

- Independent of MUSIQ Docker worker and production FastAPI quality scoring
- Three isolated evaluator invites (R1/R2/R3)
- Autosave, resume, zoom, completion summary, final submit lock
- Facilitator CSV export compatible with `generate_phase6a_consensus.py`
- Does **not** fabricate ratings

## Quick local start

```powershell
cd tools\quality_validation\phase6b_rating_portal
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
python scripts\generate_secrets.py --write-env .env
$env:IMAGES_DIR = (Resolve-Path ..\workspace\phase6a_human_validation\rater_pack\images).Path
# Load .env values into the process, or rely on pydantic env_file
.\.venv\Scripts\uvicorn app.main:app --host 127.0.0.1 --port 8090
```

Open the printed `/r/<token>` links.

## Important docs

- `BISAYA_RUBRIC_REVIEW.md` — facilitator approval flags for Bisaya copy
- `DEPLOYMENT.md` — HTTPS / Fly.io steps
- Phase 6A package: `../workspace/phase6a_human_validation/`

## Constraints honored

No changes to production FastAPI quality evaluation, Flutter, PROBE-DINOv2, WaveRep G4, or frozen Phase 6A scoring configuration.
