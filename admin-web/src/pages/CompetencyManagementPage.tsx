import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import {
  Award,
  CalendarCheck,
  ClipboardList,
  Loader2,
  Search,
  UserCheck,
  Users,
  type LucideIcon,
} from 'lucide-react'
import {
  deactivateUserAccount,
  fetchEvaluations,
  fetchEvents,
  fetchMedia,
  fetchMemberRatingSummaries,
  fetchRankings,
  fetchTasks,
  fetchUsers,
  setUserStatus,
  updateCompetencyLevel,
  updateRankingRemarks,
} from '../api/admin'
import { AdminCard } from '../components/AdminCard'
import { AdminSelect } from '../components/AdminSelect'
import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminFeatureHeader } from '../components/AdminFeatureHeader'
import { PageLoader } from '../components/PageLoader'
import { PageToolbarRefreshButton } from '../components/PageToolbar'
import { useToast } from '../context/ToastContext'
import { CompetencyMembersTable } from '../components/competency/CompetencyMembersTable'
import { CompetencyProfileDrawer } from '../components/competency/CompetencyProfileDrawer'
import { TeamMembersTable } from '../components/documentation-team/TeamMembersTable'
import { TeamMemberProfileDrawer } from '../components/documentation-team/TeamMemberProfileDrawer'
import {
  buildCompetencyDashboard,
  competencyLevelToApiLabel,
  countByChip as countCompetencyByChip,
  filterAndSortCompetency,
  matchesChip,
  SORT_OPTIONS as COMPETENCY_SORT_OPTIONS,
  type CompetencyDashboardData,
  type CompetencyFilterChip,
  type CompetencyLevel,
  type CompetencyMember,
  type CompetencySortOption,
} from '../lib/competency'
import {
  buildTeamProfiles,
  countByChip as countTeamByChip,
  filterAndSortTeam,
  type TeamFilterChip,
  type TeamMemberProfile,
  type TeamSortOption,
} from '../lib/teamMembers'
import { FEATURE_HEADERS } from '../lib/featureHeaders'

export type CompetencyWorkspaceTab = 'directory' | 'skills'

const TEAM_FILTER_CHIPS: { id: TeamFilterChip; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'photographers', label: 'Photographers' },
  { id: 'videographers', label: 'Videographers' },
  { id: 'available', label: 'Available' },
  { id: 'assigned', label: 'Assigned' },
  { id: 'inactive', label: 'Inactive' },
]

const TEAM_SORT_OPTIONS: { id: TeamSortOption; label: string }[] = [
  { id: 'name', label: 'Name (A–Z)' },
  { id: 'tasksCompleted', label: 'Most assignments' },
]

const SKILLS_PRIMARY_CHIPS: CompetencyFilterChip[] = [
  'all',
  'advanced',
  'needsReview',
  'photographers',
  'videographers',
]

const SKILLS_CHIP_LABELS: Record<CompetencyFilterChip, string> = {
  needsReview: 'Needs review',
  all: 'All members',
  photographers: 'Photographers',
  videographers: 'Videographers',
  available: 'Available',
  assigned: 'Assigned',
  beginner: 'Beginner',
  intermediate: 'Intermediate',
  advanced: 'Top tier',
}

const LEVEL_OPTIONS: { id: CompetencyLevel | 'all'; label: string }[] = [
  { id: 'all', label: 'All levels' },
  { id: 'beginner', label: 'Beginner' },
  { id: 'intermediate', label: 'Intermediate' },
  { id: 'advanced', label: 'Advanced' },
]

function parseTab(raw: string | null): CompetencyWorkspaceTab {
  if (raw === 'directory' || raw === 'members') return 'directory'
  if (raw === 'skills' || raw === 'rankings') return 'skills'
  // Legacy /competency bookmarks open Skills & Rankings.
  return 'skills'
}

