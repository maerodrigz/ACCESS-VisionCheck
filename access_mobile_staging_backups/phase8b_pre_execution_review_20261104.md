# Phase 8B: Grandfather Snapshot Capture — Pre-Execution Review ONLY

Date: 2026-11-04. **No `--apply`, no database writes, no `.env` changes, no v2 activation.**

This document is preparation and review. A **GO** recommendation means technically understood and checklist-ready, **not** authorization to execute.

---

## A. Existing capture implementation summary

### Entry point

| Item | Detail |
|------|--------|
| Script | `access_backend/scripts/skill_progression_capture_grandfather.py` |
| CLI | `--apply` flag (`store_true`); **default = dry-run** (no writes) |
| Env bootstrap | `bootstrap_environment()` at import (uses `ACCESS_ENV_FILE` if set, else `access_backend/.env`) |
| Session | `SessionLocal()`; closed in `finally` |

### Dry-run behavior (default)

- Does **not** call `assert_capture_apply_safe` (guard runs only when `args.apply` is true: lines 60–61, 107–108).
- Loads **approved** members: `UserStatus.APPROVED` + `RoleName.MEMBER` (lines 68–74).
- For each member with a `member_rankings` row and **empty** `skill_tier_grandfather_floor`:
  - Builds snapshot via `build_skill_progression_snapshot(db, user.id)` (line 89).
  - Uses **`snap.computed_tier_v1`** as the floor value (lines 90, 99).
  - Prints plan; increments `would_write` (lines 98–101).
  - **Does not** mutate ORM attributes or `commit()` (apply block skipped).
- Members **without** ranking row: logged, skipped (lines 81–85).
- Members **with existing floor**: `skipped_existing` (lines 86–88).
- **Admin override**: if `competency_level_override` is set, script increments `members_with_admin_override` and prints a note but **still counts toward `would_write` and would still write on `--apply`** (lines 92–105). Override does **not** skip capture.

### `--apply` behavior

When `--apply`:

1. `assert_capture_apply_safe(db)` **before** loop (line 60).
2. Same loop; for each eligible row sets on `MemberRanking` (lines 103–105):
   - `skill_tier_grandfather_floor` = `tier` (`computed_tier_v1`)
   - `skill_tier_grandfather_captured_at` = `datetime.now(timezone.utc)`
   - `skill_tier_grandfather_from_policy` = `POLICY_V1` (`"v1"`)
3. If `would_write > 0`: second `assert_capture_apply_safe(db)` then **single** `db.commit()` (lines 107–110).
4. On commit failure: `db.rollback()` and re-raise (lines 111–113).
5. If `would_write == 0`: prints message, **no commit** (lines 114–115).
6. `CaptureApplySafetyError`: rollback + exit 1 (lines 124–127).

### Tables / fields affected on `--apply`

| Table | Columns written | Other tables |
|-------|-----------------|--------------|
| `member_rankings` | `skill_tier_grandfather_floor`, `skill_tier_grandfather_captured_at`, `skill_tier_grandfather_from_policy` | **None** in this script |

**Not modified by this script:** `users` (including `skill_level_id`), `member_rankings.total_points`, `rank_position`, `competency_level_override`, evaluations, milestones, `system_settings`, XP ledger logic.

**Possible side effect:** `member_rankings.updated_at` may change via SQLAlchemy `onupdate=func.now()` on the model when the row is flushed/committed (`app/models/member_ranking.py` lines 27–29).

### Tier source

- V1 earned tier: `build_skill_progression_snapshot` → `computed_tier_v1` (v1 policy formula on eligible eval stats; not bulk recalc of `users.skill_level_id`).

### Related (read-only) helpers

- `app/services/skill_progression_grandfather.py`: missing-snapshot checks for v2 gate messaging (no writes).

---

## B. Database safety guard audit (`assert_capture_apply_safe`)

Source: `app/services/skill_progression_capture_guard.py`

**Important:** Guards apply **only** when `--apply` is passed. They are written for **staging DB apply**, not shared-development `postgres`.

| # | Guard | Status | Evidence |
|---|--------|--------|----------|
| 1 | Confirm `current_database() = postgres` (shared dev) | **Missing / inverted for shared dev** | Live DB must be `access_skillprogression_staging` (lines 78–80). `postgres` is in `FORBIDDEN_APPLY_DATABASES` (lines 14–19, 74–76) → **`--apply` on shared dev `postgres` always fails.** |
| 2 | Confirm PostgreSQL host and port | **Partial** | `DB_HOST` in allowlist (lines 54–58); live `inet_server_port() == 5432` (lines 86–89). Only evaluated on `--apply`. |
| 3 | Active policy is v1 | **Implemented** (on `--apply`) | Lines 49–52 |
| 4 | Reject staging / UAT / test / unknown | **Partial / staging-centric** | Forbids `postgres`, `access_uat`, `access_waverep_test` on apply (74–76). Requires staging name + role (78–85). Does not define a shared-dev allow path. |
| 5 | Reject unexpected approved-member counts | **Missing** | No assertion on `len(members)` or `would_write`. |
| 6 | Reject unexpected capture counts | **Missing** | Same. |
| 7 | Skip already captured snapshots | **Implemented** (in script loop) | `skill_progression_capture_grandfather.py` 86–88; apply path does not overwrite existing floor. |
| 8 | No writes to XP, evals, milestones, `skill_level_id` | **Implemented** (by scope) | Script only sets grandfather columns on `member_rankings`. |
| 9 | Rollback on failure | **Partial** | `commit` wrapped with rollback on exception (111–113); safety error rollback (125). No savepoints per member. |
| 10 | Stop if env/identity changes mid-run | **Missing** | Single check before loop and before commit; no re-check after loop. |

