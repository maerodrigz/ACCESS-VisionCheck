# Phase 7: Final Regression and Rollout Readiness (NO ACTIVATION)

Date: 2026-11-04

**Scope:** Verification and readiness only. Staging remains **v2** on **3011**. Shared development remains **v1** on **3001**. No grandfather `--apply`, no v2 activation, no commits.

---

## A. Flutter test results

| Run | Passed | Failed |
|-----|--------|--------|
| Initial full suite | 146 | 6 |
| After Phase 7 fixes | **152** | **0** |

**Failures resolved (classification):**

| Test | Cause | Action |
|------|--------|--------|
| `api_config_lan_sync_test` | Hardcoded LAN IP `.97`; PC list starts at `.98` | **Test fix:** assert `knownLanHosts.first` + `defaultPort` |
| `api_config_staging_port_test` | Wrong `fromEnvironment` default (3011 vs compile-time 3001) | **Test fix:** branch on actual `API_PORT` define |
| `additional_quality_insights_test` | Panel collapsed by default; labels hidden until expand | **Test fix:** tap to expand before assertions |
| `media_evaluation_screen_test` (2) | **1px** eval card Column overflow in tight height | **App fix:** reduce card footer padding 1px |
| `practice_member_evaluation_flow_test` | Parser now returns deferred AI shell (not null) | **Test fix:** align with deferred preview behavior |

No tests skipped or weakened.

**`flutter analyze`:** 61 **info**-level items (style/deprecation); **no errors**. Pre-existing; not introduced in Phase 7.

---

## B. Backend regression results

### Skill progression / v2 suite (default `.env`, `ACCESS_ENV_FILE` unset)

```
53 passed (test_skill_progression_*, member_milestones_progression, evaluation_daily_quota, staging_readiness)
```

Covers: v1/v2 policy branches (with proper env isolation), capture guard, milestones, daily quota, staging readiness.

**Note:** Running progression tests with `ACCESS_ENV_FILE` pointing at staging makes two tests fail (settings stuck at v2). CI/local regression must **unset** staging env when testing shared-dev defaults.

### Full `tests/` (excluding 2 files with SyntaxError collection errors)

```
314 passed, 8 failed, 18 skipped
```

Failures are **outside** skill progression (camera provenance, waverep flags, evaluations filter, member review gate, partial Android video copy). Treat as **pre-existing / environment** backlog, not v2 rollout blockers unless your release gate requires 100% pytest green.

### Collection errors (pre-existing)

- `tests/test_submission_chains_phase1.py` — SyntaxError
- `tests/test_replacement_upload_phase2.py` — collection error

---

## C. Remaining bugs / blockers

| Item | Severity | Notes |
|------|----------|--------|
| Shared dev grandfather floors **0/approved** | **Rollout blocker** | Column exists; capture not applied on `postgres` |
| 8 general pytest failures | Medium | Unrelated to progression v2 |
| 2 broken test modules | Low | Syntax/collection |
| Windows firewall / Public Wi-Fi for phone LAN | Ops | Documented Phase 6; not code |
| `flutter analyze` infos | Low | Style/deprecation |

**No new application defects** found in skill progression UI/API paths covered by Phase 7 fixes.

---

## D. Stored-tier consistency

### Authoritative (effective) tier in user-facing paths

| Surface | Source |
|---------|--------|
| Member Profile API | `skill_effective_tier` + `skill_tier_stored_legacy` (`member.py` + `build_skill_progression_snapshot`) |
| Participation API | `skill_effective_tier`, v2 policy fields |
| Flutter Profile / skill progress | `authoritativeSkillTierFromProfile()` → `skill_effective_tier` |
| Admin member list | `skill_effective_tier` / stored legacy (`admin_members.py`) |
| Rankings API rows | `skill_level` = **effective** via `resolve_member_skill_level()` |
| Admin web analytics | `skill_effective_tier ?? skill_level` fallback |
| Account profile modal | `skill_effective_tier` |

### Legacy stored label still referenced (document only)

| Consumer | Field | Risk |
|----------|-------|------|
| `users.skill_level_id` | DB column | Updated on **individual** admin recalc paths only; **no bulk recalc** in rollout plan |
| Rankings list UI | `r['skill_level']` from API | OK if API sends effective (it does) |
| Some edit/profile fallbacks | `profile['skill_level']` | Profile API should prefer effective; verify if old clients cache legacy key |
| XP leaderboard sort | `rank_position` | **Unchanged** (not skill tier) |

