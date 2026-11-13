# Phase 3: Research-Only Rule-Based Feedback (Hybrid NR-IQA)

**Status:** implemented as research-only. Not shown in Flutter / admin UI.  
**Do not claim accuracy** until independently validated.

Production `media_evaluator` feedback templates, Gemini coaching, XP, recommendations, badges, and DB `criteria_json` / `feedback` fields are **unchanged**.

## Files created / modified

| Path | Role |
|------|------|
| `app/services/quality_shadow/feedback_rules.py` | Documented thresholds + observation templates |
| `app/services/quality_shadow/feedback_generator.py` | Generator with sharpness/blur dedupe |
| `app/services/quality_shadow/scoring.py` | Attaches `experimental_feedback` to shadow records |
| `app/services/quality_shadow/logging_store.py` | JSONL/CSV include experimental feedback |
| `tests/test_quality_shadow_feedback.py` | Unit tests |
| `docs/samples/SAMPLE_experimental_feedback.json` | Sample output |
| `docs/samples/PHASE3_HUMAN_FEEDBACK_EVAL_TEMPLATE.csv` | Human feedback-quality rating sheet |
| `docs/PHASE3_HYBRID_FEEDBACK_RESEARCH.md` | This document |

## Feedback rule definitions

Ruleset id: `hybrid_feedback_rules_v1`.

### Continuous q bands (higher = better)

| Band | Condition | Meaning |
|------|-----------|---------|
| severe | `q < 0.25` | Strong issue observation |
| moderate | `0.25 ≤ q < 0.45` | Moderate issue |
| mild | `0.45 ≤ q < 0.65` | Mild issue |
| no_issue | `q ≥ 0.65` | Maintain / no issue text |

Applied to: sharpness, blur, brightness, contrast, blocking_artifacts.

These cut points are **not** EfficientNet `_soft_score` thresholds (`0.80 / 0.64 / 0.46 / 0.28` on boosted metrics).

### Color heuristic badges

| Band | Condition |
|------|-----------|
| unavailable | `available == false` (no fabricated cast/sat claim) |
| severe | badge ≤ 2 |
| moderate | badge == 3 |
| mild | badge == 4 |
| no_issue | badge ≥ 5 |

### Sharpness / blur policy

Both use the same Laplacian quality axis. The generator **always suppresses** blur observations when sharpness was scored, recording `observation_kind=suppressed_duplicate` so evaluators can audit dedupe without contradictory tips.

### MUSIQ

Logged under `musiq_context` only. **Never** used to generate criterion observations or user recommendations.

## Observation record schema

Each observation includes: criterion, raw measurement + key, q (when applicable), rule_id, rule_description, threshold, observation, suggested_improvement, observation_kind, confidence / uncertainty, suppression flags.

## Sample experimental feedback

See `docs/samples/SAMPLE_experimental_feedback.json`.

## Human evaluation template

`docs/samples/PHASE3_HUMAN_FEEDBACK_EVAL_TEMPLATE.csv`

Columns:

- `media_anon_id`, `criterion`, `system_observation`, `rule_triggered`
- `reference_issue_identified_by_human` (independent label; empty if none)
- `observation_correctness_1to5`, `recommendation_relevance_1to5`, `clarity_1to5`, `usefulness_1to5`

**Important:** these 1–5 ratings score **feedback quality**, not image quality. Use the existing human image-quality protocol separately when judging photo criteria.

## Issue-level precision / recall / F1

Define a finite issue vocabulary, e.g.  
`{soft_focus, bad_exposure, low_contrast, blocking, color_cast, bad_saturation}`.

For each image and issue class \(c\):

1. **Human reference** \(R\): set of classes the independent evaluator marks present.
2. **System prediction** \(P\): set of classes mapped from non-suppressed `observation_kind=issue` rows (map rule_ids → classes; ignore `no_issue` / `unavailable` / `suppressed_duplicate`).

Then over the evaluation set:

\[
\mathrm{Precision} = \frac{|P \cap R|}{|P|},\quad
\mathrm{Recall} = \frac{|P \cap R|}{|R|},\quad
F_1 = \frac{2\cdot\mathrm{Precision}\cdot\mathrm{Recall}}{\mathrm{Precision}+\mathrm{Recall}}
\]

Report micro and macro averages. Do **not** count MUSIQ OPQ as an issue class. Softened “mild” bands may be analyzed in a sensitivity table (include vs exclude mild).

Likert means for correctness / relevance / clarity / usefulness are reported separately from P/R/F1.

## How to collect (research)

1. Keep `QUALITY_SHADOW_ENABLED=false` in production.
2. On a research host only, enable shadow, capture JSONL with `experimental_feedback`.
3. Export observations into the human template (one row per criterion per image).
4. Blind raters to production ENET feedback when scoring feedback quality.
5. Compute P/R/F1 + Likert summaries offline.

## Limitations and next validation requirements

- Rules are a priori / heuristic; not fitted or validated on ACCESS officer labels.
- Sharpness/blur share one detector; blur is suppressed by design.
- Color rules reuse production heuristic badges (still experimental).
- Phase 1 pilot improved rank correlation for scores, **not** feedback text quality.
- Need independent human reference issues on a set **disjoint** from development examples.
- No UI dual-read until P/R/F1 and Likert gates are met and approved.

## Rollback

Disable shadow (`QUALITY_SHADOW_ENABLED=false`) or ignore `experimental_feedback` in logs. Production feedback path needs no rollback.