export function CompetencyManagementPage() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const { showToast } = useToast()

  const [tab, setTab] = useState<CompetencyWorkspaceTab>(() => parseTab(searchParams.get('tab')))
  const [team, setTeam] = useState<TeamMemberProfile[]>([])
  const [competency, setCompetency] = useState<CompetencyDashboardData | null>(null)
  const [pendingMembers, setPendingMembers] = useState(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const [directorySearch, setDirectorySearch] = useState('')
  const [directoryChip, setDirectoryChip] = useState<TeamFilterChip>('all')
  const [directorySort, setDirectorySort] = useState<TeamSortOption>('name')
  const [selectedTeam, setSelectedTeam] = useState<TeamMemberProfile | null>(null)

  const [skillsSearch, setSkillsSearch] = useState('')
  const [skillsChip, setSkillsChip] = useState<CompetencyFilterChip>('all')
  const [levelFilter, setLevelFilter] = useState<CompetencyLevel | 'all'>('all')
  const [skillsSort, setSkillsSort] = useState<CompetencySortOption>('performance')
  const [selectedCompetency, setSelectedCompetency] = useState<CompetencyMember | null>(null)

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
      const ratingMap = ratingSummaries as Record<
        string,
        { count: number; average_rating: number | null }
      >
      const profiles = buildTeamProfiles({
        users: userRows,
        tasks,
        events,
        rankings,
        media,
        evaluations,
        memberRatingSummaries: ratingMap,
      })
      const dashboard = buildCompetencyDashboard({
        users: userRows,
        tasks,
        events,
        rankings,
        media,
        evaluations,
        memberRatingSummaries: ratingMap,
      })
      setTeam(profiles)
      setCompetency(dashboard)
      setPendingMembers(
        userRows.filter(
          (u) =>
            String(u.role ?? '').toLowerCase() === 'member' &&
            String(u.status ?? '').toLowerCase() === 'pending',
        ).length,
      )
      setSelectedTeam((prev) => {
        if (!prev) return null
        return profiles.find((m) => m.id === prev.id) ?? null
      })
      setSelectedCompetency((prev) => {
        if (!prev) return null
        return dashboard.members.find((m) => m.profile.id === prev.profile.id) ?? null
      })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load competency workspace')
      setTeam([])
      setCompetency(null)
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
    const nextTab = parseTab(searchParams.get('tab'))
    setTab(nextTab)
    if (searchParams.get('view') === 'inactive') {
      setDirectoryChip('inactive')
      setTab('directory')
    }
    const q = searchParams.get('q')
    if (q) {
      setDirectorySearch(q)
      setSkillsSearch(q)
    }
  }, [navigate, searchParams])

  useEffect(() => {
    const memberId = Number(searchParams.get('member') || 0)
    if (!memberId || !competency) return
    const match = competency.members.find((m) => m.profile.id === memberId)
    if (match) {
      setTab('skills')
      setSelectedCompetency(match)
    }
  }, [competency, searchParams])

  function selectTab(next: CompetencyWorkspaceTab) {
    setTab(next)
    const params = new URLSearchParams(searchParams)
    params.set('tab', next)
    setSearchParams(params, { replace: true })
  }

  const overview = useMemo(
    () => ({
      total: team.length,
      available: countTeamByChip(team, 'available'),
      assigned: countTeamByChip(team, 'assigned'),
      needsReview: competency?.stats.needsReview ?? 0,
    }),
    [team, competency],
  )

  const directoryVisible = useMemo(
    () => filterAndSortTeam(team, { chip: directoryChip, search: directorySearch, sort: directorySort }),
    [team, directoryChip, directorySearch, directorySort],
  )

  const skillsVisible = useMemo(() => {
    if (!competency) return []
    const base = filterAndSortCompetency(competency.members, {
      chip: skillsChip,
      search: skillsSearch,
      sort: skillsSort,
    })
    if (levelFilter === 'all') return base
    return base.filter((m) => m.currentLevel === levelFilter)
  }, [competency, skillsChip, skillsSearch, skillsSort, levelFilter])

  const levelCounts = useMemo(() => {
    if (!competency) return { all: 0, beginner: 0, intermediate: 0, advanced: 0 }
    const base = competency.members.filter((m) => matchesChip(m, skillsChip))
    return {
      all: base.length,
      beginner: base.filter((m) => m.currentLevel === 'beginner').length,
      intermediate: base.filter((m) => m.currentLevel === 'intermediate').length,
      advanced: base.filter((m) => m.currentLevel === 'advanced').length,
    }
  }, [competency, skillsChip])

  async function handleDeactivate(member: TeamMemberProfile) {
    await deactivateUserAccount(member.id)
    await load()
  }

  async function handleStatusChange(member: TeamMemberProfile, status: string, reason?: string) {
    await setUserStatus(member.id, status, reason)
    await load()
  }

  async function handleSendNotesToMember(notes: string): Promise<boolean> {
    if (!selectedCompetency) return false
    const trimmed = notes.trim()
    if (!trimmed) {
      showToast('Write a note before sending to the member')
      return false
    }
    setSaving(true)
    try {
      await updateRankingRemarks(selectedCompetency.profile.id, trimmed, { notifyMember: true })
      await load()
      showToast(`Note sent to ${selectedCompetency.profile.name}`)
      return true
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'Failed to send note')
      return false
    } finally {
      setSaving(false)
    }
  }

  async function handleUpdateLevel(level: CompetencyLevel | 'system') {
    if (!selectedCompetency) return
    setSaving(true)
    try {
      const apiLevel = level === 'system' ? null : competencyLevelToApiLabel(level)
      await updateCompetencyLevel(selectedCompetency.profile.id, apiLevel)
      await load()
      showToast(
        level === 'system'
          ? `Using system recommendation for ${selectedCompetency.profile.name}`
          : `Competency level updated for ${selectedCompetency.profile.name}`,
      )
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'Failed to update competency level')
    } finally {
      setSaving(false)
    }
  }

  const header = FEATURE_HEADERS.competency

  return (
    <div className="mx-auto min-w-0 max-w-[1400px] space-y-4 pb-8">
      <AdminFeatureHeader
        icon={header.icon}
        title={header.title}
        description={header.description}
        backTo="/"
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              onClick={() => navigate('/account-management?view=registrations&tab=members')}
              className="inline-flex items-center gap-1.5 rounded-xl border border-[var(--color-border)] bg-white/80 px-3 py-2 text-xs font-semibold text-[#4B6C83] hover:bg-white"
            >
              <ClipboardList size={14} aria-hidden />
              Pending registrations
              {pendingMembers > 0 ? (
                <span className="rounded-full bg-[var(--color-accent-cyan)]/20 px-1.5 py-0.5 text-[10px] font-bold text-[var(--color-accent-cyan)]">
                  {pendingMembers}
                </span>
              ) : null}
            </button>
            <PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />
          </div>
        }
      />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      <div className="grid grid-cols-2 gap-2 lg:grid-cols-4">
        <SummaryCard
          icon={Users}
          label="Total Members"
          hint="On the roster"
          value={overview.total}
          accent="var(--color-accent-blue)"
        />
        <SummaryCard
          icon={UserCheck}
          label="Available"
          hint="Ready to assign"
          value={overview.available}
          accent="var(--color-success)"
        />
        <SummaryCard
          icon={CalendarCheck}
          label="Currently Assigned"
          hint="On an event"
          value={overview.assigned}
          accent="var(--color-warning)"
        />
        <SummaryCard
          icon={Award}
          label="Needs Review"
          hint="Competency follow-up"
          value={overview.needsReview}
          accent="var(--color-accent-cyan)"
          onClick={() => {
            selectTab('skills')
            setSkillsChip('needsReview')
            setLevelFilter('all')
          }}
        />
      </div>

      <div className="overflow-hidden rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-[0_1px_3px_rgba(15,23,42,0.05)]">
        <div
          className="flex gap-1 border-b border-[var(--color-border)] bg-[var(--color-surface-muted)]/60 p-1.5"
          role="tablist"
          aria-label="Competency workspace"
        >
          <TabButton
            active={tab === 'directory'}
            onClick={() => selectTab('directory')}
            label="Member Overview"
          />
          <TabButton
            active={tab === 'skills'}
            onClick={() => selectTab('skills')}
            label="Skills & Rankings"
          />
        </div>

        <div className="space-y-3 p-3 sm:p-4">
          {tab === 'directory' ? (
            <>
              <div className="flex flex-wrap gap-1.5">
                {TEAM_FILTER_CHIPS.map((c) => (
                  <button
                    key={c.id}
                    type="button"
                    onClick={() => setDirectoryChip(c.id)}
                    className={[
                      'rounded-full px-3 py-1 text-xs font-bold transition',
                      directoryChip === c.id
                        ? 'bg-[var(--color-accent-blue)] text-white'
                        : 'border border-[var(--color-border)] bg-white text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
                    ].join(' ')}
                  >
                    {c.label} ({countTeamByChip(team, c.id)})
                  </button>
                ))}
              </div>

              <div className="flex flex-col gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)]/40 p-2">
                <div className="grid items-center gap-2 md:grid-cols-[1fr_auto]">
                  <div className="relative min-w-0">
                    <Search
                      size={15}
                      className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]"
                    />
                    <input
                      value={directorySearch}
                      onChange={(e) => setDirectorySearch(e.target.value)}
                      placeholder="Search members…"
                      aria-label="Search members"
                      className="admin-input w-full rounded-lg py-1.5 pl-9 pr-3 text-sm"
                    />
                  </div>
                  <AdminSelect
                    className="md:w-52"
                    buttonClassName="rounded-lg py-1.5"
                    value={directorySort}
                    onChange={(v) => setDirectorySort(v as TeamSortOption)}
                    aria-label="Sort team members"
                    options={TEAM_SORT_OPTIONS.map((o) => ({
                      value: o.id,
                      label: `Sort: ${o.label}`,
                    }))}
                  />
                </div>
                <p className="px-1 text-[11px] text-[var(--color-text-secondary)]">
                  {directoryVisible.length} member{directoryVisible.length === 1 ? '' : 's'} shown
                </p>
              </div>

              {loading && team.length === 0 ? (
                <PageLoader label="Loading members…" />
              ) : (
                <TeamMembersTable members={directoryVisible} onViewProfile={setSelectedTeam} />
              )}
            </>
          ) : (
            <>
              {competency ? (
                <div className="flex flex-wrap gap-1.5">
                  {SKILLS_PRIMARY_CHIPS.map((id) => (
                    <button
                      key={id}
                      type="button"
                      onClick={() => {
                        setSkillsChip(id)
                        setLevelFilter('all')
                      }}
                      className={[
                        'rounded-full px-3 py-1 text-xs font-bold transition',
                        skillsChip === id
                          ? 'bg-[var(--color-accent-blue)] text-white'
                          : 'border border-[var(--color-border)] bg-white text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
                      ].join(' ')}
                    >
                      {SKILLS_CHIP_LABELS[id]} ({countCompetencyByChip(competency.members, id)})
                    </button>
                  ))}
                </div>
              ) : null}

              <div className="flex flex-col gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)]/40 p-2 sm:p-3">
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-[minmax(0,1fr)_minmax(0,10rem)_minmax(0,10rem)]">
                  <div className="relative min-w-0 sm:col-span-2 xl:col-span-1">
                    <Search
                      size={16}
                      className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]"
                    />
                    <input
                      value={skillsSearch}
                      onChange={(e) => setSkillsSearch(e.target.value)}
                      placeholder="Search name, role, or competency level…"
                      className="admin-input w-full rounded-xl py-2 pl-9 pr-3 text-sm"
                    />
                  </div>
                  <AdminSelect
                    className="min-w-0 w-full"
                    value={levelFilter}
                    onChange={(v) => setLevelFilter(v as CompetencyLevel | 'all')}
                    aria-label="Filter by competency level"
                    options={LEVEL_OPTIONS.map((o) => ({
                      value: o.id,
                      label: `${o.label} (${levelCounts[o.id]})`,
                    }))}
                  />
                  <AdminSelect
                    className="min-w-0 w-full"
                    value={skillsSort}
                    onChange={(v) => setSkillsSort(v as CompetencySortOption)}
                    aria-label="Sort members"
                    options={COMPETENCY_SORT_OPTIONS.map((o) => ({
                      value: o.id,
                      label: `Sort: ${o.label}`,
                    }))}
                  />
                </div>
                {competency ? (
                  <p className="flex flex-wrap gap-x-3 gap-y-1 text-xs text-[var(--color-text-muted)]">
                    <span>{competency.stats.totalMembers} members</span>
                    <span>{competency.stats.needsReview} need review</span>
                    <span>{competency.stats.advancedCount} advanced</span>
                    <span>{competency.stats.intermediateCount} intermediate</span>
                    <span>{competency.stats.beginnerCount} beginner</span>
                    <span>Overrides sync to the server</span>
                  </p>
                ) : null}
              </div>

              {loading && !competency ? (
                <div className="flex justify-center py-16">
                  <Loader2 className="animate-spin text-[var(--color-text-muted)]" size={28} />
                </div>
              ) : skillsVisible.length === 0 ? (
                <AdminCard
                  dashed
                  padding="lg"
                  className="text-center text-sm text-[var(--color-text-secondary)]"
                >
                  {skillsChip === 'needsReview' && levelFilter === 'all' && !skillsSearch.trim() ? (
                    <>
                      <Award size={28} className="mx-auto text-[var(--color-text-muted)]" />
                      <p className="mt-3 font-semibold text-[var(--color-text-primary)]">
                        Review queue is clear
                      </p>
                      <p className="mt-1">
                        All members match their system recommendations with clean integrity records.
                      </p>
                    </>
                  ) : (
                    <>
                      <p className="font-semibold text-[var(--color-text-primary)]">
                        No members match your filters
                      </p>
                      <p className="mt-1">Try another filter, level, or clear your search.</p>
                    </>
                  )}
                </AdminCard>
              ) : (
                <>
                  <div className="flex items-center justify-between gap-2">
                    <h2 className="text-sm font-bold text-[var(--color-text-primary)]">
                      Member rankings and competency
                    </h2>
                    <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
                      {skillsVisible.length} shown
                    </span>
                  </div>
                  <CompetencyMembersTable
                    members={skillsVisible}
                    onViewProfile={setSelectedCompetency}
                  />
                </>
              )}
            </>
          )}
        </div>
      </div>

      {selectedTeam ? (
        <TeamMemberProfileDrawer
          member={selectedTeam}
          onClose={() => setSelectedTeam(null)}
          onDeactivate={handleDeactivate}
          onStatusChange={handleStatusChange}
        />
      ) : null}

      {selectedCompetency ? (
        <CompetencyProfileDrawer
          member={selectedCompetency}
          saving={saving}
          onClose={() => setSelectedCompetency(null)}
          onSendNotesToMember={handleSendNotesToMember}
          onUpdateLevel={handleUpdateLevel}
        />
      ) : null}
    </div>
  )
}

