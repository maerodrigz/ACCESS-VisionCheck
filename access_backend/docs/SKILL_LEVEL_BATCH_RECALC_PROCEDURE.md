# Skill tier batch recalculation (manual, quality-only)

Quality-only skill classification and eligibility filtering are already live in code paths (`resolve_member_skill_level`, `recalculate_skill_level`). **Stored `users.skill_level_id` values may still reflect pre-batch tiers** until an operator runs the apply script after review.

This procedure **does not** change evaluation rows, XP, AI detection, or scoring formulas. It only updates persisted member skill tier labels via existing `recalculate_skill_level`.

---

## 1. Safety principles

| Rule | Detail |
|------|--------|
| Dry-run first | Always run `skill_level_recalc_dry_run.py` and review CSV + `summary.json`. |
| Backup before apply | Run `skill_level_recalc_backup.py`; keep `manifest.json` path for apply. |
| No silent production writes | Apply requires `--apply`, `--confirm-db`, `SKILL_RECALC_CONFIRM`, and (for `postgres` / `access`) `ALLOW_PRODUCTION_SKILL_RECALC=YES`. |
| Idempotent apply | `--skip-unchanged` (default) skips members whose stored tier already matches effective tier. Re-running apply after success should update **0** members. |
| Post-verify | Apply emits a `post_apply_verify_*` report; `remaining_mismatch` must be **0**. |

---

## 2. Read-only dry-run

From `access_backend` (uses `DATABASE_URL` / `.env`):

```powershell
cd access_backend
python scripts/skill_level_recalc_dry_run.py
```

Optional single member:

```powershell
python scripts/skill_level_recalc_dry_run.py --user-id 77
```

**Outputs** (under `backups/skill_recalc/dry_run_<timestamp>/`):

- `member_skill_recalc.csv` — per member:
  - `stored_skill_level` — current DB tier
  - `computed_skill_tier` — quality-only formula + eval gates (no override)
  - `effective_tier_after_recalc` — what `recalculate_skill_level` would persist (override wins)
  - `eligible_eval_count`, `total_practice_eval_rows`, `eligible_quality_avg_pct`
  - `competency_level_override`, `would_persist_change`
- `summary.json` — counts + eligibility audit

**Eligibility audit** confirms pending, withheld, rejected, and confirmed-AI rows are not counted toward skill aggregates (`leak_count` must be **0** before apply).

Exit code **2** if leaks are detected.

---

## 3. Database backup and restore

### Create backup

```powershell
cd access_backend
python scripts/skill_level_recalc_backup.py
```

Note `dump=` and `manifest=` paths from stdout.

### Restore (disaster recovery only)

Replace `<target_db>` with a **non-production** database first when practicing restore.

```powershell
$env:PGPASSWORD = "<postgres_password>"
pg_restore -h localhost -p 5432 -U postgres -d <target_db> --clean --if-exists "C:\path\to\postgres_pre_skill_recalc_YYYYMMDD_HHMMSS.dump"
```

**Warning:** `--clean` drops objects in the target database. Never restore over production until leadership approves.

Alternative: restore to a new empty database, point `DATABASE_URL` at it, and verify app read-only before cutover.

---

## 4. Apply recalculation (manual write — approval required)

**Not run automatically. Do not run against live production until dry-run and backup are signed off.**

```powershell
cd access_backend

# 1) Dry-run (again, same DB)
python scripts/skill_level_recalc_dry_run.py

# 2) Backup
python scripts/skill_level_recalc_backup.py

# 3) Apply (example — adjust paths and DB name)
$env:SKILL_RECALC_CONFIRM = "I_UNDERSTAND_SKILL_RECALC_WRITE"
$env:ALLOW_PRODUCTION_SKILL_RECALC = "YES"   # only when intentionally targeting production DB_NAME

python scripts/skill_level_recalc_apply.py `
  --apply `
  --confirm-db postgres `
  --require-backup "backups\skill_recalc\pre_recalc_YYYYMMDD_HHMMSS\manifest.json"
```

Without `--apply`, `skill_level_recalc_apply.py` behaves as dry-run only.

**What apply changes:** `users.skill_level_id` via `recalculate_skill_level` → `resolve_member_skill_level` (quality-only payload, eligible eval count, **admin competency override preserved**).

**What apply does not change:** `media_evaluations`, XP / `member_rankings.total_points`, AI detection rows, or override fields.

---

## 5. Post-run verification

1. Review `backups/skill_recalc/post_apply_verify_<timestamp>/summary.json`:
   - `would_persist_change` = **0**
   - `eligibility_leak_count` = **0**
2. Re-run dry-run; CSV should show `stored_skill_level` = `effective_tier_after_recalc` for all rows.
3. Spot-check mobile Profile / Rankings and admin Competency for a few members.
4. Restart API if needed (no schema migration required).

---

## 6. Test on isolated database (required before production apply)

Use `access_waverep_test` or another disposable DB:

```powershell
$env:ACCESS_PYTEST_DB = "access_waverep_test"
$env:DATABASE_URL = "postgresql+psycopg://postgres:<password>@localhost:5432/access_waverep_test"

python scripts/skill_level_recalc_dry_run.py
python scripts/skill_level_recalc_backup.py
# Apply without ALLOW_PRODUCTION_SKILL_RECALC if DB_NAME is not in the production guard list
python scripts/skill_level_recalc_apply.py --apply --confirm-db access_waverep_test --require-backup "<manifest.json>"
python scripts/skill_level_recalc_apply.py --apply --confirm-db access_waverep_test --require-backup "<manifest.json>"
# Second apply should report updated=0 skipped=<all>
```

Run unit tests:

```powershell
python -m pytest tests/test_skill_level_recalc_batch.py tests/test_skill_scoring.py tests/test_skill_evaluation_eligibility.py -q
```

---

## 7. When stored tier differs from computed tier

| Situation | Meaning | Operator action |
|-----------|---------|-----------------|
| `stored` ≠ `computed`, no override | Legacy tier (e.g. old formula) or tier never recalculated after eligibility change | Expected before batch apply; apply updates stored to `effective`. |
| Override set (`competency_level_override`) | Admin locked competency label (Beginner / Intermediate / Advanced) | Apply sets **effective** to override-normalized tier, not raw quality Expert. Document in Competency UI; clear override only if formula should govern. |
| `computed` = Expert but `effective` = Advanced | Override maps to 3-tier admin scale, or eval gate (< 10 eligible) caps tier | Explain to member: quality may be high but tier needs more eligible evaluations or admin policy. |
| `stored` = `computed` but member expected change | Pending/withheld evals excluded | No batch action; tier updates on next single-member `recalculate_skill_level` when eval is released. |
| Dry-run `would_persist_change` = 0 for everyone | Already aligned | Skip apply; document “no batch needed”. |

Members with **pending_review** evaluations: excluded from averages; tier may rise after admin release without re-upload.

---

## 8. Rollback

If apply results are wrong:

1. Stop API traffic (optional).
2. Restore PostgreSQL from pre-recalc dump (section 3).
3. Do not re-run apply until root cause is understood.

There is no partial automatic rollback; restore is the safe path.

---

## Script reference

| Script | Mode |
|--------|------|
| `scripts/skill_level_recalc_dry_run.py` | Read-only |
| `scripts/skill_level_recalc_backup.py` | Writes dump file only |
| `scripts/skill_level_recalc_apply.py` | Dry-run default; writes only with `--apply` + confirmations |

Shared logic: `app/services/skill_level_recalc_batch.py`.
