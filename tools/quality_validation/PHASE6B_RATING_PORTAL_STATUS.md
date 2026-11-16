# Phase 6B Online Rating Portal — Status

**Date:** 2026-11-14  
**Code location:** `tools/quality_validation/phase6b_rating_portal/`  
**Public HTTPS:** **not deployed / not verified.** Cloud packaging for Cloudflare Pages + Supabase Free is implemented under `phase6b_rating_portal/cloud/` (see `cloud/DEPLOY_CLOUDFLARE_SUPABASE.md`).

## Completed

- Separate lightweight FastAPI + static mobile UI (no MUSIQ / no production quality engine)
- Server-side evaluator isolation via invite → session → `evaluator_id`
- Authenticated image serving for `INDVAL-001`…`100`
- Eight criteria with Modern Bisaya + locked English prompts
- Circular 1–5 controls, N/A, autosave, Previous / Save & Next, resume, zoom/pan
- Completion summary + final submit lock
- Facilitator CSV export (Phase 6A consensus-compatible columns)
- Local pytest coverage for isolation, image auth, export
- Fly.io Dockerfile + `DEPLOYMENT.md`
- Bisaya vs locked rubric discrepancy flags in `BISAYA_RUBRIC_REVIEW.md`

## Not completed (requires facilitator / hosting)

- Facilitator approval of Bisaya wording flags
- Generating production invite secrets and distributing links
- Actual Fly (or other) deploy + external HTTPS verification
- Collection of human ratings (none fabricated)

## Facilitator must provide

1. Hosting account (Fly.io recommended)  
2. `EVALUATOR_INVITES` and `FACILITATOR_TOKEN` (from `scripts/generate_secrets.py`)  
3. Approval on `BISAYA_RUBRIC_REVIEW.md` before rating starts  

## Constraints

Production FastAPI quality scoring, Flutter, PROBE-DINOv2, WaveRep G4, and Phase 6A freeze artifacts were not modified for scoring behavior.
