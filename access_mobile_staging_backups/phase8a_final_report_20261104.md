# Phase 8A: Shared Development Grandfather Readiness (PREPARATION ONLY)

Date: 2026-11-04 (UTC). **No `--apply`, no v2 activation, no DB writes, no `.env` changes.**

---

## A. Live shared-development database identity

| Check | Result |
|-------|--------|
| `ACCESS_ENV_FILE` | **Cleared** for all shared-dev steps |
| Config loaded | `access_backend/.env` |
| `settings.db_name` | **postgres** |
| `SELECT current_database()` | **postgres** |
| `SELECT current_user` | **postgres** |
| `inet_server_addr()` | **::1** (localhost) |
| `inet_server_port()` | **5432** |
| `SKILL_PROGRESSION_ACTIVE_POLICY` | **v1** |
| `settings.api_port` | **3001** |
| Forbidden DBs | **Not connected** (not staging/uat/waverep_test) |

**Identity: PASS** — all Step 1 checks satisfied.

---

## B. Schema and approved member verification (read-only)

| Metric | Phase 7 baseline | Phase 8A live | Delta |
|--------|------------------|---------------|-------|
| Approved members | 1 | **1** | none |
| Grandfather floor rows | 0 | **0** | none |
| Admin competency overrides | 0 | **0** | none |
| Grandfather columns on `member_rankings` | present | **3/3** | none |

**Approved member IDs:** `[77]`

**Member 77 (read-only progression snapshot, v1 policy):**

| Field | Value |
|-------|--------|
| `computed_tier_v1_policy` | **Intermediate** |
| `effective_tier` | **Intermediate** |
| `users.skill_level_id` | **3** → legacy label **Intermediate** |
| `skill_score_pct` | 69.53 |
| Eligible evaluations | 3 |
| Distinct eligible upload days | 2 |
| `member_rankings.total_points` | 208 |
| `rank_position` | 1 |
| Grandfather floor | null |
| Admin override | null |
| Milestones (if table present) | 7 |

Matches Phase 7 expectations for tier and counts.

---

## C. Backup path, size, validation

| Item | Value |
|------|--------|
| Tool | `pg_dump -Fc` (PostgreSQL 18 bin) |
| Pre-dump identity | `postgres` @ port **5432** |
| Path | `access_mobile_staging_backups/phase8a_postgres_shared_dev_20261103_215723.dump` |
| Size | **179,313 bytes** (~175 KiB) |
| `pg_dump` exit | **0** |
| `pg_restore --list` | **376** TOC lines, exit **0** |
| Status | **VERIFIED** |

**Future restore (not executed in 8A):**

```text
# Example only — run only in an approved maintenance window on a NON-production target
pg_restore -h localhost -p 5432 -U postgres -d postgres --clean --if-exists phase8a_postgres_shared_dev_YYYYMMDD_HHMMSS.dump
```

Prefer restoring to a **new empty database** first for validation, then swap only with explicit approval.

Helper script: `access_backend/scripts/phase8a_pg_dump_shared_dev.py`

---

## D. Read-only v1 baseline export

| Artifact |
|----------|
| `access_mobile_staging_backups/phase8a_shared_dev_baseline_20261103_215626.json` |

Contains identity, policy, counts, and member 77 progression fields (no passwords/tokens).

Generator: `access_backend/scripts/phase8a_shared_dev_preparation.py`

---

## E. Grandfather dry-run results (no `--apply`)

```
connected database=postgres user=postgres
user_id=77 computed_v1=Intermediate -> floor=Intermediate
database=postgres members=1 would_capture=1
skipped_existing=0 members_with_admin_override=0 mode=dry_run
```

| Expected (Phase 7) | Actual (8A) |
|--------------------|-------------|
| members=1 | **1** |
| would_capture=1 | **1** |
| skipped_existing=0 | **0** |
| overrides=0 | **0** |
| user 77 tier Intermediate | **Intermediate** |

**Dry-run: PASS**

---

## F. Before/after database consistency (dry-run)

Fingerprints: `phase8a_fingerprint_before_dryrun.json`, `phase8a_fingerprint_after_dryrun.json`

