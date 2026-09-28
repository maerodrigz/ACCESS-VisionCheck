import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { Image, Loader2, RefreshCw, Search, Video } from 'lucide-react'
import { fetchAiDetectionList, fetchAiDetectionSummary } from '../api/admin'
import type { AiDetectionRow, AiDetectionSummary } from '../api/media'
import { AdminCard } from '../components/AdminCard'
import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { pageToolbarBtnClass } from '../components/PageToolbar'
import { AdminSelect } from '../components/AdminSelect'
import { AiDetectionRowCard } from '../components/ai-detection/AiDetectionRowCard'
import { AiReviewModal } from '../components/ai-detection/AiReviewModal'
import {
  type IntegrityFormatFilter,
  type IntegrityInboxFilter,
  isProbeSmokeTestRow,
  isVideoDetectionRow,
  matchesIntegrityInbox,
  parseAiDetectionRow,
  sortDetectionRows,
  summaryFromRows,
} from '../lib/aiDetection'
const INBOX_CHIPS: { id: IntegrityInboxFilter; label: string }[] = [
  { id: 'needs_action', label: 'Needs action' },
  { id: 'all', label: 'All scans' },
  { id: 'pending_scan', label: 'Pending scan' },
  { id: 'suspicious', label: 'Suspicious' },
  { id: 'ai_generated', label: 'AI generated' },
  { id: 'human', label: 'Human' },
  { id: 'resolved', label: 'Resolved' },
]

const FORMAT_OPTIONS: { id: IntegrityFormatFilter; label: string }[] = [
  { id: 'all', label: 'All formats' },
  { id: 'photos', label: 'Photos' },
  { id: 'videos', label: 'Videos' },
]

function IntegrityResultsList({
  items,
  onDetails,
}: {
  items: AiDetectionRow[]
  onDetails: (row: AiDetectionRow) => void
}) {
  return (
    <div className="space-y-3">
      {items.map((row) => (
        <AiDetectionRowCard key={row.id} row={row} onDetails={onDetails} />
      ))}
    </div>
  )
}

