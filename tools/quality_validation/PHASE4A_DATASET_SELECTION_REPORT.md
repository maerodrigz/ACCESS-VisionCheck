# Phase 4A: Validation Dataset Selection Report

**Status:** preparation complete. Human independent ratings are **not** yet collected.  
**Freeze id:** `phase4a_freeze_20261113`  
**Selection seed:** `20261113_phase4a_indval`

## Goal

Identify a disjoint evaluation set that was **not** used to select or tune hybrid thresholds / Phase 3 feedback rules, larger than the Phase 1 30-image pilot when possible.

## Asset inventory and overlap

| Asset | Role historically | Eligible as primary Phase 4A holdout? |
|-------|-------------------|----------------------------------------|
| Human pilot PILOT-001…030 (KonIQ Run002 keys) | Phase 1 hybrid vs ENET retrospective; earlier ENET human-vs-machine | **No** (evaluation leakage / repeat look) |
| SPAQ-200 | Classical/Tenengrad exploratory readiness; Phase 12/13 Spearman | **No** (development/diagnostic use) |
| Phase 8/9 controlled distortion | A priori map diagnostics | **No** |
| KonIQ Run002 on disk (100 jpg) minus pilot 30 | Same corpus family, **disjoint files** | **Yes** (primary pool: 70) |
| KonIQ `images/` Run001 extract (40 jpg) | Benchmark family; not in pilot | **Yes** (supplement: 40) |
| Combined candidate pool | 110 unique files after exclusions | Target sample **n=100** |
| ACCESS-native club photos | Ideal ecological validity | **Preferred future**; not available as a ready local labeled pack here |

### Documented leakage safeguards

1. Exclude all pilot `source_media_key` values.
2. Exclude SPAQ-200 keys if any filename collision occurs.
3. Deduplicate by filename / sha256 in the selection script.
4. Facilitator mapping withheld from raters (`facilitator_mapping.csv`).
5. Analysis script refuses empty human sheets (no fabricated scores).

## Recommended sample size

| Option | n | Rationale |
|--------|--:|-----------|
| **Recommended primary** | **100** | Larger than pilot (30); fits local KonIQ remainder+Run001 (110); allows MOS-quintile stratification |
| Minimum acceptable | 70 | Run002 holdout only |
| Ideal future | ≥100 ACCESS-native | Better domain match; collect before production claims |

**Limitations:** KonIQ domain ≠ ACCESS event documentation. Published KonIQ MOS is overall-only and is **not** ACCESS criterion ground truth. SPAQ attribute labels are not used as primary GT here because of prior exploratory use.

## Selection procedure

```bash
cd tools/quality_validation
python select_phase4a_holdout.py --n 100 --seed 20261113_phase4a_indval
```

Outputs under `workspace/phase4a_indval/`:

- `holdout_manifest.csv`
- `facilitator_mapping.csv` (not for raters)
- `selection_report.json`

## What this set validates

1. **Image-quality assessment:** hybrid badges / q and ENET badges vs new human 1–5 medians; MUSIQ raw vs human overall (Spearman/Pearson; MAE only if scales compatible).
2. **Feedback generation:** issue-level P/R/F1 vs independent Y/N issue labels; Likert on feedback text quality.

These two analyses must stay separate in Chapter 4.
