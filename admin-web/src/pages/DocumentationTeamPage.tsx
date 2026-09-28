import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams, useNavigate } from 'react-router-dom'
import { Search, UserPlus } from 'lucide-react'
import {
  fetchEvaluations,
  fetchEvents,
  fetchMedia,
  fetchMemberRatingSummaries,
  fetchRankings,
  fetchTasks,
  fetchUsers,
  setUserStatus,
} from '../api/admin'
import { PageLoader } from '../components/PageLoader'
import { TeamMembersTable } from '../components/documentation-team/TeamMembersTable'
import { TeamMemberProfileDrawer } from '../components/documentation-team/TeamMemberProfileDrawer'
import { PageToolbarRefreshButton } from '../components/PageToolbar'
import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { AdminSelect } from '../components/AdminSelect'
import {
  buildTeamProfiles,
  countByChip,
  filterAndSortTeam,
  type TeamFilterChip,
  type TeamMemberProfile,
  type TeamSortOption,
} from '../lib/teamMembers'

const FILTER_CHIPS: { id: TeamFilterChip; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'photographers', label: 'Photographers' },
  { id: 'videographers', label: 'Videographers' },
  { id: 'available', label: 'Available' },
  { id: 'assigned', label: 'Assigned' },
  { id: 'inactive', label: 'Inactive' },
]

const SORT_OPTIONS: { id: TeamSortOption; label: string }[] = [
  { id: 'name', label: 'Name (A–Z)' },
  { id: 'tasksCompleted', label: 'Most assignments' },
]

export function DocumentationTeamPage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [all, setAll] = useState<TeamMemberProfile[]>([])
  const [pendingMembers, setPendingMembers] = useState(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [chip, setChip] = useState<TeamFilterChip>(() => {
    const view = searchParams.get('view')
    return view === 'inactive' ? 'inactive' : 'all'
  })
  const [sort, setSort] = useState<TeamSortOption>('name')
  const [selected, setSelected] = useState<TeamMemberProfile | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [users, tasks, events, rankings, media, evaluations, ratingSummaries] = await Promise.all([
        fetchUsers(),
        fetchTasks(),
        fetchEvents(),
        fetchRankings(),
        fetchMedia(),
        fetchEvaluations(),
        fetchMemberRatingSummaries().catch(() => ({})),
      ])
      const userRows = users as unknown as Record<string, unknown>[]
      const profiles = buildTeamProfiles({
        users: userRows,
        tasks,
        events,
        rankings,
        media,
        evaluations,
        memberRatingSummaries: ratingSummaries as Record<
          string,
          { count: number; average_rating: number | null }
        >,
      })
      setAll(profiles)
      setPendingMembers(
        userRows.filter(
          (u) =>
            String(u.role ?? '').toLowerCase() === 'member' &&
            String(u.status ?? '').toLowerCase() === 'pending',
        ).length,
      )
      setSelected((prev) => {
        if (!prev) return null
        return profiles.find((m) => m.id === prev.id) ?? null
      })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load team')
      setAll([])
      setPendingMembers(0)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  useEffect(() => {
    if (searchParams.get('view') === 'pending') {
      navigate('/account-management?view=registrations&tab=members', { replace: true })
      return
    }
    if (searchParams.get('view') === 'inactive') {
      setChip('inactive')
    }
    const q = searchParams.get('q')
    if (q) setSearch(q)
  }, [navigate, searchParams])

  const visible = useMemo(
    () => filterAndSortTeam(all, { chip, search, sort }),
    [all, chip, search, sort],
  )

  const stats = useMemo(
    () => ({
      available: countByChip(all, 'available'),
      pendingMembers,
    }),
    [all, pendingMembers],
  )

  async function handleDeactivate(member: TeamMemberProfile) {
    await setUserStatus(member.id, 'rejected')
    await load()
  }

  async function handleStatusChange(member: TeamMemberProfile, status: string, reason?: string) {
    await setUserStatus(member.id, status, reason)
    await load()
  }

  return (
    <div className="space-y-6">
      <AdminPageHeader
        title="Team Roster"
        subtitle="Day-to-day operations: who is available, who is on assignment, and member account status."
        backTo="/"
        actions={
          <>
            <PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />
            <Link
              to="/account-management?view=registrations&tab=members"
              className="inline-flex h-10 shrink-0 items-center gap-2 whitespace-nowrap rounded-xl bg-[var(--color-accent-blue)] px-4 text-sm font-bold text-white hover:opacity-95"
            >
              <UserPlus size={16} />
              Review registrations
              {stats.pendingMembers > 0 && (
                <span className="rounded-full bg-white/20 px-2 py-0.5 text-xs">{stats.pendingMembers}</span>
              )}
            </Link>
          </>
        }
      />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      <div className="flex flex-wrap gap-2">
        {FILTER_CHIPS.map((c) => (
          <button
            key={c.id}
            type="button"
            onClick={() => setChip(c.id)}
            className={[
              'rounded-full px-4 py-1.5 text-xs font-bold transition',
              chip === c.id
                ? 'bg-[var(--color-accent-blue)] text-white'
                : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
            ].join(' ')}
          >
            {c.label} ({countByChip(all, c.id)})
          </button>
        ))}
      </div>

      <div className="flex flex-col gap-3 rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3 md:p-4">
        <div className="grid gap-3 md:grid-cols-[1fr_auto]">
          <div className="relative min-w-0">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search members…"
              className="admin-input w-full rounded-xl py-2 pl-9 pr-3 text-sm"
            />
          </div>
          <AdminSelect
            value={sort}
            onChange={(v) => setSort(v as TeamSortOption)}
            aria-label="Sort team members"
            options={SORT_OPTIONS.map((o) => ({ value: o.id, label: `Sort: ${o.label}` }))}
          />
        </div>
        <p className="text-xs text-[var(--color-text-secondary)]">
          {visible.length} member{visible.length === 1 ? '' : 's'} shown · {stats.available} available ·{' '}
          {stats.pendingMembers} pending registration{stats.pendingMembers === 1 ? '' : 's'}
        </p>
      </div>

      {loading && all.length === 0 ? (
        <PageLoader label="Loading team…" />
      ) : (
        <TeamMembersTable members={visible} onViewProfile={setSelected} />
      )}

      {selected && (
        <TeamMemberProfileDrawer
          member={selected}
          onClose={() => setSelected(null)}
          onDeactivate={handleDeactivate}
          onStatusChange={handleStatusChange}
        />
      )}
    </div>
  )
}