export function MediaIntegrityPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const [rows, setRows] = useState<AiDetectionRow[]>([])
  const [summary, setSummary] = useState<AiDetectionSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [searchQuery, setSearchQuery] = useState('')
  const [inboxFilter, setInboxFilter] = useState<IntegrityInboxFilter>('needs_action')
  const [formatFilter, setFormatFilter] = useState<IntegrityFormatFilter>('all')
  const [includeProbeSmoke, setIncludeProbeSmoke] = useState(false)
  const [selected, setSelected] = useState<AiDetectionRow | null>(null)

  const memberRows = useMemo(
    () => (includeProbeSmoke ? rows : rows.filter((r) => !isProbeSmokeTestRow(r))),
    [rows, includeProbeSmoke],
  )
  const probeSmokeHiddenCount = useMemo(
    () => rows.filter((r) => isProbeSmokeTestRow(r)).length,
    [rows],
  )

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [list, sum] = await Promise.all([
        fetchAiDetectionList(),
        fetchAiDetectionSummary().catch(() => null),
      ])
      const parsed = list.map((m) => parseAiDetectionRow(m))
      setRows(parsed)
      setSummary(sum ?? summaryFromRows(parsed))
      setSelected((prev) => {
        if (!prev) return null
        return parsed.find((r) => r.id === prev.id) ?? null
      })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load AI detection results')
      setRows([])
      setSummary({
        total_scanned: 0,
        human_count: 0,
        ai_generated_count: 0,
        suspicious_count: 0,
        pending_review_count: 0,
      })
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
    const id = window.setInterval(load, 45000)
    return () => window.clearInterval(id)
  }, [load])

  useEffect(() => {
    const mediaId = Number(searchParams.get('media') || 0)
    if (!mediaId || rows.length === 0) return
    const row = rows.find((r) => r.media_id === mediaId || r.id === mediaId)
    if (!row) return
    setInboxFilter('all')
    if (isProbeSmokeTestRow(row)) setIncludeProbeSmoke(true)
    setSelected(row)
    const next = new URLSearchParams(searchParams)
    next.delete('media')
    setSearchParams(next, { replace: true })
  }, [rows, searchParams, setSearchParams])

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase()
    return sortDetectionRows(
      memberRows.filter((r) => {
        if (!matchesIntegrityInbox(r, inboxFilter)) return false
        if (formatFilter === 'photos' && isVideoDetectionRow(r)) return false
        if (formatFilter === 'videos' && !isVideoDetectionRow(r)) return false
        if (!q) return true
        return (
          r.media_name.toLowerCase().includes(q) ||
          r.member_name.toLowerCase().includes(q) ||
          r.detection_remarks?.toLowerCase().includes(q)
        )
      }),
    )
  }, [memberRows, searchQuery, inboxFilter, formatFilter])

  const inboxCounts = useMemo(() => {
    const counts = {} as Record<IntegrityInboxFilter, number>
    for (const chip of INBOX_CHIPS) {
      counts[chip.id] = memberRows.filter((r) => matchesIntegrityInbox(r, chip.id)).length
    }
    return counts
  }, [memberRows])

  const formatCounts = useMemo(() => {
    const inboxRows = memberRows.filter((r) => matchesIntegrityInbox(r, inboxFilter))
    return {
      all: inboxRows.length,
      photos: inboxRows.filter((r) => !isVideoDetectionRow(r)).length,
      videos: inboxRows.filter((r) => isVideoDetectionRow(r)).length,
    }
  }, [memberRows, inboxFilter])

  const splitByFormat = formatFilter === 'all'
  const filteredPhotos = useMemo(() => filtered.filter((r) => !isVideoDetectionRow(r)), [filtered])
  const filteredVideos = useMemo(() => filtered.filter((r) => isVideoDetectionRow(r)), [filtered])
  const hiddenVideoCount = useMemo(
    () =>
      memberRows.filter((r) => isVideoDetectionRow(r) && !matchesIntegrityInbox(r, inboxFilter)).length,
    [memberRows, inboxFilter],
  )

  const queueTitle =
    inboxFilter === 'needs_action'
      ? 'Review queue'
      : inboxFilter === 'resolved'
        ? 'Resolved scans'
        : 'Scan results'

  function inboxCount(id: IntegrityInboxFilter): number {
    return inboxCounts[id] ?? 0
  }

  return (
    <div className="space-y-5 pb-8">
      <AdminPageHeader
        title="Media Integrity"
        subtitle="Trust check for flagged member uploads. Pair with Member Uploads to browse files."
        backTo="/"
        actions={
          <button type="button" onClick={load} disabled={loading} className={pageToolbarBtnClass}>
            <RefreshCw size={16} className={loading ? 'animate-spin' : 'shrink-0 text-[var(--color-text-secondary)]'} />
            Refresh
          </button>
        }
      />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      <div className="flex flex-wrap gap-2">
        {INBOX_CHIPS.map((c) => (
          <button
            key={c.id}
            type="button"
            onClick={() => setInboxFilter(c.id)}
            className={[
              'rounded-full px-4 py-1.5 text-xs font-bold transition',
              inboxFilter === c.id
                ? 'bg-[var(--color-accent-blue)] text-white'
                : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
            ].join(' ')}
          >
            {c.label} ({inboxCount(c.id)})
          </button>
        ))}
      </div>

      <div className="flex flex-col gap-2 rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3 md:p-4">
        <div className="grid gap-3 lg:grid-cols-[1fr_auto]">
          <div className="relative min-w-0">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
            <input
              placeholder="Search media or member name…"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="admin-input w-full rounded-xl py-2 pl-9 pr-3 text-sm"
            />
          </div>
          <AdminSelect
            value={formatFilter}
            onChange={(v) => setFormatFilter(v as IntegrityFormatFilter)}
            aria-label="Filter by format"
            options={FORMAT_OPTIONS.map((o) => ({
              value: o.id,
              label: `${o.label} (${formatCounts[o.id]})`,
            }))}
          />
        </div>
        {summary && (
          <p className="text-xs text-[var(--color-text-muted)]">
            {summary.total_scanned} scanned · {summary.human_count} human · {summary.suspicious_count} suspicious ·{' '}
            {summary.ai_generated_count} AI · {summary.pending_review_count} need review
          </p>
        )}
        <label className="flex cursor-pointer items-start gap-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2.5">
          <input
            type="checkbox"
            checked={includeProbeSmoke}
            onChange={(e) => setIncludeProbeSmoke(e.target.checked)}
            className="mt-0.5 h-4 w-4 rounded border-[var(--color-border)] accent-[var(--color-accent-blue)]"
          />
          <span className="text-xs leading-relaxed text-[var(--color-text-secondary)]">
            <span className="font-bold text-[var(--color-text-primary)]">Include PROBE smoke tests</span>
            {probeSmokeHiddenCount > 0 ? (
              <>
                {' '}
                ({probeSmokeHiddenCount} hidden by default: names starting with &quot;PROBE smoke&quot; or legacy
                Step8A/Step8B)
              </>
            ) : (
              <> (dev E2E uploads from the PROBE smoke scripts)</>
            )}
          </span>
        </label>
      </div>

      <div className="flex items-center justify-between gap-2">
        <h2 className="text-sm font-bold text-[var(--color-text-primary)]">{queueTitle}</h2>
        <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
          {filtered.length} item{filtered.length === 1 ? '' : 's'}
        </span>
      </div>

      {loading && rows.length === 0 ? (
        <div className="flex justify-center py-16 text-[var(--color-text-secondary)]">
          <Loader2 className="animate-spin" size={28} />
        </div>
      ) : filtered.length === 0 ? (
        <AdminCard dashed padding="lg" className="text-center text-sm text-[var(--color-text-secondary)]">
          {inboxFilter === 'needs_action' && !searchQuery.trim() && formatFilter === 'all' ? (
            <>
              <p className="font-semibold text-[var(--color-text-primary)]">Queue is clear</p>
              <p className="mt-1">No scans waiting for admin review right now.</p>
            </>
          ) : (
            <>
              <p className="font-semibold text-[var(--color-text-primary)]">No results match your filters</p>
              <p className="mt-1">Try another inbox tab, format, or clear your search.</p>
            </>
          )}
        </AdminCard>
      ) : splitByFormat ? (
        <div className="space-y-8">
          {filteredPhotos.length > 0 && (
            <section>
              <div className="mb-3 flex items-center gap-2">
                <Image size={16} className="text-[var(--color-accent-cyan)]" />
                <h3 className="text-sm font-bold text-[var(--color-text-primary)]">Photos</h3>
                <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
                  {filteredPhotos.length}
                </span>
              </div>
              <IntegrityResultsList items={filteredPhotos} onDetails={setSelected} />
            </section>
          )}
          {(filteredVideos.length > 0 || hiddenVideoCount > 0) && (
            <section>
              <div className="mb-3 flex items-center gap-2">
                <Video size={16} className="text-[var(--color-accent-blue)]" />
                <h3 className="text-sm font-bold text-[var(--color-text-primary)]">Videos</h3>
                <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
                  {filteredVideos.length}
                </span>
              </div>
              {filteredVideos.length > 0 ? (
                <IntegrityResultsList items={filteredVideos} onDetails={setSelected} />
              ) : (
                <AdminCard dashed padding="md" className="text-sm text-[var(--color-text-secondary)]">
                  <p className="font-semibold text-[var(--color-text-primary)]">No videos in this inbox tab</p>
                  <p className="mt-1">
                    {hiddenVideoCount} video scan{hiddenVideoCount === 1 ? '' : 's'} exist but are already reviewed or
                    marked low AI risk. Switch to <span className="font-semibold">All scans</span> or{' '}
                    <span className="font-semibold">Resolved</span> to see them.
                  </p>
                  <button
                    type="button"
                    onClick={() => setInboxFilter('all')}
                    className="mt-3 rounded-lg bg-[var(--color-accent-blue)] px-3 py-1.5 text-xs font-bold text-white"
                  >
                    Show all scans
                  </button>
                </AdminCard>
              )}
            </section>
          )}
        </div>
      ) : (
        <IntegrityResultsList items={filtered} onDetails={setSelected} />
      )}

      {selected && (
        <AiReviewModal row={selected} onClose={() => setSelected(null)} onSaved={load} />
      )}
    </div>
  )
}