function TabButton({
  active,
  onClick,
  label,
}: {
  active: boolean
  onClick: () => void
  label: string
}) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      onClick={onClick}
      className={[
        'flex-1 rounded-xl px-3 py-2 text-sm font-bold transition sm:flex-none sm:px-4',
        active
          ? 'bg-white text-[var(--color-accent-blue)] shadow-sm ring-1 ring-[var(--color-border)]'
          : 'text-[var(--color-text-secondary)] hover:bg-white/70 hover:text-[var(--color-text-primary)]',
      ].join(' ')}
    >
      {label}
    </button>
  )
}

function SummaryCard({
  icon: Icon,
  label,
  hint,
  value,
  accent,
  onClick,
}: {
  icon: LucideIcon
  label: string
  hint: string
  value: number
  accent: string
  onClick?: () => void
}) {
  const className =
    'flex h-[68px] items-center gap-2.5 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-3 text-left shadow-[0_1px_2px_rgba(15,39,68,0.04)]'
  const inner = (
    <>
      <span
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg"
        style={{
          backgroundColor: `color-mix(in srgb, ${accent} 14%, white)`,
          color: accent,
        }}
      >
        <Icon size={16} strokeWidth={2.25} aria-hidden />
      </span>
      <span className="min-w-0">
        <span className="block text-lg font-extrabold leading-none tabular-nums text-[var(--color-text-primary)]">
          {value}
        </span>
        <span className="mt-0.5 block truncate text-[11px] font-semibold leading-tight text-[var(--color-text-primary)]">
          {label}
        </span>
        <span className="block truncate text-[10px] leading-tight text-[var(--color-text-secondary)]">
          {hint}
        </span>
      </span>
    </>
  )
  if (onClick) {
    return (
      <button type="button" onClick={onClick} className={`${className} transition hover:bg-[var(--color-surface-hover)]`}>
        {inner}
      </button>
    )
  }
  return <div className={className}>{inner}</div>
}
