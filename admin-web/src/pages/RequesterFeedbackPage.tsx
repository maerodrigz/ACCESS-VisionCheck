import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { Download, Loader2, MessageSquare, Search } from 'lucide-react'
import { fetchFeedback, fetchMedia, fetchServiceRequests, fetchTasks, fetchUsers, updateFeedbackAdminReview } from '../api/admin'
import { AdminCard } from '../components/AdminCard'
import { AdminSelect } from '../components/AdminSelect'
import { AdminConfirmDialog } from '../components/AdminConfirmDialog'
import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { pageToolbarBtnClass, PageToolbarRefreshButton } from '../components/PageToolbar'
import { useToast } from '../context/ToastContext'
import { FeaturedTestimonialCard } from '../components/requester-feedback/FeaturedTestimonialCard'
import { FeedbackDetailsDrawer } from '../components/requester-feedback/FeedbackDetailsDrawer'
import { FeedbackReviewsTable } from '../components/requester-feedback/FeedbackReviewsTable'
import {
  buildExportReport,
  buildFeedbackDashboard,
  FILTER_CHIPS,
  matchesChip,
  type FeedbackFilterChip,
  type RequesterFeedbackDashboardData,
  type RequesterFeedbackItem,
} from '../lib/requesterFeedback'
const RATING_FILTER_OPTIONS: { id: 'rating_all' | 'star5' | 'star4' | 'star3' | 'star2' | 'star1'; label: string }[] = [
  { id: 'rating_all', label: 'All ratings' },
  { id: 'star5', label: '5 stars' },
  { id: 'star4', label: '4 stars' },
  { id: 'star3', label: '3 stars' },
  { id: 'star2', label: '2 stars' },
  { id: 'star1', label: '1 star' },
]

const PRIMARY_CHIPS: FeedbackFilterChip[] = ['pending', 'needsAttention', 'all']