### Dry-run safety

- Default run performs SELECTs + in-memory snapshot computation; **no `commit()`** unless `--apply`.
- Verified in this review: shared-dev dry-run completed with `mode=dry_run`.

### Documentation alignment

`access_backend/docs/SKILL_PROGRESSION_V2_STAGING_SETUP.md` §9–10: **`capture_grandfather.py --apply` is not approved for shared dev**; staging `--apply` uses `.env.skillprogression_staging`. Staging already has **8/8** floors (dry-run `would_capture=0`).

---

## C. Phase 8A backup verification (archive only, no restore)

| Check | Result |
|-------|--------|
| Path | `access_mobile_staging_backups/phase8a_postgres_shared_dev_20261103_215723.dump` |
| Exists | **Yes** |
| Size | **179,313 bytes** (unchanged from Phase 8A) |
| Format | PostgreSQL custom (`-Fc`); archive header `dbname: postgres` |
| `pg_restore --list` | **Readable**; TOC entries **366** (Phase 8A reported 376 lines; minor tooling/count variance; archive valid) |
| Sample contents | Includes `TABLE DATA public member_rankings`, `users`, grandfather-related schema |

**Archive validation:** PASS.  
**Full restore to a database:** **NOT TESTED** (explicitly out of scope for 8A/8B).

---

## D. V1 baseline comparison (Phase 8A JSON vs live read-only)

Baseline file: `access_mobile_staging_backups/phase8a_shared_dev_baseline_20261103_215626.json`

Live query session: `ACCESS_ENV_FILE` cleared, `.env` → `postgres`.

| Field | Phase 8A baseline | Live (this review) | Match |
|-------|-------------------|----------------------|-------|
| `computed_tier_v1` / policy | Intermediate | Intermediate | Yes |
| `effective_tier` | Intermediate | Intermediate | Yes |
| `users.skill_level_id` | 3 | 3 | Yes |
| Legacy label | Intermediate | Intermediate | Yes |
| `total_points` | 208 | 208 | Yes |
| `rank_position` | 1 | 1 | Yes |
| Eligible evaluations | 3 | 3 | Yes |
| Distinct eligible upload days | 2 | 2 | Yes |
| `skill_score_pct` | 69.53 | 69.53 | Yes |
| Milestones | 7 | 7 | Yes |
| Grandfather floor | null | null | Yes |
| Admin override | null | null | Yes |

**DIFFS: none.** Future capture does **not** require baseline revalidation for drift (as of this review).

---

## E. Exact expected database write set (shared dev, if `--apply` were permitted)

Derived from source + read-only state only. **Not executed.**

### Row that would change

| Table | PK / key | Column | Current | Expected after capture | Reason |
|-------|----------|--------|---------|------------------------|--------|
| `member_rankings` | `id=62`, `user_id=77` | `skill_tier_grandfather_floor` | `NULL` | `Intermediate` | Store v1 computed earned tier |
| `member_rankings` | same | `skill_tier_grandfather_captured_at` | `NULL` | UTC timestamp at apply | Audit when captured |
| `member_rankings` | same | `skill_tier_grandfather_from_policy` | `NULL` | `v1` | Policy label at capture |
| `member_rankings` | same | `updated_at` | `2026-11-02 22:46:06+08` (approx) | New timestamp on commit | Model `onupdate` |

### Must remain unchanged

- `users.id=77`: `skill_level_id`, email, status, password, all non-ranking fields
- `member_rankings`: `total_points`, `rank_position`, `competency_level_override`, `admin_remarks`
- All evaluation, milestone, XP transaction, and media rows
- `SKILL_PROGRESSION_ACTIVE_POLICY` in `.env` (remains **v1**)
- Staging database rows (separate DB)

**Write-set confidence:** HIGH from code inspection + live NULL grandfather fields.

**Critical blocker:** With **current** guards, the documented `--apply` path for **shared dev `postgres` will not run** (see §B). Expected write set applies only after a **separately authorized** guard/policy change or an approved staging-only apply (staging already captured).

---

## F. Dry-run result (executed, no `--apply`)

### Shared development (default `.env`, `ACCESS_ENV_FILE` unset)

```
connected database=postgres user=postgres
user_id=77 computed_v1=Intermediate -> floor=Intermediate
database=postgres members=1 would_capture=1
skipped_existing=0 members_with_admin_override=0 mode=dry_run
```

Matches Phase 8A expectations.

