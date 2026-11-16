# Phase 6A — Independent 100-Image Human Validation Package

**Status:** package prepared. Human ratings **not** collected. Independent validation is **not** complete.
**Prepared (UTC):** 2026-11-14T01:10:01.982022+00:00
**Freeze ID:** `phase6a_freeze_20261114T011001Z`
**Package root:** `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\phase6a_human_validation`

## 1. Holdout audit

- Manifest rows: **100**
- Blinded images present: **100**
- Unique INDVAL IDs: **100**
- Unique SHA-256: **100**
- Readable JPEGs: **100/100**
- Missing images: none
- Unreadable: none
- Duplicate IDs: none
- Duplicate hashes: none
- Hash mismatches vs manifest: none

## 2. Independence from 30-image pilot

- Pilot keys overlapping holdout: **none**
- Pilot SHA-256 overlapping holdout: **none**
- Selection report pilot_keys_in_selected: **none**

Holdout remains KonIQ-domain (same corpus family as the pilot) but uses **disjoint files** by `source_media_key` and content hash.

## 3. Frozen machine versions (for later analysis; hidden from raters)

- MUSIQ: `tfhub:google/musiq/paq2piq/1` / `paq2piq/1`
- OpenCV map: `phase9_a_priori_equal_bin_v1` (experimental equal-bin; uncalibrated)
- Feedback rules: `hybrid_feedback_rules_v1` (experimental; not distributed to raters)
- Production quality engine remains: **enet**

## 4. Package locations

| Asset | Path |
|---|---|
| Rater images | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\phase6a_human_validation\rater_pack\images` |
| Rating sheets R1–R3 | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\phase6a_human_validation\rater_pack\ratings_R*.csv` |
| Rubric | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\phase6a_human_validation\rater_pack\HUMAN_RATING_RUBRIC.md` |
| Instructions | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\phase6a_human_validation\rater_pack\INSTRUCTIONS.md` |
| HTML helper | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\phase6a_human_validation\rater_pack\rating_sheet.html` |
| Facilitator map | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\phase6a_human_validation\facilitator\facilitator_mapping.csv` |
| Freeze record | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\phase6a_human_validation\freeze\phase6a_freeze.json` |
| Consensus script | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\generate_phase6a_consensus.py` |

## 5. Instructions for the three evaluators

Give each rater only the `rater_pack/` contents (or a zip of that folder) plus their own `ratings_R#.csv`. Point them to `INSTRUCTIONS.md` and `HUMAN_RATING_RUBRIC.md`. Collect filled CSVs before any consensus or machine comparison.

## 6. Explicit non-claims

- No human scores were fabricated.
- Consensus was **not** generated.
- Statistical human-vs-machine analysis was **not** run.
- Phase 4A files under `workspace/phase4a_indval/` were **not** overwritten.
- Production scoring / Flutter / PROBE / WaveRep were **not** modified.

