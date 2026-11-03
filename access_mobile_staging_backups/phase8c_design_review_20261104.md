# Phase 8C: Minimal Shared-Development Grandfather Capture Pathway — Design Review ONLY

Date: 2026-11-04. **No code, no `.env` edits, no database writes, no `--apply`, no v2 activation.**

A **GO for implementation (Phase 8D)** means the design is sound; it does **not** authorize coding or capture execution.

---

## A. Existing architecture findings

### Components (as implemented today)

| Piece | Location | Role |
|-------|----------|------|
| Capture CLI | `access_backend/scripts/skill_progression_capture_grandfather.py` | Approved members → `computed_tier_v1` → optional `--apply` on `member_rankings` |
| Staging apply guard | `access_backend/app/services/skill_progression_capture_guard.py` | Fail-closed **`--apply` only on staging** |
| Tier computation | `app/services/skill_progression.py` → `build_skill_progression_snapshot()` | Read-only stats + v1/v2 math; capture uses **`computed_tier_v1`** only |
| Readiness helpers | `app/services/skill_progression_grandfather.py` | Missing-floor checks for v2 gate (no writes) |
| DB session | `app/database.py` → `SessionLocal()` | Standard SQLAlchemy session; commit in CLI |
| Config | `app/config.py` + `bootstrap_environment()` | `ACCESS_ENV_FILE` overrides `.env` |
| Guard tests | `tests/test_skill_progression_capture_guard.py` | Staging accept; **postgres forbidden**; v2 rejected |

**Note:** Guard module path is `app/services/skill_progression_capture_guard.py` (not repo root).

### Capture CLI behavior (summary)

```47:129:access_backend/scripts/skill_progression_capture_grandfather.py
# Default: dry-run (no --apply)
# --apply: assert_capture_apply_safe → loop → optional commit
# Writes only: skill_tier_grandfather_floor, _captured_at, _from_policy
# Skips rows that already have skill_tier_grandfather_floor (no overwrite)
# Admin override: counted in summary but still captured (not skipped)
```

### Staging guard (must remain unchanged)

```33:99:access_backend/app/services/skill_progression_capture_guard.py
# Requires ACCESS_ENV_FILE → .env.skillprogression_staging
# Requires settings.db_name == access_skillprogression_staging
# Requires live DB == staging, role == access_skillprogression_app
# FORBIDDEN_APPLY_DATABASES includes "postgres" → shared dev --apply impossible today
```

### Smallest gap for shared-development capture

1. **Separate apply guard** that **requires** `current_database() = 'postgres'` and **forbids** staging/UAT/waverep names (mirror of staging guard, inverted allowlist).
2. **Separate CLI entry** (or mutually exclusive flag) so staging `--apply` path is never accidentally combined with shared-dev env.
3. **Optional refactor (8D):** extract shared “dry-run / apply loop” into one internal function used by both CLIs to avoid duplicating tier logic (not required for safety if new script imports snapshot builder only).
4. **Shared-dev-specific preflight constants** for the current single-member fleet (approved=1, user 77, ranking 62, tier Intermediate) — configurable via env **file excluded from git** or CLI args documented at execution time, not hardcoded secrets.
5. **No change** to FastAPI routes, Flutter, middleware, or startup.

Phase 8B confirmed: dry-run on `postgres` works; `--apply` on `postgres` hits `CaptureApplySafetyError` by design.

---

## B. Minimal design options comparison

### Option A — Separate shared-development-only CLI

New script, e.g. `scripts/skill_progression_capture_grandfather_shared_dev.py`:

- Loads **only** default `access_backend/.env` (`ACCESS_ENV_FILE` **must be unset**).
- Dry-run default; `--apply` calls **`assert_shared_dev_capture_apply_safe()`** (new module or sibling file).
- Reuses `build_skill_progression_snapshot` + same three column writes (or calls extracted helper from 8D).
- **Does not import or call** `assert_capture_apply_safe`.

| Criterion | Assessment |
|-----------|------------|
| Safety | **High** — staging entry point untouched; wrong script = wrong guard set |
| Complexity | **Low–medium** — new file + new guard module (~100–150 lines) + optional extract |
| Duplication | **Low** if loop extracted once in 8D |
| Testing | Add parallel test module for shared-dev guard; staging tests unchanged |
| Maintainability | Two explicit operator commands; docs list both |
| Wrong-DB risk | **Lowest** — postgres script refuses staging DB; staging script refuses postgres |
| Runtime perf | **None** — CLI only |

