import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { Award, Loader2, Search } from 'lucide-react'
import {
  fetchEvaluations,
  fetchEvents,
  fetchMedia,
  fetchMemberRatingSummaries,
  fetchRankings,
  fetchTasks,
  fetchUsers,
  updateCompetencyLevel,
  updateRankingRemarks,
} from '../api/admin'
import { AdminCard } from '../components/AdminCard'
import { AdminSelect } from '../components/AdminSelect'
import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { PageToolbarRefreshButton } from '../components/PageToolbar'
import { useToast } from '../context/ToastContext'
import { CompetencyMembersTable } from '../components/competency/CompetencyMembersTable'
import { CompetencyProfileDrawer } from '../components/competency/CompetencyProfileDrawer'
import {
  buildCompetencyDashboard,
  competencyLevelToApiLabel,
  countByChip,
  filterAndSortCompetency,
  matchesChip,
  SORT_OPTIONS,
  type CompetencyDashboardData,
  type CompetencyFilterChip,
  type CompetencyLevel,
  type CompetencyMember,
  type CompetencySortOption,
} from '../lib/competency'
const PRIMARY_CHIPS: CompetencyFilterChip[] = [
  'all',
  'advanced',
  'needsReview',
  'photographers',
  'videographers',
]

const PRIMARY_CHIP_LABELS: Record<CompetencyFilterChip, string> = {
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

export function CompetencyManagementPage() {
  const [searchParams] = useSearchParams()
  const [data, setData] = useState<CompetencyDashboardData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [chip, setChip] = useState<CompetencyFilterChip>('all')
  const [levelFilter, setLevelFilter] = useState<CompetencyLevel | 'all'>('all')
  const [sort, setSort] = useState<CompetencySortOption>('performance')
  const [selected, setSelected] = useState<CompetencyMember | null>(null)
  const { showToast } = useToast()
  const [saving, setSaving] = useState(false)

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
      const dashboard = buildCompetencyDashboard({
        users: users as unknown as Record<string, unknown>[],
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
      setData(dashboard)
      setSelected((prev) => {
        if (!prev) return null
        return dashboard.members.find((m) => m.profile.id === prev.profile.id) ?? null
      })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load competency data')
      setData(null)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  useEffect(() => {
    const q = searchParams.get('q')
    if (q) setSearch(q)
  }, [searchParams])

  useEffect(() => {
    const memberId = Number(searchParams.get('member') || 0)
    if (!memberId || !data) return
    const match = data.members.find((m) => m.profile.id === memberId)
    if (match) setSelected(match)
  }, [data, searchParams])

  const visible = useMemo(() => {
    if (!data) return []
    const base = filterAndSortCompetency(data.members, { chip, search, sort })
    if (levelFilter === 'all') return base
    return base.filter((m) => m.currentLevel === levelFilter)
  }, [data, chip, search, sort, levelFilter])

  const levelCounts = useMemo(() => {
    if (!data) return { all: 0, beginner: 0, intermediate: 0, advanced: 0 }
    const base = data.members.filter((m) => matchesChip(m, chip))
    return {
      all: base.length,
      beginner: base.filter((m) => m.currentLevel === 'beginner').length,
      intermediate: base.filter((m) => m.currentLevel === 'intermediate').length,
      advanced: base.filter((m) => m.currentLevel === 'advanced').length,
    }
  }, [data, chip])

  function showMsg(msg: string) {
    showToast(msg)
  }

  async function handleSendNotesToMember(notes: string): Promise<boolean> {
    if (!selected) return false
    const trimmed = notes.trim()
    if (!trimmed) {
      showMsg('Write a note before sending to the member')
      return false
    }
    setSaving(true)
    try {
      await updateRankingRemarks(selected.profile.id, trimmed, { notifyMember: true })
      await load()
      showMsg(`Note sent to ${selected.profile.name}`)
      return true
    } catch (e) {
      showMsg(e instanceof Error ? e.message : 'Failed to send note')
      return false
    } finally {
      setSaving(false)
    }
  }

  async function handleUpdateLevel(level: CompetencyLevel | 'system') {
    if (!selected) return
    setSaving(true)
    try {
      const apiLevel = level === 'system' ? null : competencyLevelToApiLabel(level)
      await updateCompetencyLevel(selected.profile.id, apiLevel)
      await load()
      showMsg(
        level === 'system'
          ? `Using system recommendation for ${selected.profile.name}`
          : `Competency level updated for ${selected.profile.name}`,
      )
    } catch (e) {
      showMsg(e instanceof Error ? e.message : 'Failed to update competency level')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="min-w-0 max-w-full space-y-5 pb-8">
      <AdminPageHeader
        title="Competency Management"
        subtitle="See who ranks highest, track performance and skill level, override competency when needed, and decide who fits each event scale."
        backTo="/"
        actions={<PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />}
      />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      {data && (
        <div className="flex flex-wrap gap-2">
          {PRIMARY_CHIPS.map((id) => (
            <button
              key={id}
              type="button"
              onClick={() => {
                setChip(id)
                setLevelFilter('all')
              }}
              className={[
                'rounded-full px-4 py-1.5 text-xs font-bold transition',
                chip === id
                  ? 'bg-[var(--color-accent-blue)] text-white'
                  : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
              ].join(' ')}
            >
              {PRIMARY_CHIP_LABELS[id]} ({countByChip(data.members, id)})
            </button>
          ))}
        </div>
      )}

      <div className="flex flex-col gap-2 rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3 md:p-4">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-[minmax(0,1fr)_minmax(0,10rem)_minmax(0,10rem)]">
          <div className="relative min-w-0 sm:col-span-2 xl:col-span-1">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
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
            value={sort}
            onChange={(v) => setSort(v as CompetencySortOption)}
            aria-label="Sort members"
            options={SORT_OPTIONS.map((o) => ({ value: o.id, label: `Sort: ${o.label}` }))}
          />
        </div>
        {data && (
          <p className="flex flex-wrap gap-x-3 gap-y-1 text-xs text-[var(--color-text-muted)]">
            <span>{data.stats.totalMembers} members</span>
            <span>{data.stats.needsReview} need review</span>
            <span>{data.stats.advancedCount} advanced</span>
            <span>{data.stats.intermediateCount} intermediate</span>
            <span>{data.stats.beginnerCount} beginner</span>
            <span>Overrides sync to the server</span>
          </p>
        )}
      </div>

      {loading && !data ? (
        <div className="flex justify-center py-16">
          <Loader2 className="animate-spin text-[var(--color-text-muted)]" size={28} />
        </div>
      ) : visible.length === 0 ? (
        <AdminCard dashed padding="lg" className="text-center text-sm text-[var(--color-text-secondary)]">
          {chip === 'needsReview' && levelFilter === 'all' && !search.trim() ? (
            <>
              <Award size={28} className="mx-auto text-[var(--color-text-muted)]" />
              <p className="mt-3 font-semibold text-[var(--color-text-primary)]">Review queue is clear</p>
              <p className="mt-1">All members match their system recommendations with clean integrity records.</p>
            </>
          ) : (
            <>
              <p className="font-semibold text-[var(--color-text-primary)]">No members match your filters</p>
              <p className="mt-1">Try another tab, level filter, or clear your search.</p>
            </>
          )}
        </AdminCard>
      ) : (
        <>
          <div className="flex items-center justify-between gap-2">
            <h2 className="text-sm font-bold text-[var(--color-text-primary)]">Member rankings and competency</h2>
            <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
              {visible.length} shown
            </span>
          </div>
          <CompetencyMembersTable members={visible} onViewProfile={setSelected} />
        </>
      )}

      {selected && (
        <CompetencyProfileDrawer
          member={selected}
          saving={saving}
          onClose={() => setSelected(null)}
          onSendNotesToMember={handleSendNotesToMember}
          onUpdateLevel={handleUpdateLevel}
        />
      )}
    </div>
  )
}
