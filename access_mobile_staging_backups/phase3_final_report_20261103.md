# Phase 3: Staging v2 Activation Report

Generated: 2026-11-03 (local, untracked)

## A. Pre-activation safety verification (3A)

| Check | Result |
|-------|--------|
| `ACCESS_ENV_FILE` → `.env.skillprogression_staging` | PASS |
| `settings.db_name` = `access_skillprogression_staging` | PASS |
| Live DB / user / port | PASS (`access_skillprogression_staging`, `access_skillprogression_app`, 5432) |
| Staging role not superuser / no createdb / createrole | PASS |
| Staging API port 3011 | PASS |
| Shared dev policy v1 | PASS (default v1 via `.env`) |
| Staging policy pre-activation v1 | PASS |
| `grandfather_snapshots_complete` | PASS (8/8) |
| Floors from `computed_tier_v1` (no admin override on staging) | PASS |
| Backup readable | PASS (`access_skillprogression_staging_20261103_103820.dump`) |
| Rollback procedure documented | PASS (`SKILL_PROGRESSION_V2_ACTIVATION.md`) |

## B. Baseline snapshot (3B)

File: `phase3_baseline_20261103_104217.json`

- Policy: v1
- Approved members: 8
- Grandfather complete: true
- Milestones: 0
- Total XP sum: 1100
- Per-member v1 computed/effective tiers and eligible stats captured (no member rows modified)

## C. Staging-only activation (3C)

- Changed only `access_backend/.env.skillprogression_staging`: `SKILL_PROGRESSION_ACTIVE_POLICY=v2`
- Staging API on port 3011 with `ACCESS_ENV_FILE` set
- Shared dev `.env` and port 3001 untouched
- No grandfather `--apply`, no bulk recalc, no `users.skill_level_id` updates

## D. Authenticated participation API (3D)

Scripts: `phase3_api_smoke.py`, `phase3_all_members_participation.py`

All 8 approved members: login + `GET /api/member/participation` matches `build_skill_progression_snapshot`.

Global fields (all members):

- `skill_progression_policy_version` = v2
- `skill_progression_policy_configured` = v2
- `skill_progression_v2_blocked_reason` = null
- `daily_evaluation_limit` = 3

## E. Expected vs actual tier calculations

| Member | Stored `skill_level_id` | v1 computed | v2 raw (eval+days+quality) | Grandfather floor | Effective (v2) | API match |
|--------|-------------------------|-------------|----------------------------|-------------------|----------------|-----------|
| member@access.edu | Beginner | Beginner | Beginner | Beginner | Beginner | yes |
| carlos.m@… | Intermediate | Intermediate | **Beginner** (1 day) | Intermediate | Intermediate | yes |
| maria.santos@… | Beginner | Beginner | Beginner | Beginner | Beginner | yes |
| james.villanueva@… | Advanced | Beginner | Beginner | Beginner | Beginner | yes |
| sophia.lim@… | Intermediate | Beginner | Beginner | Beginner | Beginner | yes |
| miguel.torres@… | Expert | Beginner | Beginner | Beginner | Beginner | yes |
| elena.cruz@… | Advanced | Beginner | Beginner | Beginner | Beginner | yes |
| mark.delosreyes@… | Intermediate | Beginner | Beginner | Beginner | Beginner | yes |

Notes:

- Carlos: 3 eligible evals, 81% quality, **1** distinct Manila day → strict v2 rules yield Beginner; **grandfather floor** and `apply_grandfather_floor_v2` keep computed/effective at Intermediate (no demotion). Next tier toward Advanced correctly requires 12 evals, 10 days (`rem_evals=9`, `rem_days=9`).
- Five members retain **legacy stored labels** (Advanced/Expert/Intermediate) while effective tier is Beginner per earned v1 snapshot and zero eligible evals. This is expected without bulk recalc (explicitly forbidden in Phase 3).

## F. Flutter smoke tests (3E)

| Test | Result |
|------|--------|
| Live app on device/emulator → staging :3011 → Profile UI | **NOT TESTED** (widget test harness blocks real HTTP; no manual run logged) |
| `staging_v2_participation_fixture_test.dart` (v2 participation → snapshot copy) | PASS |
| `member_competency_snapshot_policy_test.dart` | PASS |
| `member_profile_skill_progress_section_test.dart` (320/360/393) | PASS |
| `flutter analyze` (prior session) | 3 pre-existing info lints in `app_state.dart` only |

To manual-smoke Flutter against staging: set runtime backend URL to PC LAN IP port **3011**, cold restart app, sign in as synthetic member (password not logged here).

## G. Post-activation shared-dev safety (3F)

`phase3_post_activation.py` — PASS

- Staging: db identity unchanged, policy **v2**, floors **8/8**, milestones **0**, xp_sum **1100** (matches baseline)
- `skill_level_id` unchanged for all 8 tracked members
- Shared dev: policy **v1**, users **3** (unchanged)

## H. Rollback

**Not performed.** Critical API checks passed; staging remains on v2 for further testing.

Rollback if needed: stop staging API → set `SKILL_PROGRESSION_ACTIVE_POLICY=v1` in staging env only → restart port 3011 → verify participation policy v1.

## I. Remaining issues

1. **Stored vs effective label drift** on 5 synthetic members until a future approved recalc or admin alignment (by design for Phase 3).
2. **Flutter live UI** against port 3011 not executed in this phase.
3. **`skill_computed_tier` under v2** reflects grandfather-adjusted computed tier, not strict v2-only raw tier; use internal snapshot fields / eligibility stats for raw v2 rule verification (Carlos case).

## J. Recommendation

**GO** for continued **isolated staging** experimentation on v2.

**NO-GO** for shared development, UAT, or production v2 rollout until separate explicit approval, grandfather planning on real members, and Flutter live smoke on staging API.

No git commit, push, deploy, or bulk recalc performed in Phase 3.