| Field | Before | After |
|-------|--------|-------|
| `database` | postgres | postgres |
| `policy` | v1 | v1 |
| `approved_members` | 1 | 1 |
| `grandfather_floors` | 0 | 0 |
| `overrides` | 0 | 0 |
| user 77 `skill_level_id` | 3 | 3 |
| user 77 `total_points` | 208 | 208 |

**No writes detected** from dry-run.

---

## G. Staging isolation verification (read-only)

Separate env: `.env.skillprogression_staging`

| Check | Result |
|-------|--------|
| `current_database()` | **access_skillprogression_staging** |
| DB role | **access_skillprogression_app** |
| Policy | **v2** |
| API port (settings) | **3011** |
| Grandfather floors | **8** |
| `staging_isolation_ok` | **True** |

Staging API **not restarted**. No staging records modified.

Script: `access_backend/scripts/phase8a_staging_readonly_check.py`

---

## H. Remaining backend test failure assessment (Phase 7 + 8A re-run)

Skill progression suite (**53/53**) on default `.env`: **not rollout blockers**.

| Failure | Area | Rollout blocker? | Evidence |
|---------|------|------------------|----------|
| `test_admin_human_xp_once_still_guarded` | XP / ai_review_workflow mocks | **No** | Test patches removed `ranking_crud` symbol |
| `test_xp_awarded_once_after_verify` | Same | **No** | Stale mock path |
| `test_fake_probability_from_logit_matches_univfd_sigmoid` | AI detector unit | **No** | Signature change `_fake_probability_from_logit(logit, torch)` |
| `test_list_evaluations_media_id_returns_one_row` | Evaluations list mock | **No** | Pydantic mock fields for new chain/XP columns |
| `test_partial_android_member_message_not_ai_accusation` | Media integrity copy | **Investigate** | Intentional copy change for partial provenance; not auth/profile/progression |
| `test_default_flag_off` / `test_runtime_status_flag_off` | Waverep env | **No** | Local `.env` has waverep enabled; tests assume default off |
| `test_submission_chains_phase1.py` | Collection | **No** | SyntaxError in test file |
| `test_replacement_upload_phase2.py` | Collection | **No** | Collection error |

**None** of the failures block grandfather **capture** or v2 **policy flip** for Profile/Participation/Rankings APIs when progression tests pass.

---

## I. Risks and rollback readiness

| Risk | Mitigation |
|------|------------|
| Wrong DB on `--apply` | Capture guard + 8A identity script; require `ACCESS_ENV_FILE` unset and live `postgres` check |
| No rollback after capture | Verified **179 KiB** custom dump; restore procedure documented |
| Single approved member | Dry-run captures **1** row; low blast radius |
| Staging cross-contamination | 8A verified staging **unchanged** (8/8, v2) |
| pytest drift | Fix tests in a separate hygiene pass; not required for 8B capture |

Rollback after future v2 activation (separate phase): set policy **v1**, restart API; grandfather floors remain; **no bulk recalc** per policy.

---

## J. GO / NO-GO for Phase 8B (grandfather `--apply` on shared dev)

| Gate | Status |
|------|--------|
| Identity = `postgres` v1 @ 3001 | **GO** |
| Schema + counts match expectations | **GO** |
| Verified backup on disk | **GO** |
| Baseline JSON exported | **GO** |
| Dry-run would_capture=1 | **GO** |
| Zero writes from dry-run | **GO** |
| Staging isolated (v2, 8/8) | **GO** |
| Explicit user authorization for `--apply` | **PENDING** |

### Recommendation

**GO for Phase 8B** — shared development is **prepared** for a separately authorized grandfather snapshot **`--apply`** on `postgres`, subject to:

1. Human approval checkpoint immediately before `--apply`.
2. Re-run identity + fingerprint + dry-run in the same session as apply.
3. Do **not** set `ACCESS_ENV_FILE` to staging during 8B.

**NO-GO** for v2 activation or any step beyond grandfather capture until Phase 8B completes and a future phase is approved.

---

## Artifacts (local, untracked)

- `phase8a_shared_dev_baseline_20261103_215626.json`
- `phase8a_postgres_shared_dev_20261103_215723.dump`
- `phase8a_fingerprint_before_dryrun.json`
- `phase8a_fingerprint_after_dryrun.json`

Ops scripts under `access_backend/scripts/phase8a_*.py` (preparation helpers only).

**Stop.** Await explicit authorization for Phase 8B `--apply` only.
