import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams, useNavigate } from 'react-router-dom'
import { CalendarCheck, Search, UserCheck, UserPlus, Users, type LucideIcon } from 'lucide-react'
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
      total: all.length,
      available: countByChip(all, 'available'),
      assigned: countByChip(all, 'assigned'),
      pendingMembers,
    }),
    [all, pendingMembers],
  )

  async function handleDeactivate(member: TeamMemberProfile, deleteUploads: boolean) {
    const result = await setUserStatus(member.id, 'rejected', 'Deactivated by administrator', {
      deleteUploads,
    })
    if (result.message) {
      // Toast not wired on this page; parent reload reflects changes.
      void result.message
    }
    await load()
  }

  async function handleStatusChange(member: TeamMemberProfile, status: string, reason?: string) {
    await setUserStatus(member.id, status, reason)
    await load()
  }

  return (
    <div className="mx-auto max-w-[1400px] space-y-3">
      <AdminPageHeader
        title="Member Management"
        subtitle="Day-to-day operations: who is available, who is on assignment, and member account status."
        backTo="/"
        actions={
          <PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />
        }
      />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      <div className="grid grid-cols-2 gap-2 lg:grid-cols-4">
        <MemberSummaryCard
          icon={Users}
          label="Total Members"
          hint="on the roster"
          value={stats.total}
          color="var(--color-accent-blue)"
        />
        <MemberSummaryCard
          icon={UserCheck}
          label="Available"
          hint="ready to assign"
          value={stats.available}
          color="var(--color-success)"
        />
        <MemberSummaryCard
          icon={CalendarCheck}
          label="Currently Assigned"
          hint="on an event"
          value={stats.assigned}
          color="var(--color-warning)"
        />
        <MemberSummaryCard
          icon={UserPlus}
          label="Pending Registrations"
          hint="awaiting review"
          value={stats.pendingMembers}
          color="var(--color-accent-cyan)"
        />
      </div>

      <div className="flex flex-wrap gap-1.5">
        {FILTER_CHIPS.map((c) => (
          <button
            key={c.id}
            type="button"
            onClick={() => setChip(c.id)}
            className={[
              'rounded-full px-3 py-1 text-xs font-bold transition',
              chip === c.id
                ? 'bg-[var(--color-accent-blue)] text-white'
                : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
            ].join(' ')}
          >
            {c.label} ({countByChip(all, c.id)})
          </button>
        ))}
      </div>

      <div className="flex flex-col gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-2 shadow-[0_1px_2px_rgba(15,39,68,0.04)]">
        <div className="grid items-center gap-2 md:grid-cols-[1fr_auto]">
          <div className="relative min-w-0">
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search members…"
              aria-label="Search members"
              className="admin-input w-full rounded-lg py-1.5 pl-9 pr-3 text-sm"
            />
          </div>
          <AdminSelect
            className="md:w-52"
            buttonClassName="rounded-lg py-1.5"
            value={sort}
            onChange={(v) => setSort(v as TeamSortOption)}
            aria-label="Sort team members"
            options={SORT_OPTIONS.map((o) => ({ value: o.id, label: `Sort: ${o.label}` }))}
          />
        </div>
        <p className="px-1 text-[11px] text-[var(--color-text-secondary)]">
          {visible.length} member{visible.length === 1 ? '' : 's'} shown
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

function MemberSummaryCard({
  icon: Icon,
  label,
  hint,
  value,
  color,
}: {
  icon: LucideIcon
  label: string
  hint: string
  value: number
  color: string
}) {
  return (
    <div
      className="flex h-[62px] items-center gap-2.5 rounded-xl border border-[var(--color-border)] px-3 shadow-[0_1px_2px_rgba(15,39,68,0.04)]"
      style={{ backgroundColor: `color-mix(in srgb, ${color} 6%, var(--color-surface))` }}
    >
      <span
        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg"
        style={{ backgroundColor: `color-mix(in srgb, ${color} 16%, var(--color-surface))`, color }}
      >
        <Icon size={16} strokeWidth={2.25} />
      </span>
      <span className="min-w-0">
        <span className="block text-lg font-extrabold leading-none tabular-nums text-[var(--color-text-primary)]">
          {value}
        </span>
        <span className="mt-0.5 block truncate text-[11px] font-semibold leading-tight text-[var(--color-text-primary)]">
          {label}
        </span>
        <span className="block truncate text-[10px] leading-tight text-[var(--color-text-secondary)]">{hint}</span>
      </span>
    </div>
  )
}