### Option B — Scoped flag on existing CLI (`--shared-development-apply`)

Single script; `--apply` routes to staging guard **or** shared-dev guard based on explicit flag; default remains staging-only when `ACCESS_ENV_FILE` set.

| Criterion | Assessment |
|-----------|------------|
| Safety | **Medium** — one entry point; operator can pass wrong flag/env combo |
| Complexity | **Medium** — branching + mutual exclusion rules |
| Duplication | **Lower** single loop |
| Testing | More combinatorial cases (flag × env × apply) |
| Maintainability | One script, harder runbooks |
| Wrong-DB risk | **Medium** — requires strict mutual exclusion tests |
| Runtime perf | **None** |

### Option C — One-time SQL migration script (rejected)

Ad-hoc SQL bypasses tier resolver and guard patterns; high audit risk. **Not recommended.**

### Recommendation: **Option A (separate shared-dev CLI + separate guard module)**

Rationale: Preserves staging safeguards **literally unchanged**, minimizes accidental cross-targeting, aligns with Phase 8B finding, no Flutter/API surface, clearest approval checkpoints. Option B is acceptable only if team strongly prefers one script; Option A is safer for a **one-row, one-time** production-adjacent op.

**Explicitly excluded:** generic `--force`, `--database`, or bypass of `FORBIDDEN_APPLY_DATABASES` on the staging guard.

---

## C. Recommended design and rationale

### Architecture (future 8D)

```
scripts/skill_progression_capture_grandfather.py          # UNCHANGED staging --apply path
scripts/skill_progression_capture_grandfather_shared_dev.py  # NEW shared-dev --apply path
app/services/skill_progression_capture_guard.py           # UNCHANGED staging guards
app/services/skill_progression_capture_guard_shared_dev.py   # NEW shared-dev guards + preflight
app/services/skill_progression_grandfather_capture.py     # OPTIONAL: shared capture core (dry-run + apply)
```

### Operator model

| Action | Command context |
|--------|-----------------|
| Staging dry-run / apply | Existing script + `.env.skillprogression_staging` (apply already done: 8/8) |
| Shared dev dry-run | **Existing** script with default `.env` (already works) OR new script dry-run only |
| Shared dev apply | **New script only**, after Phase 8F authorization |

### Authorization model

- **No** `--apply` without prior Phase 8E human sign-off checklist.
- Optional: require env var **`GRANDFATHER_SHARED_DEV_APPLY_APPROVED=1`** set in the **operator shell only** (not in `.env` committed files) immediately before `--apply`, checked by new guard (second human intent signal).

---

## D. Required safety guards (shared-development `--apply`)

All checks use **live SQL** on the connected session. **Settings alone are insufficient.**

### Mode and environment

| Guard | Rule |
|-------|------|
| Explicit shared-dev mode | Only the new CLI accepts shared-dev `--apply` |
| `ACCESS_ENV_FILE` | **Must be unset** (or explicitly equal to `.env` only — reject staging filename) |
| `settings.db_name` | Must be **`postgres`** |
| `current_database()` | Must be **`postgres`** |
| `current_user` | Must be **`postgres`** (matches Phase 8A/8B live role) |
| `inet_server_addr()` | `localhost`, `127.0.0.1`, or `::1` |
| `inet_server_port()` | **5432** |
| Forbidden DB names | Reject if live DB ∈ `{access_skillprogression_staging, access_uat, access_waverep_test}` |
| Policy | `SKILL_PROGRESSION_ACTIVE_POLICY` and effective policy **v1** |
| API port (settings) | **3001** (informational assert in preflight printout) |
| Optional approval token | `GRANDFATHER_SHARED_DEV_APPLY_APPROVED=1` in shell |

### Fleet and target fingerprint (Phase 8C baseline — revalidated at execution)

Values are **examples from 8A/8B**; implementation should load from a **local operator manifest** (JSON next to backup) so counts can change without code edits:

| Assertion | Expected at design time |
|-----------|-------------------------|
| Approved member count | **1** |
| `would_capture` | **1** |
| `skipped_existing` | **0** |
| Admin overrides | **0** |
| Target `user_id` | **77** |
| Target `member_rankings.id` | **62** |
| `computed_tier_v1` | **Intermediate** |
| Grandfather columns | All **NULL** before apply |
| Legacy `users.skill_level_id` | **3** (unchanged by capture) |