### Staging (reference only, read-only dry-run)

```
connected database=access_skillprogression_staging user=access_skillprogression_app
database=access_skillprogression_staging members=8 would_capture=0
skipped_existing=8 members_with_admin_override=0 mode=dry_run
```

Staging unchanged; no writes.

---

## G. Proposed future capture command (**NOT EXECUTED**)

### Authorization checkpoint 0

Explicit written approval for **which database** and **which guard path**:

- **Option A (current code):** `--apply` only on **`access_skillprogression_staging`** with `ACCESS_ENV_FILE` → `.env.skillprogression_staging` (staging already **8/8** → expect `would_capture=0`).
- **Option B (shared dev, user Phase 8A intent):** Requires **future authorized code change** to allow `--apply` on `postgres` with default `.env` and fail-closed shared-dev guards. **Not available today.**

### Documented command that **would** apply on shared dev **if guards allowed** (DO NOT RUN)

```powershell
# NOT AUTHORIZED — WILL FAIL TODAY WITH CaptureApplySafetyError ON postgres
cd access_backend
Remove-Item Env:ACCESS_ENV_FILE -ErrorAction SilentlyContinue
python scripts/skill_progression_capture_grandfather.py --apply
```

### Command that **current codebase** expects for `--apply` (staging; DO NOT RUN without approval)

```powershell
# NOT AUTHORIZED — staging already fully captured
cd access_backend
$env:ACCESS_ENV_FILE = (Resolve-Path .env.skillprogression_staging).Path
python scripts/skill_progression_capture_grandfather.py --apply
```

No script, test, or helper in this review invokes `--apply`.

---

## H. Post-capture verification plan (future, after separate approval)

1. Re-run identity: `current_database()`, policy **v1**, port **3001**.
2. `SELECT count(*)` grandfather floors = approved member count (expect **1** on shared dev).
3. User 77: floor **Intermediate**, `from_policy` **v1**, `captured_at` NOT NULL.
4. Confirm `users.skill_level_id` still **3**; `total_points` still **208**.
5. Re-run dry-run: `would_capture=0`, `skipped_existing=1`.
6. `GET /api/member/participation` (smoke): policy still **v1** on shared dev.
7. Staging read-only check: still **v2**, **8/8** floors, port **3011**.
8. Compare fingerprint JSON to pre-capture snapshot.

---

## I. Rollback and recovery

| Scenario | Action |
|----------|--------|
| Bad capture on shared dev | Restore from `phase8a_postgres_shared_dev_20261103_215723.dump` to a **new** DB first; in-place restore only with explicit approval |
| Partial commit | Unlikely single commit; restore or manual NULL of three grandfather columns on affected rows (manual = separate approval) |
| Wrong database | **Prevented today** for postgres apply by guards; dry-run always verify `connected database=` line |
| v2 accidentally enabled | Revert `.env` policy to v1; restart API; no automatic bulk recalc |

Restore procedure documented in Phase 8A report; **not executed** here.

---

## J. Remaining risks

1. **`--apply` on shared dev blocked by design** — Phase 8B capture on `postgres` needs guard work or process realignment with staging-only docs.
2. **Admin override members still captured** — override counted but not skipped; could surprise ops if overrides exist later.
3. **No guard on `would_capture` count** — operator must manually assert `would_capture=1` before any future apply.
4. **Backup restore untested** — archive valid; full DR not proven.
5. **Single-member blast radius** — low, but restore path should be confirmed before apply.
6. **Broader pytest failures** — do not affect capture script logic directly (see §K).

---

## K. Backend failure relevance (Phase 7)

| Failure | Affects grandfather capture? |
|---------|------------------------------|
| Stale mocks (`ranking_crud`, evaluations pydantic) | **No** |
| Waverep flag tests (env has waverep on) | **No** |
| AI detector signature test | **No** |
| Partial Android integrity copy | **No** (messaging only) |
| SyntaxError test modules | **No** |
| Skill progression suite (53/53) | **Yes — passing**; tier calculation path used by capture |

**Unresolved safety concern for capture integrity:** none identified in progression/capture code path; **primary concern is apply guard / target DB mismatch**, not pytest noise.

---

## L. GO / NO-GO for a separately authorized capture

| Question | Recommendation |
|----------|----------------|
| Dry-run + baseline + backup ready on shared dev? | **GO** (prepared) |
| Execute `--apply` on shared dev `postgres` with **current** code? | **NO-GO** (guards forbid `postgres`; requires `ACCESS_ENV_FILE` staging + staging DB) |
| Execute `--apply` on staging? | **NO-GO for new writes** (already **8/8**; dry-run `would_capture=0`) |
| Proceed to code/guard change for shared-dev apply? | **Conditional** — only with explicit new authorization |

### Overall Phase 8B pre-execution review

**GO** for: review complete, dry-run verified, backup validated, write-set documented, execution checklist ready.

**NO-GO** for: executing `--apply` now or assuming Phase 8A implied shared-dev apply without guard changes.

**Stop.** Wait for explicit user authorization that specifies **database target** and **guard/code path** before any write.
