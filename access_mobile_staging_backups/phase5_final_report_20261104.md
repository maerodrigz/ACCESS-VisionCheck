# Phase 5: Skill Tier Display Consistency and 320px Overflow

Generated: 2026-11-04 (local, untracked)

## A. Files changed

**Backend**

- `access_backend/app/api/routes/member.py` — profile uses progression snapshot for effective tier
- `access_backend/app/schemas/member_api.py` — `ProfileOut`: `skill_effective_tier`, `skill_tier_stored_legacy`; `skill_level` = effective
- `access_backend/app/crud/admin_members.py` — effective + legacy fields for admin member list/detail
- `access_backend/app/schemas/admin_member.py` — `skill_effective_tier`, `skill_tier_stored_legacy`
- `access_backend/app/services/assignment_recommendations.py` — recommendation label uses `resolve_member_skill_level` (score formula unchanged)

**Flutter**

- `lib/shared/controllers/participation_quota_sync.dart` — `authoritativeSkillTierFromProfile()`
- `lib/shared/controllers/member_data_controller.dart` — profile sync uses effective tier
- `lib/mobile_app/widgets/member_dashboard_competency_progress.dart` — 320px responsive fixes (track, chip, motivation, button, narrow card)

**Admin web**

- `admin-web/src/lib/analytics.ts` — participation rows prefer `skill_effective_tier`
- `admin-web/src/components/account-management/AccountProfileModal.tsx` — display effective tier

**Tests**

- `access_backend/tests/test_skill_progression_staging_readiness.py` — profile vs participation, tier field cases
- `test/participation_quota_sync_test.dart` — profile tier mapping

## B. Profile API consistency

`GET /api/member/profile`:

| Field | Value |
|-------|--------|
| `skill_level` | **Effective** tier (same as participation; backward-compatible display) |
| `skill_effective_tier` | Explicit effective tier |
| `skill_tier_stored_legacy` | `users.skill_level_id` label (audit only) |

Verified: stored **Expert** + effective **Beginner** matches participation; no `skill_level_id` writes.

## C. Flutter responsive tests

| Width | Result |
|-------|--------|
| 320px (Carlos live staging JSON) | **PASS** |
| 360px | **PASS** |
| 393px | **PASS** |
| 320px @ 1.3 text scale (profile section) | **PASS** |

Fixes: compact track labels under 360px, constrained chip/motivation/button rows, narrow card padding and badge sizing.

## D. Admin/analytics consistency

- Admin member API: `skill_level` = effective; `skill_tier_stored_legacy` = stored
- Analytics participation export: prefers `skill_effective_tier`
- Account profile modal: shows effective tier
- Assignment recommendations: **display** tier = effective; ranking score math unchanged

Rankings admin API was already effective via `resolve_member_skill_level`.

## E. Regression tests

- Backend: tier field + `test_profile_effective_tier_matches_participation` — **PASS**
- Flutter: phase4 Carlos layouts, profile section, participation mapping, policy widgets — **PASS**

## F. Live device test

**NOT TESTED** (no emulator/device session executed in this phase).

**Staging run (temporary, does not change default 3001 config):**

```bash
flutter run -t lib/mobile_app/main_mobile.dart --dart-define=API_PORT=3011
# Physical phone on same LAN:
# flutter run -t lib/mobile_app/main_mobile.dart --dart-define=API_BASE_URL=http://<PC_IP>:3011
```

**Manual checklist**

1. Confirm orange offline banner is absent after login.
2. Profile hero **Skill:** line matches skill progress **Your level** (Intermediate for Carlos).
3. Skill progress shows v2 remainder copy and 3/day cap note.
4. Pull-to-refresh / re-open Profile: tier unchanged after participation sync.
5. Optional: sign in as member with stored Expert / effective Beginner on staging; hero shows **Beginner**.

Refresh live JSON: `python access_backend/scripts/phase4_export_staging_participation.py` (staging API on 3011).

## G. Remaining rollout blockers

1. **Manual device smoke** on staging :3011 not done.
2. **Stored `skill_level_id`** still stale for 5/8 staging fixtures until approved recalc (by design).
3. Some admin surfaces may still show legacy fields if they bypass updated member API (audit `skill_tier_stored_legacy` when needed).
4. **Shared dev / production** policy still v1; v2 rollout needs separate approval.

## H. Recommendation

| Scope | Verdict |
|-------|---------|
| **Continue staging v2 QA** | **GO** — profile/participation alignment and 320px layout fixed |
| **Shared dev / production v2** | **NO-GO** until device smoke + rollout approval |

No commit, push, deploy, migration, recalc, or grandfather `--apply` in Phase 5.
