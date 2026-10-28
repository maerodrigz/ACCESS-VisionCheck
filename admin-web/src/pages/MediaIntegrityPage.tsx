import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { Info, Loader2, RefreshCw, Search } from 'lucide-react'
import { fetchAiDetectionForMedia, fetchAiDetectionList } from '../api/admin'
import type { AiDetectionRow } from '../api/media'
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
  isResolvedIntegrityReview,
  parseAiDetectionRow,
  sortDetectionRows,
} from '../lib/aiDetection'
import type { ReviewStatus } from '../api/media'

type QueueKind = 'photos' | 'videos'

const INBOX_CHIPS: { id: IntegrityInboxFilter; label: string }[] = [
  { id: 'needs_action', label: 'Needs Action' },
  { id: 'reupload_requested', label: 'Re-upload Requested' },
  { id: 'all', label: 'All Scans' },
  { id: 'pending_scan', label: 'Pending Scan' },
  { id: 'suspicious', label: 'Suspicious' },
  { id: 'ai_generated', label: 'AI Generated' },
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
  showFormat,
  onDetails,
}: {
  items: AiDetectionRow[]
  showFormat: boolean
  onDetails: (row: AiDetectionRow) => void
}) {
  return (
    <div className="grid gap-2 xl:grid-cols-2">
      {items.map((row) => (
        <AiDetectionRowCard key={row.id} row={row} showFormat={showFormat} onDetails={onDetails} />
      ))}
    </div>
  )
}