If live dry-run differs, **abort** (do not relax guards to match).

### Non-overwrite

- Skip or **fail** if `skill_tier_grandfather_floor` already set (prefer **fail** on shared-dev single-row path so partial state is visible).
- Staging script behavior (skip existing) remains unchanged.

### Backup and baseline (pre-apply, read-only checks)

| Guard | Rule |
|-------|------|
| Backup path | File exists (e.g. `phase8a_postgres_shared_dev_20261103_215723.dump`) |
| Backup size | ≥ minimum threshold (e.g. > 100 KiB) |
| Archive | `pg_restore --list` exit 0 |
| Baseline JSON | Fresh compare or regenerate; member 77 fields match manifest |
| Dry-run | Same session: run dry-run; output matches manifest |

### Write scope

- **Only** `member_rankings` row **`id = 62` AND `user_id = 77`**.
- **Only** three grandfather fields (+ ORM `updated_at` if triggered).
- **No** `users`, evaluations, milestones, XP, overrides.

### TOCTOU / transaction design

1. **Begin transaction** (`db.begin()` or explicit).
2. Re-run **live identity** queries inside transaction.
3. `SELECT ... FROM member_rankings WHERE id = 62 AND user_id = 77 FOR UPDATE`:
   - Confirm row exists.
   - Confirm grandfather columns NULL.
4. Re-count approved members inside transaction; must still equal manifest.
5. Recompute tier via `build_skill_progression_snapshot(db, 77)`; must still be **Intermediate**.
6. **Single-row UPDATE** with `WHERE id = 62 AND user_id = 77 AND skill_tier_grandfather_floor IS NULL` (rowcount must be **1**).
7. If rowcount ≠ 1 → **rollback**, fail closed.
8. **Commit** once.
9. Post-commit read-only verification (new session): floors=1, user 77 floor=Intermediate.

Staging `--apply` keeps existing guard + ORM loop; no need to add single-row SQL there (already 8/8).

### v2

- No `.env` change to v2 in capture phase.
- Guard rejects configured policy v2.

---

## E. Exact expected write set (shared dev, when authorized)

| Table | Row | Column | Before | After |
|-------|-----|--------|--------|-------|
| `member_rankings` | `id=62`, `user_id=77` | `skill_tier_grandfather_floor` | NULL | `Intermediate` |
| same | same | `skill_tier_grandfather_captured_at` | NULL | UTC timestamp |
| same | same | `skill_tier_grandfather_from_policy` | NULL | `v1` |
| same | same | `updated_at` | prior value | ORM/server update |

**Must not change:** any other row; `users.skill_level_id`; `total_points` (208); `rank_position`; milestones; evaluations; staging DB.

**Post-capture verification queries (read-only):**

- `COUNT(*)` grandfather floors = 1.
- Row 62: floor=`Intermediate`, policy=`v1`, captured_at NOT NULL.
- User 77: `skill_level_id` = 3.
- Dry-run: `would_capture=0`, `skipped_existing=1`.

---

## F. Failure and rollback behavior

| Condition | Behavior |
|-----------|----------|
| Wrong database / role / port | **Fail before transaction**; no writes |
| `ACCESS_ENV_FILE` points to staging | **Fail** (shared-dev CLI) |
| Policy ≠ v1 | **Fail** |
| Approved count ≠ manifest | **Fail** |
| `would_capture` ≠ manifest | **Fail** (run dry-run first) |
| User ≠ 77 or ranking ≠ 62 | **Fail** |
| Tier ≠ Intermediate | **Fail** (revalidation required; do not auto-capture new tier) |
| Ranking row missing | **Fail** |
| Snapshot already exists | **Fail** (do not overwrite on shared-dev path) |
| Backup missing / invalid list | **Fail** |
| Concurrent update (row locked or NULL check fails) | **Rollback**; rowcount 0 → fail |
| DB error mid-transaction | **Rollback**; no partial commit |
| Post-commit verification fails | **Alert**; classify as **after-commit failure** — operator chooses: manual NULL revert of three columns (separate approval) or restore from Phase 8A dump to scratch DB then assess; **no auto full restore** |

**Fail-closed default:** any guard failure exits non-zero; session rolled back.

---

## G. Runtime performance impact

| Area | Impact |
|------|--------|
| Flutter app | **None** — no new screens, buttons, or API calls |
| FastAPI request path | **None** — no middleware or route changes |
| App startup | **None** |
| Background jobs | **None** |
| Normal login / Profile / Rankings / upload | **None** |
| Operator maintenance | **One-time** CLI; seconds-long DB transaction |