export function RequesterFeedbackPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const [data, setData] = useState<RequesterFeedbackDashboardData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [chip, setChip] = useState<FeedbackFilterChip>('pending')
  const [ratingFilter, setRatingFilter] = useState<'rating_all' | 'star5' | 'star4' | 'star3' | 'star2' | 'star1'>('rating_all')
  const [selected, setSelected] = useState<RequesterFeedbackItem | null>(null)
  const [focusResponse, setFocusResponse] = useState(false)
  const [archiveTarget, setArchiveTarget] = useState<RequesterFeedbackItem | null>(null)
  const { showToast } = useToast()

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [feedbackRows, requests, tasks, media, users] = await Promise.all([
        fetchFeedback(),
        fetchServiceRequests(),
        fetchTasks(),
        fetchMedia(),
        fetchUsers(),
      ])
      const dashboard = buildFeedbackDashboard({
        feedbackRows,
        requests,
        tasks,
        media,
        users: users as unknown as Record<string, unknown>[],
      })
      setData(dashboard)
      setSelected((prev) => {
        if (!prev) return null
        return dashboard.feedback.find((f) => f.id === prev.id) ?? null
      })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load feedback')
      setData(null)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  useEffect(() => {
    const feedbackId = Number(searchParams.get('feedback') || 0)
    if (!feedbackId || !data) return
    const item = data.feedback.find((f) => f.id === feedbackId)
    if (!item) return
    setSelected(item)
    setFocusResponse(false)
    setChip('all')
    const next = new URLSearchParams(searchParams)
    next.delete('feedback')
    setSearchParams(next, { replace: true })
  }, [data, searchParams, setSearchParams])

  const visible = useMemo(() => {
    if (!data) return []
    const q = search.trim().toLowerCase()
    return data.feedback.filter((item) => {
      if (!matchesChip(item, chip)) return false
      if (ratingFilter !== 'rating_all' && !matchesChip(item, ratingFilter)) return false
      if (!q) return true
      return (
        item.eventName.toLowerCase().includes(q) ||
        item.organization.toLowerCase().includes(q) ||
        item.requesterName.toLowerCase().includes(q) ||
        String(item.rating).includes(q) ||
        (item.eventDate != null &&
          `${item.eventDate.toLocaleDateString()}`.toLowerCase().includes(q))
      )
    })
  }, [data, chip, ratingFilter, search])

  const chipCounts = useMemo(() => {
    if (!data) return {} as Record<FeedbackFilterChip, number>
    const counts = {} as Record<FeedbackFilterChip, number>
    for (const c of FILTER_CHIPS) {
      counts[c.id] = data.feedback.filter((i) => matchesChip(i, c.id)).length
    }
    return counts
  }, [data])

  const ratingCounts = useMemo(() => {
    if (!data) return { rating_all: 0, star5: 0, star4: 0, star3: 0, star2: 0, star1: 0 }
    const base = data.feedback.filter((i) => matchesChip(i, chip))
    return {
      rating_all: base.length,
      star5: base.filter((i) => i.rating === 5).length,
      star4: base.filter((i) => i.rating === 4).length,
      star3: base.filter((i) => i.rating === 3).length,
      star2: base.filter((i) => i.rating === 2).length,
      star1: base.filter((i) => i.rating === 1).length,
    }
  }, [data, chip])

  function showMsg(msg: string, tone: 'success' | 'error' | 'info' = 'success') {
    showToast(msg, tone)
  }

  function openDetails(item: RequesterFeedbackItem, respond = false) {
    setSelected(item)
    setFocusResponse(respond)
  }

  function closeDrawer() {
    setSelected(null)
    setFocusResponse(false)
  }

  async function markReviewed(item: RequesterFeedbackItem) {
    try {
      await updateFeedbackAdminReview(item.id, { review_status: 'reviewed' })
      closeDrawer()
      await load()
      showMsg('Feedback marked as reviewed')
    } catch (e) {
      showMsg(e instanceof Error ? e.message : 'Could not update feedback', 'error')
    }
  }

  async function confirmArchive() {
    if (!archiveTarget) return
    try {
      await updateFeedbackAdminReview(archiveTarget.id, { review_status: 'archived' })
      setArchiveTarget(null)
      closeDrawer()
      await load()
      showMsg('Feedback archived')
    } catch (e) {
      showMsg(e instanceof Error ? e.message : 'Could not archive feedback', 'error')
    }
  }

  async function sendResponse(response: string) {
    if (!selected) return
    if (!response.trim()) {
      showMsg('Write a response before sending')
      return
    }
    try {
      await updateFeedbackAdminReview(selected.id, {
        admin_response: response.trim(),
        review_status: 'reviewed',
      })
      closeDrawer()
      await load()
      showMsg('Response saved')
    } catch (e) {
      showMsg(e instanceof Error ? e.message : 'Could not save response', 'error')
    }
  }

  function exportReport() {
    if (!data) return
    void navigator.clipboard.writeText(buildExportReport(data))
    showMsg('Feedback report copied to clipboard')
  }

  function primaryChipLabel(id: FeedbackFilterChip): string {
    const base = FILTER_CHIPS.find((c) => c.id === id)?.label ?? id
    return `${base} (${chipCounts[id] ?? 0})`
  }

  return (
    <div className="min-w-0 max-w-full space-y-5 pb-8">
      <AdminPageHeader
        title="Requester Feedback"
        subtitle="Ratings and comments from organizations after completed events. Respond to issues and track satisfaction."
        backTo="/"
        actions={
          <>
            <button type="button" onClick={exportReport} disabled={!data} className={pageToolbarBtnClass}>
              <Download size={16} className="shrink-0 text-[var(--color-text-secondary)]" strokeWidth={2} />
              Export report
            </button>
            <PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />
          </>
        }
      />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      {loading && !data ? (
        <div className="flex justify-center py-16">
          <Loader2 className="animate-spin text-[var(--color-text-muted)]" size={28} />
        </div>
      ) : data ? (
        <>
          <div className="flex flex-wrap gap-2">
            {PRIMARY_CHIPS.map((id) => (
              <button
                key={id}
                type="button"
                onClick={() => {
                  setChip(id)
                  setRatingFilter('rating_all')
                }}
                className={[
                  'rounded-full px-4 py-1.5 text-xs font-bold transition',
                  chip === id && ratingFilter === 'rating_all'
                    ? 'bg-[var(--color-accent-blue)] text-white'
                    : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
                ].join(' ')}
              >
                {primaryChipLabel(id)}
              </button>
            ))}
          </div>

          <div className="flex flex-col gap-2 rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3 md:p-4">
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-[minmax(0,1fr)_minmax(0,11rem)]">
              <div className="relative min-w-0">
                <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
                <input
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Search event, organization, requester, rating, date…"
                  className="admin-input w-full rounded-xl py-2 pl-9 pr-3 text-sm"
                />
              </div>
              <AdminSelect
                className="min-w-0 w-full"
                value={ratingFilter}
                onChange={(v) =>
                  setRatingFilter(v as 'rating_all' | 'star5' | 'star4' | 'star3' | 'star2' | 'star1')
                }
                aria-label="Filter by rating"
                options={RATING_FILTER_OPTIONS.map((o) => ({
                  value: o.id,
                  label: `${o.label} (${o.id === 'rating_all' ? ratingCounts.rating_all : ratingCounts[o.id]})`,
                }))}
              />
            </div>
            <p className="flex flex-wrap gap-x-3 gap-y-1 text-xs text-[var(--color-text-muted)]">
              <span>Avg {data.stats.averageRating > 0 ? data.stats.averageRating.toFixed(1) : 'N/A'}/5</span>
              <span>{data.stats.totalReceived} received</span>
              <span>{data.stats.positiveReviews} positive (4-5)</span>
              <span>{data.stats.needsAttention} need attention</span>
              <span>{data.stats.pendingReview} pending review</span>
            </p>
          </div>

          {data.featured && chip === 'all' && ratingFilter === 'rating_all' && !search.trim() && (
            <FeaturedTestimonialCard testimonial={data.featured} />
          )}

          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <h2 className="text-sm font-bold text-[var(--color-text-primary)]">Submitted reviews</h2>
              <p className="mt-0.5 text-xs text-[var(--color-text-secondary)]">
                Feedback appears after requestors complete an event review.
              </p>
            </div>
            <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
              {visible.length} shown
            </span>
          </div>

          {visible.length === 0 ? (
            <AdminCard dashed padding="lg" className="text-center text-sm text-[var(--color-text-secondary)]">
              {chip === 'pending' && ratingFilter === 'rating_all' && !search.trim() ? (
                <>
                  <MessageSquare size={28} className="mx-auto text-[var(--color-text-muted)]" />
                  <p className="mt-3 font-semibold text-[var(--color-text-primary)]">Inbox is clear</p>
                  <p className="mt-1">No feedback waiting for admin review.</p>
                </>
              ) : (
                <>
                  <p className="font-semibold text-[var(--color-text-primary)]">No reviews match your filters</p>
                  <p className="mt-1">Try another tab, rating filter, or clear your search.</p>
                </>
              )}
            </AdminCard>
          ) : (
            <FeedbackReviewsTable
              items={visible}
              onViewDetails={(i) => openDetails(i)}
              onRespond={(i) => openDetails(i, true)}
              onArchive={(i) => setArchiveTarget(i)}
            />
          )}
        </>
      ) : null}

      {selected && (
        <FeedbackDetailsDrawer
          item={selected}
          focusResponse={focusResponse}
          onClose={closeDrawer}
          onSendResponse={sendResponse}
          onMarkReviewed={() => markReviewed(selected)}
          onArchive={() => setArchiveTarget(selected)}
        />
      )}

      <AdminConfirmDialog
        open={archiveTarget != null}
        title="Archive feedback?"
        message={
          archiveTarget ? `"${archiveTarget.eventName}" will be hidden from the active review list.` : ''
        }
        confirmLabel="Archive"
        tone="danger"
        onConfirm={() => void confirmArchive()}
        onCancel={() => setArchiveTarget(null)}
      />
    </div>
  )
}