export function MediaIntegrityPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const [rows, setRows] = useState<AiDetectionRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [searchQuery, setSearchQuery] = useState('')
  const [inboxFilter, setInboxFilter] = useState<IntegrityInboxFilter>('needs_action')
  const [formatFilter, setFormatFilter] = useState<IntegrityFormatFilter>('all')
  const [queueKind, setQueueKind] = useState<QueueKind>('photos')
  const [includeProbeSmoke, setIncludeProbeSmoke] = useState(false)
  const [selected, setSelected] = useState<AiDetectionRow | null>(null)

  const memberRows = useMemo(
    () => (includeProbeSmoke ? rows : rows.filter((r) => !isProbeSmokeTestRow(r))),
    [rows, includeProbeSmoke],
  )

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const list = await fetchAiDetectionList('all')
      const parsed = list.map((m) => parseAiDetectionRow(m))
      setRows(parsed)
      setSelected((prev) => {
        if (!prev) return null
        return parsed.find((r) => r.id === prev.id) ?? null
      })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load AI detection results')
      setRows([])
    } finally {
      setLoading(false)
    }
  }, [])

  const handleReviewSaved = useCallback((aiRowId: number, nextStatus: ReviewStatus) => {
    setRows((prev) =>
      prev.map((r) =>
        r.id === aiRowId
          ? { ...r, review_status: nextStatus, reviewed_by_admin: isResolvedIntegrityReview(nextStatus) }
          : r,
      ),
    )
    setSelected(null)
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

  const filteredPhotos = useMemo(() => filtered.filter((r) => !isVideoDetectionRow(r)), [filtered])
  const filteredVideos = useMemo(() => filtered.filter((r) => isVideoDetectionRow(r)), [filtered])
  const showKindTabs = formatFilter === 'all' && filteredPhotos.length > 0 && filteredVideos.length > 0
  const visibleRows = showKindTabs ? (queueKind === 'photos' ? filteredPhotos : filteredVideos) : filtered
  const showFormatBadge = formatFilter === 'all' && !showKindTabs

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
    <div className="mx-auto max-w-[1400px] space-y-3 pb-8">
      <AdminPageHeader
        title="Media Integrity"
        subtitle="Review flagged member uploads. Open Media Gallery for event documentation files."
        backTo="/"
        actions={
          <button type="button" onClick={load} disabled={loading} className={pageToolbarBtnClass}>
            <RefreshCw size={16} className={loading ? 'animate-spin' : 'shrink-0 text-[var(--color-text-secondary)]'} />
            Refresh
          </button>
        }
      />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      <div
        className="flex flex-wrap gap-1 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-1"
        role="tablist"
        aria-label="Scan status"
      >
        {INBOX_CHIPS.map((c) => {
          const active = inboxFilter === c.id
          return (
            <button
              key={c.id}
              type="button"
              role="tab"
              aria-selected={active}
              onClick={() => setInboxFilter(c.id)}
              className={[
                'inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition',
                active
                  ? 'bg-[var(--color-accent-blue)] text-white'
                  : 'text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-primary)]',
              ].join(' ')}
            >
              {c.label}
              <span
                className={[
                  'rounded-full px-1.5 text-[10px] font-bold',
                  active
                    ? 'bg-white/20 text-white'
                    : 'bg-[var(--color-surface-muted)] text-[var(--color-text-secondary)]',
                ].join(' ')}
              >
                {inboxCount(c.id)}
              </span>
            </button>
          )
        })}
      </div>

      <div className="grid gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-2.5 lg:grid-cols-[minmax(0,1fr)_14rem]">
        <div className="relative min-w-0">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
          <input
            placeholder="Search media or member name…"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="admin-input w-full rounded-lg py-1.5 pl-9 pr-3 text-sm"
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

      <section className="space-y-2 pt-1">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <h2 className="text-sm font-bold text-[var(--color-text-primary)]">{queueTitle}</h2>
            <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
              {filtered.length} item{filtered.length === 1 ? '' : 's'}
            </span>
          </div>
          {showKindTabs ? (
            <div
              className="inline-flex rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-0.5"
              role="tablist"
              aria-label="Media type"
            >
              {([
                ['photos', 'Photos', filteredPhotos.length],
                ['videos', 'Videos', filteredVideos.length],
              ] as const).map(([id, label, count]) => {
                const active = queueKind === id
                return (
                  <button
                    key={id}
                    type="button"
                    role="tab"
                    aria-selected={active}
                    onClick={() => setQueueKind(id)}
                    className={[
                      'rounded-md px-3 py-1 text-xs font-bold transition',
                      active
                        ? 'bg-[var(--color-accent-blue)] text-white'
                        : 'text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-primary)]',
                    ].join(' ')}
                  >
                    {label} ({count})
                  </button>
                )
              })}
            </div>
          ) : null}
        </div>

        <p className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)]">
          <Info size={12} className="shrink-0" />
          Automated detection is an indicator, not proof. Flagged media needs Admin review before any decision.
        </p>

        {loading && rows.length === 0 ? (
          <div className="flex justify-center py-16 text-[var(--color-text-secondary)]">
            <Loader2 className="animate-spin" size={28} />
          </div>
        ) : filtered.length === 0 ? (
          <AdminCard dashed padding="lg" className="text-center text-sm text-[var(--color-text-secondary)]">
            {inboxFilter === 'needs_action' && !searchQuery.trim() && formatFilter === 'all' ? (
              <>
                <p className="font-semibold text-[var(--color-text-primary)]">Queue is clear</p>
                <p className="mt-1">No scans waiting for Admin review right now.</p>
              </>
            ) : (
              <>
                <p className="font-semibold text-[var(--color-text-primary)]">No results match your filters</p>
                <p className="mt-1">Try another status tab, format, or clear your search.</p>
              </>
            )}
          </AdminCard>
        ) : (
          <IntegrityResultsList items={visibleRows} showFormat={showFormatBadge} onDetails={setSelected} />
        )}
      </section>

      {selected && (
        <AiReviewModal
          row={selected}
          onClose={() => setSelected(null)}
          onSaved={(nextStatus) => handleReviewSaved(selected.id, nextStatus)}
          onOpenRelatedMedia={(mediaId) => {
            const found = rows.find((r) => r.media_id === mediaId)
            if (found) {
              setSelected(found)
              return
            }
            void fetchAiDetectionForMedia(mediaId)
              .then((raw) => {
                const row = parseAiDetectionRow(raw)
                if (row) {
                  setInboxFilter('all')
                  setSelected(row)
                }
              })
              .catch(() => {
                /* keep modal; chain panel already shows media id */
              })
          }}
        />
      )}
    </div>
  )
}