Design adds **zero** recurring queries or network calls to member-facing runtimes.

---

## H. Isolated test plan (Phase 8D — do not run on real shared dev)

Extend **`tests/test_skill_progression_capture_guard.py`** (staging unchanged) and add **`tests/test_skill_progression_capture_guard_shared_dev.py`**:

| Test case | Intent |
|-----------|--------|
| Staging guard still accepts staging / rejects postgres | **Regression** — existing tests must pass unchanged |
| Shared-dev guard accepts postgres + rejects staging DB name | New |
| Shared-dev guard rejects unset vs staging `ACCESS_ENV_FILE` | New |
| Shared-dev guard rejects v2 policy | New |
| Shared-dev guard rejects wrong member count (mock DB) | New |
| Shared-dev guard rejects tier mismatch | New |
| Shared-dev guard rejects non-NULL floor | New |
| Apply path uses UPDATE … WHERE id=62 AND floor IS NULL; rowcount 1 | Unit/integration with SQLite/Postgres test DB |
| Rowcount 0 → rollback, no commit | New |
| Transaction failure → rollback | New |
| Capture does not call `users` update | Mock assert |
| Idempotent second apply → fail or would_capture=0 | New |
| Backup validator rejects missing file | Pure function test |
| CLI integration: shared-dev `--apply` without approval env var → exit 1 | New |

Use **test database** or mocks only; never connect tests to developer `postgres` with `--apply`.

Optional: extract capture core and test dry-run output without apply.

---

## I. Future implementation and approval checkpoints

| Phase | Scope | Authorization |
|-------|--------|---------------|
| **8D** | Implement Option A: new guard module + new CLI + optional capture core extract + unit tests | Explicit **GO for code** (Phase 8C recommendation) |
| **8E** | Run tests (53+ new guard tests); re-verify backup list; fresh baseline JSON; dry-run; peer review checklist | Explicit **GO for capture prep** |
| **8F** | Operator runs **one** shared-dev `--apply` with manifest + backup path + approval env var | **Separate** written authorization; not combined with 8D/8E |
| **8G** | Consider shared-dev **v2 activation** (`.env` policy flip + API restart + smoke) | **Separate** authorization after 8F verification |

Phases **must not** be merged into a single approval.

**8F documented command shape (NOT TO RUN NOW):**

```powershell
# Phase 8F ONLY — requires prior 8D/8E + written approval
cd access_backend
Remove-Item Env:ACCESS_ENV_FILE -ErrorAction SilentlyContinue
$env:GRANDFATHER_SHARED_DEV_APPLY_APPROVED = "1"
python scripts/skill_progression_capture_grandfather_shared_dev.py --apply `
  --manifest ..\access_mobile_staging_backups\phase8f_capture_manifest.json
```

(Manifest design: paths to backup, expected counts, user 77 fingerprint — operator-maintained, untracked.)

---

## J. Remaining risks

| Risk | Mitigation |
|------|------------|
| Operator runs old staging script against wrong env | Runbooks; 8F uses **new script only** |
| Member fleet grows before 8F | Manifest count checks fail closed; refresh 8E |
| Tier changes before 8F | Tier re-check in transaction; abort |
| Admin override added later | Shared-dev design should **fail** if overrides > 0 unless manifest updated |
| Backup restore untested | Recommend test restore to **`postgres_capture_drill`** DB in 8E (optional, separate approval) |
| Staging guard regression | Keep existing tests byte-for-byte behavior |
| ORM loop vs single-row SQL drift | Shared-dev uses constrained UPDATE; staging unchanged |

---

## K. GO / NO-GO — code implementation only (Phase 8D)

| Decision | Status |
|----------|--------|
| Design complete and minimal? | **Yes** |
| Staging safeguards preserved? | **Yes** (Option A leaves staging guard + CLI path untouched) |
| No runtime / UI impact? | **Yes** |
| Wrong-DB risk acceptable? | **Low** with separate CLI + inverted guards |
| **GO to implement Phase 8D?** | **GO** — implement Option A as specified |
| **GO to execute capture?** | **NO-GO** — requires Phase 8F authorization |
| **GO for v2 on shared dev?** | **NO-GO** — Phase 8G only |

---

**Stop.** Phase 8C design review complete. Await explicit authorization for **Phase 8D implementation** only.