**No bulk `skill_level_id` updates** performed or recommended.

---

## E. Shared development read-only readiness

Script: `access_backend/scripts/phase7_shared_dev_readiness.py` (read-only SQL only).

| Check | Result |
|-------|--------|
| Database | `postgres` |
| DB user | `postgres` |
| `SKILL_PROGRESSION_ACTIVE_POLICY` | **v1** |
| API port (env) | **3001** |
| Approved members | **1** |
| Admin competency overrides | **0** |
| `skill_tier_grandfather_floor` column | **Present** |
| Grandfather floor rows populated | **0** |
| Grandfather `--apply` | **Not run** |

**Grandfather dry-run (shared dev, no `--apply`):** run `python scripts/skill_progression_capture_grandfather.py` with default `.env` before any future activation; review output for member count vs approved roster.

**Staging (reference, prior phases):** `access_skillprogression_staging`, policy **v2**, grandfather **8/8** on staging.

---

## F. Proposed shared-development rollout steps (future approval only)

1. **Checkpoint:** Explicit product/ops sign-off; maintenance window optional.
2. **Backup:** `pg_dump` of `postgres` (shared dev); verify restore on scratch DB (identity check script pattern from Phase 2).
3. **Identity safeguards:** Confirm `ACCESS_ENV_FILE` **not** staging file; `DB_NAME=postgres`; `API_PORT=3001`; `current_database()` before any write script.
4. **Schema:** Ensure migration applied (`skill_tier_grandfather_*` columns); run readonly identity script.
5. **v1 baseline:** Export participation/profile samples for approved members (JSON snapshot).
6. **Grandfather capture:** `skill_progression_capture_grandfather.py` **dry-run** → review → **`--apply` only after approval** (still v1 policy).
7. **Verify capture:** Count `skill_tier_grandfather_floor` = approved member count; no `--apply` on staging-only DB names from shared env by mistake.
8. **Activate v2:** Set `SKILL_PROGRESSION_ACTIVE_POLICY=v2` in **shared** `.env` only after steps 5–7 pass; restart API on **3001**.
9. **API smoke:** Health, login, `/member/profile`, `/member/participation` (policy v2), admin stats.
10. **Flutter:** `--dart-define` port **3001** (default); Profile effective tier vs participation; no staging URL in production build.
11. **Rollback:** Set policy back to **v1**; restart; grandfather floors remain; **no automatic bulk tier recalc**; document whether stored `skill_level_id` needs manual review (case-by-case only).
12. **Post-rollout:** Monitor Media Integrity and XP (unchanged logic); compare to v1 baseline export.

**Checkpoints requiring human approval:** backup verified, dry-run reviewed, `--apply`, v2 env flip, rollback decision.

---

## G. GO / NO-GO recommendation

| Area | Recommendation |
|------|----------------|
| **Staging v2 (3011)** | **GO** — Phase 6 device checks + Phase 7 Flutter 152/152 + staging API smoke |
| **Shared dev v2 activation** | **NO-GO** — grandfather floors **0**, capture/apply not done; explicit approval required |
| **Codebase readiness for rollout** | **CONDITIONAL GO** — progression tests green; fix or waive unrelated 8 pytest failures per your CI policy |
| **Production** | **NO-GO** — out of scope; not assessed |

**Stop here.** Await explicit authorization before shared-development v2 activation or grandfather `--apply` on `postgres`.

---

## Phase 7 code changes (local, uncommitted)

| File | Change |
|------|--------|
| `lib/mobile_app/screens/evaluation_screen.dart` | 1px card padding (overflow) |
| `test/api_config_lan_sync_test.dart` | Dynamic LAN host expectation |
| `test/api_config_staging_port_test.dart` | Correct dart-define port logic |
| `test/additional_quality_insights_test.dart` | Expand panel in widget test |
| `test/practice_member_evaluation_flow_test.dart` | Deferred preview expectations |
| `access_backend/scripts/phase7_shared_dev_readiness.py` | Read-only readiness helper |
| `access_backend/scripts/verify_staging_member_login.py` | From Phase 6 (ops) |
