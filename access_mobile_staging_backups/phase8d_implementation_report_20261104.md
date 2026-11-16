# Phase 8D: Shared-Development Grandfather Capture — Implementation Report

Date: 2026-11-04. **No `--apply` executed. No shared-dev or staging records modified.**

---

## A. Files created and modified

### Created

| Path | Purpose |
|------|---------|
| `access_backend/app/services/skill_progression_capture_manifest.py` | Load operator manifest JSON |
| `access_backend/app/services/skill_progression_capture_guard_shared_dev.py` | Fail-closed shared-dev preflight guards |
| `access_backend/app/services/skill_progression_grandfather_capture_shared_dev.py` | Dry-run plan + transactional apply + post-commit verify |
| `access_backend/scripts/skill_progression_capture_shared_dev.py` | Separate maintenance CLI |
| `access_backend/tests/test_skill_progression_capture_guard_shared_dev.py` | Isolated guard/apply unit tests |
| `access_mobile_staging_backups/phase8f_shared_dev_capture_manifest.example.json` | Example manifest (paths relative to `access_backend/`) |

### Modified

**None** of the following were changed:

- `scripts/skill_progression_capture_grandfather.py`
- `app/services/skill_progression_capture_guard.py`
- Flutter, API routes, `.env` files

---

## B. Shared-development guard implementation

Module: `skill_progression_capture_guard_shared_dev.py`

| Guard | Implementation |
|-------|----------------|
| Explicit shared-dev mode | Manifest `shared_development_mode: true` required |
| Reject staging env | `ACCESS_ENV_FILE` must not name `.env.skillprogression_staging` |
| Live DB | `current_database() == postgres`; forbids staging/UAT/waverep |
| Host / port | `settings.db_host` allowlist; live port **5432** |
| Role | `current_user` matches manifest `expected_database_role` (default `postgres`) |
| Policy v1 | Settings + `configured_skill_progression_policy() == v1` |
| Counts | Approved members, admin overrides vs manifest |
| Target | Ranking `id` + `user_id`; tier via `build_skill_progression_snapshot` → `computed_tier_v1` |
| NULL grandfather | Refuses non-null floor / captured_at / from_policy |
| Backup | File exists, min size, `PGDMP` header; optional `pg_restore --list` |
| Baseline | JSON `member_77` section compared to live fingerprint |
| Apply approval | `GRANDFATHER_SHARED_DEV_APPLY_APPROVED=1` required for `--apply` |

Errors raise `SharedDevCaptureSafetyError` (fail-closed).

---

## C. CLI dry-run and apply design

**Command:** `python scripts/skill_progression_capture_shared_dev.py --manifest <path> [--apply]`

| Mode | Behavior |
|------|----------|
| Default | Full preflight + print plan; **no writes** |
| `--apply` | Requires approval env var; transactional UPDATE; post-commit verify |

**Dry-run on live shared dev (Phase 8D, no `--apply`):** **PASS**

```
mode=DRY-RUN, postgres, v1, user 77, ranking 62, tier Intermediate, apply=skipped
```

Staging CLI unchanged; cannot load staging env file in shared-dev CLI entry.

---

## D. Exact write-set enforcement

Single conditional UPDATE inside transaction:

- `WHERE id = :target_ranking_id AND user_id = :target_user_id`
- `AND skill_tier_grandfather_floor IS NULL`
- `AND skill_tier_grandfather_captured_at IS NULL`
- `AND from_policy NULL/empty`
- **`rowcount` must equal 1**

Sets only:

- `skill_tier_grandfather_floor`
- `skill_tier_grandfather_captured_at`
- `skill_tier_grandfather_from_policy` (`v1`)

Does not UPDATE `users`, evaluations, milestones, XP, or overrides.

---

## E. Transaction and concurrency safeguards

1. `with db.begin():` wraps apply path.
2. Re-run live identity + full preflight inside transaction.
3. `SELECT ... FOR UPDATE` on target ranking row.
4. Recompute tier; abort if tier drift.
5. Conditional UPDATE; abort if `rowcount != 1`.
6. Rollback on any exception (including safety errors before commit).

TOCTOU: lock + NULL checks + single-row UPDATE.

---

## F. Isolated test results

```
tests/test_skill_progression_capture_guard_shared_dev.py — 9 passed
```

Covers: valid preflight, staging env rejection, forbidden DB, v2 policy, apply approval env, invalid backup, existing floor rejection, dry-run no commit, apply rowcount path (mocked).

**No write tests against real `postgres` or staging.**

---

## G. Existing staging regression results

```
tests/test_skill_progression_capture_guard.py — passed (unchanged)
tests/test_skill_progression_policy.py — passed
tests/test_skill_progression_hardening.py — passed
```

Combined run with new tests: **32 passed** (after backup test fix).

`ACCESS_ENV_FILE` unset for default-env suites.

---

## H. Normal app performance impact

| Surface | Impact |
|---------|--------|
| Flutter / API / startup | **None** |
| Profile / Rankings / auth / upload | **None** |
| New runtime dependencies | **None** |

Reachable only via operator CLI + manifest file.

---

## I. Known risks / incomplete safeguards

| Item | Notes |
|------|--------|
| Tier computation locking | Eligibility stats not locked across all eval rows; mitigated by tier re-check inside transaction |
| Backup restore | Archive list validated; full restore drill not in 8D |
| Manifest drift | Operator must refresh manifest if fleet grows |
| `pg_restore` optional | If binary missing, header/size checks still run |
| Admin override | Target override fails; other members with overrides not scanned beyond count |
| Staging superuser guard | Staging path unchanged; shared-dev allows `postgres` role by manifest design |

---

## J. GO / NO-GO for Phase 8E verification only

| Decision | Status |
|----------|--------|
| **GO Phase 8E** (verification prep: fresh baseline, backup re-check, dry-run, peer review) | **GO** |
| **GO execute `--apply`** | **NO-GO** — requires Phase 8F authorization |
| **GO v2 on shared dev** | **NO-GO** — Phase 8G only |

---

**Stop.** Phase 8D complete. Await explicit authorization for Phase 8E/8F.
