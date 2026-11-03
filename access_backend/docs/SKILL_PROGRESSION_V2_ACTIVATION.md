# Balanced skill progression (v2) — staging activation checklist

**Production / shared dev:** keep `SKILL_PROGRESSION_ACTIVE_POLICY=v1` until explicit GO from ops.

Policy defaults to **v1** in `app/config.py`. v2 tier gates (reference only): Intermediate 60% / 3 evals / 2 Manila days; Advanced 75% / 12 / 10; Expert 90% / 24 / 24. Daily practice cap stays **3/day**.

## Phase 0 — Read-only validation (current stage)

1. Confirm code hardening and tests green (`test_skill_progression_staging_readiness.py`, Flutter policy tests).
2. Do **not** set v2 in shared `.env`.
3. Do **not** run `skill_progression_capture_grandfather.py --apply` on production or shared member DBs.

## Phase 1 — Schema and backup (writes DDL only)

1. **Database backup** with documented restore procedure (full dump or provider snapshot).
2. Confirm grandfather columns exist (non-destructive migration):
   ```bash
   cd access_backend
   python migrate_skill_progression_grandfather.py
   ```
3. Verify columns on `member_rankings`: `skill_tier_grandfather_floor`, `skill_tier_grandfather_captured_at`, `skill_tier_grandfather_from_policy`.

## Phase 2 — Grandfather dry-run (no writes)

1. Run capture **without** `--apply`:
   ```bash
   python scripts/skill_progression_capture_grandfather.py
   ```
2. Review each line: `floor` must equal **v1 computed tier**, never admin override label.
3. Members with `competency_level_override` still get an **earned** floor line; `effective=` shows override for audit.
4. Resolve warnings: `members_without_ranking_row`, empty `would_capture` anomalies.

## Phase 3 — Snapshot completeness verification (read-only)

1. Every **approved Member** must have a `member_rankings` row.
2. Every such member must have non-empty `skill_tier_grandfather_floor` **before** v2 can take effect (including override members; floor stores earned v1 computed tier).
3. Optional programmatic check (Python shell): `grandfather_snapshots_complete(db)` from `app.services.skill_progression_grandfather`.
4. `/member/participation` while env is still v1: note `skill_computed_tier_v2_preview` for spot checks.

### Participation tier fields (additive, backward compatible)

| Field | Meaning |
|-------|---------|
| `skill_computed_tier` | Tier from **active** policy (v1 rules or v2 with grandfather on computed path). Unchanged for existing clients. |
| `skill_computed_tier_v1` | v1 eval + quality gates only. |
| `skill_computed_tier_v2_strict` | v2 rules only (quality + eligible count + distinct Manila upload days), **before** grandfather floor. |
| `skill_computed_tier_v2_grandfather_adjusted` | v2 strict tier after `apply_grandfather_floor_v2`. |
| `skill_computed_tier_v2_preview` | Same as grandfather-adjusted v2; useful when effective policy is still v1. |
| `skill_effective_tier` | Shown tier: admin competency override if set, else `skill_computed_tier`. |
| `skill_tier_grandfather_floor` | Captured v1 earned tier floor (nullable). |
| `skill_tier_stored_legacy` | `users.skill_level_id` label (may be stale until recalc). |
| `skill_admin_competency_override` | Admin override on `member_rankings` (nullable). |

## Phase 4 — Snapshot apply (separate approval, writes member rows)

**Requires explicit authorization.** Writes `skill_tier_grandfather_*` on `member_rankings` only.

```bash
python scripts/skill_progression_capture_grandfather.py --apply
```

Re-run dry-run after apply; `would_capture` should be 0 and `skipped_existing` should cover all members.

## Phase 5 — Enable v2 (isolated staging / test environment only)

**Not on production until staging sign-off.**

1. Use an **isolated** database or staging clone with snapshots from Phase 4.
2. Set `SKILL_PROGRESSION_ACTIVE_POLICY=v2` in that environment’s `.env` only.
3. Restart API (`python manage.py runserver`).
4. **Verify effective policy via HTTP** (member JWT):
   - `GET /api/member/participation`
   - Expect: `skill_progression_policy_version` = `v2`
   - Expect: `skill_progression_policy_configured` = `v2`
   - Expect: `skill_progression_v2_blocked_reason` = `null`
5. Spot-check: `skill_effective_tier`, `skill_computed_tier`, remaining eval/day/quality fields match policy.
6. Monitor tier milestone notifications for duplicates (keys are idempotent; v2 eval gates use `v2:<count>` keys).

Optional after review: batch update stored `users.skill_level_id` (`scripts/skill_level_recalc_apply.py`) — **separate approval**, writes users table.

## Rollback

1. Set `SKILL_PROGRESSION_ACTIVE_POLICY=v1`.
2. Restart API.
3. Effective tier computation returns to v1 immediately.
4. Grandfather columns remain for audit; stored `users.skill_level_id` unchanged until optional recalc.

## Fail-safe behavior (verified)

| Condition | Effective policy | Participation signals |
|-----------|------------------|------------------------|
| Env unset / `v1` | v1 | `skill_progression_v2_blocked_reason` null |
| Env `v2`, snapshots incomplete | **v1** (fail-safe) | configured `v2`, blocked reason set |
| Env `v2`, snapshots complete | v2 | both version fields `v2`, blocked null |

Admin **competency override** always wins for `skill_effective_tier`. Grandfather floor applies to **v2 computed** tier only when quality supports the floor tier.

## Database write summary

| Action | Touches |
|--------|---------|
| `migrate_skill_progression_grandfather.py` | DDL on `member_rankings` |
| `capture_grandfather.py --apply` | `skill_tier_grandfather_*` |
| Eval pipeline / recalc | `users.skill_level_id`, milestones, notifications |
| Bulk recalc script | `users.skill_level_id` (bulk) |

## Grandfathering and admin override

- **Snapshot value:** always `computed_tier_v1` (earned), never the override label.
- **Display / effective tier:** override caps or labels still take precedence in API and rankings.
- **When override cleared:** earned progression history is preserved via grandfather floor and eligible eval stats; member is not reset to Beginner unless metrics justify it.
