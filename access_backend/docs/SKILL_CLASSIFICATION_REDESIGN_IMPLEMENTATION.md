# Quality-based skill classification — implementation notes

## Admin override vs member tiers (unchanged behavior)

| Layer | Levels | Source |
|-------|--------|--------|
| **Member skill tier (rankings / profile)** | Beginner, Intermediate, Advanced, **Expert** | `effective_skill_level` + optional admin override |
| **Admin competency override API** | Beginner, Intermediate, Advanced **only** | `member_rankings.competency_level_override` via `PATCH /api/rankings/{id}/competency-level` |
| **Admin recommended competency** | 3 bands (Expert score → recommended **Advanced**) | `competency_level_from_skill_score` |

When an override is set, it **wins** for `users.skill_level_id` until cleared. A member may **compute** as Expert while an admin override displays Advanced. This mismatch was pre-existing; override behavior was **not** changed in this redesign.

## Formula

- **Before:** `skill_score = 0.7 × media_quality + 0.3 × ai_authenticity` (all practice eval averages).
- **After:** `skill_score = eligible_practice_media_quality` (0–100), using `skill_evaluation_eligibility.py`.

XP (`member_rankings.total_points`), AI detection rows, review workflow, and stored `media_evaluations` scores are **unchanged**.

## Eligibility (centralized)

`practice_evaluation_eligible_for_skill` + `eligible_skill_evaluation_stats`:

- `media_category = member_evaluation`
- `member_may_view_scores` (existing release / integrity gating)
- Excludes pending, withheld, rejected, reupload, confirmed AI review statuses
- Excludes zero scores and `ai_detection.verdict` of AI-generated

## Batch recalculation

**Not run automatically.** Persisted `users.skill_level_id` updates only when `recalculate_skill_level` runs (new eval, admin review, or a future approved batch job).

Preview report (read-only):

```bash
cd access_backend
python scripts/_readonly_skill_tier_formula_preview.py
```

Output: `backups/skill_formula_preview/skill_tier_old_vs_new.csv`

## Tests

- `tests/test_skill_scoring.py`
- `tests/test_skill_evaluation_eligibility.py`
- `tests/test_rankings_admin_skill_override.py`
