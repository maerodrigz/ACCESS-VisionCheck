# Phase 4: Live Flutter Staging Verification and Tier Consistency Audit

Generated: 2026-11-03 (local, untracked)

## A. Live Flutter test result

| Check | Result |
|-------|--------|
| End-to-end device/emulator login → Profile navigation | **NOT TESTED** (no manual session recorded) |
| Staging API reachable on `127.0.0.1:3011` | **PASS** |
| Live participation export (Carlos) | **PASS** — `phase4_staging_participation_live.json` |
| `ApiConfig` with `--dart-define=API_PORT=3011` | **PASS** (`test/api_config_staging_port_test.dart`) |
| API → `applyParticipation` → `MemberCompetencySnapshot` (Carlos) | **PASS** |
| Profile skill section @ 360px / 393px (Carlos live fields) | **PASS** |
| Profile skill section @ 320px (Carlos live fields) | **FAIL** — RenderFlex overflow ~9.3px (long v2 eval gate copy) |

**Temporary staging run (does not change defaults):**

```text
flutter run -t lib/mobile_app/main_mobile.dart --dart-define=API_PORT=3011
# physical phone: add --dart-define=API_PUBLIC_HOST=<PC LAN IPv4>
# or: --dart-define=API_BASE_URL=http://127.0.0.1:3011
```

Shared dev default remains port **3001** in `api_config.dart`.

**Live Carlos participation (after API restart):**

- `skill_progression_policy_version`: v2
- `skill_computed_tier_v2_strict`: Beginner
- `skill_computed_tier_v2_grandfather_adjusted`: Intermediate
- `skill_effective_tier`: Intermediate
- `skill_tier_stored_legacy`: Intermediate (aligned for Carlos)
- `daily_evaluation_limit`: 3
- Remaining toward Advanced: 9 evals, 9 distinct days

Evidence file: `access_mobile_staging_backups/phase4_staging_participation_live.json`

---

## B. Tier field definitions and changes

**Additive API fields** on `GET /api/member/participation` (existing fields unchanged):

| Field | Meaning |
|-------|---------|
| `skill_computed_tier` | Active-policy computed tier (legacy clients). Under v2 includes grandfather on computed path. |
| `skill_computed_tier_v1` | v1 quality + eligible-count gates. |
| `skill_computed_tier_v2_strict` | v2 all three gates, **before** grandfather floor. |
| `skill_computed_tier_v2_grandfather_adjusted` | v2 after `apply_grandfather_floor_v2`. |
| `skill_computed_tier_v2_preview` | Same as grandfather-adjusted v2 (name kept for v1-era clients). |
| `skill_effective_tier` | Admin override if set, else `skill_computed_tier`. **Flutter Profile uses this after participation sync.** |
| `skill_tier_grandfather_floor` | Captured floor from Phase 2. |
| `skill_tier_stored_legacy` | `users.skill_level_id` label (may be stale). |
| `skill_admin_competency_override` | Ranking override when set. |

Snapshot dataclass: added `computed_tier_v2_raw` (internal name for strict v2).

Docs: `access_backend/docs/SKILL_PROGRESSION_V2_ACTIVATION.md` (field table).

---

## C. Stored tier consumer inventory

| Consumer | Source today | Stale risk on staging | Recommendation |
|----------|--------------|----------------------|----------------|
| **Flutter Profile hero** (`profileSkillLevel`) | `GET /member/profile` → then **overwritten** by `skill_effective_tier` when participation syncs | Low after sync; brief flash if profile loads last | Keep **effective** from participation; optional: profile API should expose effective or omit misleading stored label |
| **Flutter skill progress card** | `MemberCompetencySnapshot.fromAppState()` → effective + participation remainders | Low | **Effective + participation** (current) |
| **Flutter Rankings self card** | Rankings API `skill_level` field | Low | Rankings list uses **resolve_member_skill_level** → effective |
| **Flutter Rankings list rows** | `r['skill_level']` from rankings endpoint | Low on staging API | **Effective** from backend rankings payload |
| **GET /member/profile** `skill_level` | **Stored** `users.skill_level_id` | **High** for 5/8 staging fixtures | Prefer **effective** or add `skill_effective_tier` to profile |
| **Admin rankings / competency** | `skill_level` + `computed_skill_level` from `resolve_member_skill_level` | Low | **Effective** (already) |
| **Admin account management** | User CRUD `skill_level` stored | Medium | Display effective from rankings join where available |
| **Admin analytics / assign team** | Often stored `skill_level` on user DTO | Medium | Prefer rankings effective + new strict/grandfather fields for v2 audits |
| **Assignment recommendations** | Falls back to **stored** if payload missing | Medium | Use progression snapshot effective |
| **Milestones** | `on_skill_level_recalculated` on **recalc** only | N/A until recalc | No change in Phase 4 |
| **Notifications** | No direct `skill_level_id` reads found | — | — |
| **Media pipeline / AI review** | Calls `recalculate_skill_level` (writes stored) | Disabled path on staging Phase 3 | Out of scope until approved recalc |
| **Leaderboard sort** | XP / points, not stored tier | None | No change |

---

## D. Regression test results

**Backend (pytest):**

- `test_tier_fields_carlos_*`, admin override, stored legacy, v1 additive keys — **PASS**
- Existing participation contract + grandfather tests — **PASS**

**Flutter:**

- `phase4_carlos_staging_profile_widget_test` (live JSON mapping) — **PASS**
- Layout 360 / 393 — **PASS**; 320 — **FAIL** (overflow)
- Prior policy/profile widget tests — **PASS**

---

## E. Remaining rollout blockers

1. **Profile GET** still returns **stored** tier; can contradict participation until sync completes.
2. **Five staging members** with stored Advanced/Expert/Intermediate vs effective Beginner (until approved recalc).
3. **320px Profile overflow** with real Carlos v2 remainder messaging.
4. **No full manual Flutter navigation** smoke on device against :3011.
5. **Admin/analytics** paths still show stored tier in places (see inventory).

---

## F. GO / NO-GO

| Scope | Verdict |
|-------|---------|
| Continue **staging v2** QA | **GO** — tier fields clarified; Carlos strict vs grandfather visible in API |
| **Shared dev / production rollout** | **NO-GO** — stored-tier drift, Profile API mismatch, 320px overflow, no device smoke |

No commit, push, deploy, recalc, or grandfather `--apply` in Phase 4.
