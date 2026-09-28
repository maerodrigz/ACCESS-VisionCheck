import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { ClipboardCheck, Search } from 'lucide-react'
import {
  archiveEvaluation,
  fetchEvaluations,
  fetchEvaluationSummary,
  updateEvaluationRemarks,
} from '../api/admin'
import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { EvaluationDetailDrawer } from '../components/evaluation-review/EvaluationDetailDrawer'
import { EvaluationsTable } from '../components/evaluation-review/EvaluationsTable'
import { PageLoader } from '../components/PageLoader'
import { PageToolbarRefreshButton } from '../components/PageToolbar'
import { StatCard } from '../components/StatCard'
import { useToast } from '../context/ToastContext'
import {
  matchesEvaluationFilter,
  parseEvaluation,
  parseEvaluationSummary,
  type EvaluationReviewItem,
  type EvaluationSourceFilter,
  type EvaluationSummary,
} from '../lib/evaluationReview'

const FILTER_CHIPS: { id: EvaluationSourceFilter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'practice', label: 'Practice' },
  { id: 'event', label: 'Event coverage' },
  { id: 'flagged', label: 'AI flagged' },
]

export function EvaluationReviewPage() {
  const { showToast } = useToast()
  const [searchParams, setSearchParams] = useSearchParams()
  const [items, setItems] = useState<EvaluationReviewItem[]>([])
  const [summary, setSummary] = useState<EvaluationSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<EvaluationSourceFilter>('all')
  const [selected, setSelected] = useState<EvaluationReviewItem | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [rows, sum] = await Promise.all([
        fetchEvaluations(),
        fetchEvaluationSummary().catch(() => null),
      ])
      const parsed = rows.map(parseEvaluation)
      setItems(parsed)
      setSummary(sum ? parseEvaluationSummary(sum) : null)
      setSelected((prev) => {
        if (!prev) return null
        return parsed.find((e) => e.id === prev.id) ?? null
      })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load evaluations')
      setItems([])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  useEffect(() => {
    if (items.length === 0) return
    const evaluationId = Number(searchParams.get('evaluation') || 0)
    const mediaId = Number(searchParams.get('media') || 0)
    const match =
      (evaluationId ? items.find((e) => e.id === evaluationId) : null) ??
      (mediaId ? items.find((e) => e.mediaId === mediaId) : null)
    if (!match) return
    setSelected(match)
    const next = new URLSearchParams(searchParams)
    next.delete('evaluation')
    next.delete('media')
    setSearchParams(next, { replace: true })
  }, [items, searchParams, setSearchParams])

  const visible = useMemo(() => {
    const q = search.trim().toLowerCase()
    return items.filter((item) => {
      if (!matchesEvaluationFilter(item, filter)) return false
      if (!q) return true
      return (
        item.memberName.toLowerCase().includes(q) ||
        item.fileName.toLowerCase().includes(q) ||
        item.sourceLabel.toLowerCase().includes(q) ||
        (item.eventTitle ?? '').toLowerCase().includes(q)
      )
    })
  }, [items, filter, search])

  const chipCounts = useMemo(() => {
    const counts = {} as Record<EvaluationSourceFilter, number>
    for (const chip of FILTER_CHIPS) {
      counts[chip.id] = items.filter((item) => matchesEvaluationFilter(item, chip.id)).length
    }
    return counts
  }, [items])

  async function handleSaveRemarks(remarks: string) {
    if (!selected) return
    setBusy(true)
    try {
      await updateEvaluationRemarks(selected.id, remarks || null)
      showToast('Admin notes saved')
      await load()
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'Save failed', 'error')
    } finally {
      setBusy(false)
    }
  }

  async function handleArchive() {
    if (!selected) return
    setBusy(true)
    try {
      await archiveEvaluation(selected.id)
      showToast('Media archived')
      setSelected(null)
      await load()
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'Archive failed', 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-6">
      <AdminPageHeader
        title="Evaluation Review"
        subtitle="Score and notes for member uploads. Use Media Integrity when AI flags an upload."
        backTo="/"
        actions={<PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />}
      />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      {summary ? (
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <StatCard
            icon={ClipboardCheck}
            label="Total evaluated"
            value={summary.totalEvaluated}
            color="var(--color-accent-blue)"
          />
          <StatCard
            icon={ClipboardCheck}
            label="Average score"
            value={`${Math.round(summary.averageOverallScore)}%`}
            color="var(--color-accent-cyan)"
          />
          <StatCard
            icon={ClipboardCheck}
            label="Human verified"
            value={summary.humanMediaCount}
            color="#22c55e"
          />
          <StatCard
            icon={ClipboardCheck}
            label="AI flagged"
            value={summary.aiSuspiciousCount}
            color="#f59e0b"
            badge={summary.aiSuspiciousCount > 0}
          />
        </div>
      ) : null}

      <div className="flex flex-wrap gap-2">
        {FILTER_CHIPS.map((chip) => (
          <button
            key={chip.id}
            type="button"
            onClick={() => setFilter(chip.id)}
            className={[
              'rounded-full px-4 py-1.5 text-xs font-bold transition',
              filter === chip.id
                ? 'bg-[var(--color-accent-blue)] text-white'
                : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
            ].join(' ')}
          >
            {chip.label} ({chipCounts[chip.id] ?? 0})
          </button>
        ))}
      </div>

      <div className="rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3 md:p-4">
        <div className="relative min-w-0">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search member, file, event…"
            className="admin-input w-full rounded-xl py-2 pl-9 pr-3 text-sm"
          />
        </div>
        <p className="mt-2 text-xs text-[var(--color-text-secondary)]">
          {visible.length} evaluation{visible.length === 1 ? '' : 's'} shown
        </p>
      </div>

      {loading && items.length === 0 ? (
        <PageLoader label="Loading evaluations…" />
      ) : (
        <EvaluationsTable items={visible} onReview={setSelected} />
      )}

      <EvaluationDetailDrawer
        item={selected}
        saving={busy}
        onClose={() => setSelected(null)}
        onSaveRemarks={handleSaveRemarks}
        onArchive={handleArchive}
      />
    </div>
  )
}
