import { useEffect, useRef, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { Archive, ArchiveRestore, Calendar, MoreVertical } from 'lucide-react'
import { eventCalendarUrl } from '../../lib/adminCrossLinks'
import { AdminDrawer } from '../AdminDrawer'
import { DrawerBackButton } from '../AdminBackButton'
import { AdminConfirmDialog } from '../AdminConfirmDialog'
import {
  archiveServiceRequest,
  fetchRequestAssignments,
  fetchServiceRequest,
  setRequestStatus,
  unarchiveServiceRequest,
} from '../../api/admin'
import { useToast } from '../../context/ToastContext'
import type { DocumentationRequestItem } from '../../lib/documentationRequests'
import { formatRequestTimeRange, requestRefLabel } from '../../lib/documentationRequests'
import { AssignDocumentationTeamPanel } from './AssignDocumentationTeamPanel'
import { RequestMemberRatingsSection } from './RequestMemberRatingsSection'
import { PriorityBadge, StatusBadge } from './RequestBadges'

const CONFIRMED_ASSIGNMENT_STATUSES = new Set(['accepted', 'in_progress', 'assigned', 'completed'])

function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate())
}

function isEventDateReached(eventDate?: Date): boolean {
  if (!eventDate) return false
  return startOfDay(eventDate).getTime() <= startOfDay(new Date()).getTime()
}

function hasConfirmedCoverage(assignments: { status: string }[]): boolean {
  return assignments.some((a) => CONFIRMED_ASSIGNMENT_STATUSES.has(a.status.toLowerCase()))
}

function InfoField({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="min-w-0">
      <dt className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-secondary)]">
        {label}
      </dt>
      <dd className="mt-0.5 text-sm font-semibold leading-snug text-[var(--color-text-primary)]">{children}</dd>
    </div>
  )
}

interface Props {
  item: DocumentationRequestItem
  onClose: () => void
  onUpdated: () => void | Promise<void>
}

export function RequestReviewPanel({ item: initialItem, onClose, onUpdated }: Props) {
  const { showToast } = useToast()
  const [item, setItem] = useState(initialItem)
  const [submitting, setSubmitting] = useState(false)
  const [rejectReason, setRejectReason] = useState('')
  const [showReject, setShowReject] = useState(false)
  const [showApproveConfirm, setShowApproveConfirm] = useState(false)
  const [showCompleteConfirm, setShowCompleteConfirm] = useState(false)
  const [showResubmitConfirm, setShowResubmitConfirm] = useState(false)
  const [showArchiveConfirm, setShowArchiveConfirm] = useState(false)
  const [showRestoreConfirm, setShowRestoreConfirm] = useState(false)
  const [actionsOpen, setActionsOpen] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const actionsRef = useRef<HTMLDivElement>(null)
  const [assignments, setAssignments] = useState<{ status: string }[]>([])
  const [timeLabel, setTimeLabel] = useState(() =>
    formatRequestTimeRange(initialItem.startTime, initialItem.endTime),
  )

  useEffect(() => {
    setItem(initialItem)
    setTimeLabel(formatRequestTimeRange(initialItem.startTime, initialItem.endTime))
  }, [initialItem])

  useEffect(() => {
    if (!actionsOpen) return
    function onPointerDown(e: MouseEvent) {
      if (!actionsRef.current?.contains(e.target as Node)) setActionsOpen(false)
    }
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') setActionsOpen(false)
    }
    document.addEventListener('mousedown', onPointerDown)
    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('mousedown', onPointerDown)
      document.removeEventListener('keydown', onKeyDown)
    }
  }, [actionsOpen])

  useEffect(() => {
    let cancelled = false
    void fetchServiceRequest(initialItem.id)
      .then((row) => {
        if (cancelled) return
        const start = row.start_time != null ? String(row.start_time) : initialItem.startTime
        const end = row.end_time != null ? String(row.end_time) : initialItem.endTime
        setTimeLabel(formatRequestTimeRange(start, end))
        if (row.description != null || row.details != null) {
          const details = String(row.description ?? row.details ?? '')
          setItem((prev) => (details && !prev.details ? { ...prev, details } : prev))
        }
      })
      .catch(() => {
        /* keep times from the list payload */
      })
    return () => {
      cancelled = true
    }
  }, [initialItem.id, initialItem.startTime, initialItem.endTime])

  useEffect(() => {
    const approved =
      initialItem.displayStatus === 'approved' ||
      initialItem.displayStatus === 'completed' ||
      initialItem.displayStatus === 'archived'
    if (!approved) {
      setAssignments([])
      return
    }
    let cancelled = false
    void fetchRequestAssignments(initialItem.id)
      .then((rows) => {
        if (cancelled) return
        setAssignments(
          rows.map((r) => ({
            status: String(r.status ?? ''),
          })),
        )
      })
      .catch(() => {
        if (!cancelled) setAssignments([])
      })
    return () => {
      cancelled = true
    }
  }, [initialItem.id, initialItem.displayStatus])

  async function approve() {
    setSubmitting(true)
    setError(null)
    try {
      await setRequestStatus(item.id, 'Approved')
      setItem((prev) => ({
        ...prev,
        rawStatus: 'Approved',
        displayStatus: 'approved',
      }))
      setShowApproveConfirm(false)
      await onUpdated()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not approve request')
    } finally {
      setSubmitting(false)
    }
  }

  async function reject() {
    if (rejectReason.trim().length < 8) {
      setError('Rejection reason must be at least 8 characters.')
      return
    }
    setSubmitting(true)
    setError(null)
    try {
      await setRequestStatus(item.id, 'Rejected', rejectReason.trim())
      await onUpdated()
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not reject request')
    } finally {
      setSubmitting(false)
    }
  }

  async function markCompleted() {
    setSubmitting(true)
    setError(null)
    try {
      await setRequestStatus(item.id, 'Completed')
      setItem((prev) => ({
        ...prev,
        rawStatus: 'Completed',
        displayStatus: 'completed',
      }))
      setShowCompleteConfirm(false)
      await onUpdated()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not mark request completed')
    } finally {
      setSubmitting(false)
    }
  }

  async function archiveCompletedRequest() {
    setSubmitting(true)
    setError(null)
    try {
      await archiveServiceRequest(item.id)
      setShowArchiveConfirm(false)
      setActionsOpen(false)
      showToast('Request archived', 'success')
      await onUpdated()
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not archive request')
    } finally {
      setSubmitting(false)
    }
  }

  async function restoreArchivedRequest() {
    setSubmitting(true)
    setError(null)
    try {
      await unarchiveServiceRequest(item.id)
      setShowRestoreConfirm(false)
      setActionsOpen(false)
      showToast('Request restored to Completed', 'success')
      await onUpdated()
      setItem((prev) => ({ ...prev, displayStatus: 'completed', archivedAt: undefined }))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not restore request')
    } finally {
      setSubmitting(false)
    }
  }

  async function resubmit() {
    setSubmitting(true)
    setError(null)
    try {
      await setRequestStatus(item.id, 'Pending')
      await onUpdated()
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not resubmit')
    } finally {
      setSubmitting(false)
      setShowResubmitConfirm(false)
    }
  }

  const canApprove = item.displayStatus === 'pending'
  const canReject = item.displayStatus === 'pending'
  const eventDateReached = isEventDateReached(item.eventDate)
  const coverageConfirmed = hasConfirmedCoverage(assignments)
  const canMarkCompleted =
    item.displayStatus === 'approved' &&
    item.rawStatus.toLowerCase() !== 'completed' &&
    coverageConfirmed
  const showTeamPanel =
    item.displayStatus === 'approved' ||
    item.displayStatus === 'completed' ||
    item.displayStatus === 'archived'
  const showCompletionHint =
    item.displayStatus === 'approved' && item.rawStatus.toLowerCase() !== 'completed'
  const showMemberRatings =
    item.displayStatus === 'completed' ||
    item.displayStatus === 'archived' ||
    (item.assignedMembers.length > 0 && eventDateReached)
  const isDetailsTitle =
    item.displayStatus === 'approved' ||
    item.displayStatus === 'completed' ||
    item.displayStatus === 'archived'
  const headerTitle = isDetailsTitle ? 'Request Details' : 'Review request'
  const canArchiveRequest = item.displayStatus === 'completed'
  const canRestoreRequest = item.displayStatus === 'archived'
  const showRequestActions = canArchiveRequest || canRestoreRequest
  const hasFooterActions =
    canApprove || canReject || showReject || canMarkCompleted || item.displayStatus === 'rejected'

  return (
    <>
      <AdminDrawer
        open
        onClose={onClose}
        title={headerTitle}
        maxWidth="3xl"
        bodyClassName="space-y-3 px-5 py-4"
        header={
          <div className="flex shrink-0 items-start gap-2 border-b border-[var(--color-border)] px-5 py-3">
            <DrawerBackButton onClick={onClose} label="Back" />
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <h2 className="text-base font-extrabold leading-tight text-[var(--color-text-primary)]">
                  {headerTitle}
                </h2>
                <StatusBadge status={item.displayStatus} />
                <PriorityBadge priority={item.priority} />
              </div>
              <p className="mt-1 truncate text-sm font-semibold text-[var(--color-text-primary)]">
                {item.eventTitle}
              </p>
              <p className="text-[11px] font-semibold text-[var(--color-text-secondary)]">
                {requestRefLabel(item.id)}
              </p>
            </div>
            {showRequestActions ? (
              <div ref={actionsRef} className="relative shrink-0">
                <button
                  type="button"
                  aria-label="Request actions"
                  aria-expanded={actionsOpen}
                  aria-haspopup="menu"
                  disabled={submitting}
                  onClick={() => setActionsOpen((open) => !open)}
                  className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-[var(--color-border)] text-[var(--color-text-secondary)] transition hover:bg-[var(--color-surface-hover)] disabled:opacity-60"
                >
                  <MoreVertical size={18} aria-hidden />
                </button>
                {actionsOpen ? (
                  <div
                    role="menu"
                    className="absolute right-0 top-full z-20 mt-1 min-w-[11rem] overflow-hidden rounded-xl border border-[var(--color-border)] bg-white py-1 shadow-lg"
                  >
                    {canArchiveRequest ? (
                      <button
                        type="button"
                        role="menuitem"
                        className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm font-semibold text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]"
                        onClick={() => {
                          setActionsOpen(false)
                          setShowArchiveConfirm(true)
                        }}
                      >
                        <Archive size={16} aria-hidden />
                        Archive request
                      </button>
                    ) : null}
                    {canRestoreRequest ? (
                      <button
                        type="button"
                        role="menuitem"
                        className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm font-semibold text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]"
                        onClick={() => {
                          setActionsOpen(false)
                          setShowRestoreConfirm(true)
                        }}
                      >
                        <ArchiveRestore size={16} aria-hidden />
                        Restore to Completed
                      </button>
                    ) : null}
                  </div>
                ) : null}
              </div>
            ) : null}
          </div>
        }
        footer={
          hasFooterActions ? (
            <div className="flex flex-wrap gap-2 px-5 py-3">
              {canApprove && (
                <button
                  type="button"
                  disabled={submitting}
                  onClick={() => setShowApproveConfirm(true)}
                  className="rounded-xl bg-[var(--color-success)] px-4 py-2 text-sm font-bold text-white disabled:opacity-60"
                >
                  Approve
                </button>
              )}
              {canReject && !showReject && (
                <button
                  type="button"
                  disabled={submitting}
                  onClick={() => setShowReject(true)}
                  className="rounded-xl bg-[var(--color-danger)] px-4 py-2 text-sm font-bold text-white disabled:opacity-60"
                >
                  Reject
                </button>
              )}
              {showReject && (
                <button
                  type="button"
                  disabled={submitting}
                  onClick={reject}
                  className="rounded-xl bg-[var(--color-danger)] px-4 py-2 text-sm font-bold text-white disabled:opacity-60"
                >
                  Confirm reject
                </button>
              )}
              {canMarkCompleted && (
                <button
                  type="button"
                  disabled={submitting}
                  onClick={() => setShowCompleteConfirm(true)}
                  className="rounded-xl bg-[var(--color-accent-blue)] px-4 py-2 text-sm font-bold text-white disabled:opacity-60"
                >
                  Mark completed
                </button>
              )}
              {item.displayStatus === 'rejected' && (
                <button
                  type="button"
                  disabled={submitting}
                  onClick={() => setShowResubmitConfirm(true)}
                  className="rounded-xl border border-[var(--color-border)] px-4 py-2 text-sm font-semibold"
                >
                  Resubmit to Pending
                </button>
              )}
            </div>
          ) : undefined
        }
      >
        <section className="rounded-xl border border-[var(--color-border)] bg-white p-4">
          <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
            <h3 className="text-sm font-bold text-[var(--color-text-primary)]">Event Information</h3>
            {item.eventDate ? (
              <Link
                to={eventCalendarUrl({ requestId: item.id })}
                onClick={onClose}
                className="inline-flex items-center gap-1.5 rounded-lg border border-[var(--color-border)] px-2.5 py-1 text-[11px] font-semibold text-[var(--color-accent-blue)] hover:bg-[var(--color-surface-hover)]"
              >
                <Calendar size={12} />
                View on Calendar
              </Link>
            ) : null}
          </div>
          <dl className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <InfoField label="Event title">{item.eventTitle}</InfoField>
            <InfoField label="Requestor">{item.requestor}</InfoField>
            <InfoField label="Submitted">{item.createdAtLabel}</InfoField>
            <InfoField label="Event date">{item.eventDateLabel}</InfoField>
            <InfoField label="Venue">{item.venue?.trim() ? item.venue : 'Not specified'}</InfoField>
            <InfoField label="Time">{timeLabel}</InfoField>
            <div className="min-w-0 sm:col-span-2">
              <dt className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-secondary)]">
                Description
              </dt>
              <dd className="mt-0.5 whitespace-pre-wrap text-sm leading-relaxed text-[var(--color-text-primary)]">
                {item.details?.trim() ? item.details : 'No additional details provided.'}
              </dd>
            </div>
            {item.rejectionReason ? (
              <div className="min-w-0 rounded-lg border border-red-200 bg-red-50 px-3 py-2 sm:col-span-2">
                <dt className="text-[11px] font-semibold uppercase tracking-wide text-red-700">
                  Rejection reason
                </dt>
                <dd className="mt-0.5 whitespace-pre-wrap text-sm leading-relaxed text-red-800">
                  {item.rejectionReason}
                </dd>
              </div>
            ) : null}
          </dl>
        </section>

        {canApprove && (
          <div className="rounded-xl border border-[var(--color-border)] px-3 py-2.5 text-xs leading-relaxed text-[var(--color-text-secondary)]">
            Approve the request first, then assign the documentation team with ranked recommendations.
            Members must accept before coverage is confirmed.
          </div>
        )}

        {showTeamPanel ? (
          <AssignDocumentationTeamPanel
            item={item}
            onAssigned={async () => {
              await onUpdated()
              try {
                const rows = await fetchRequestAssignments(item.id)
                setAssignments(rows.map((r) => ({ status: String(r.status ?? '') })))
              } catch {
                /* keep prior assignment state */
              }
            }}
          />
        ) : null}

        <RequestMemberRatingsSection
          requestId={item.id}
          assignedMembers={item.assignedMembers}
          visible={showMemberRatings}
          completed={item.displayStatus === 'completed' || item.displayStatus === 'archived'}
        />

        {showCompletionHint && !canMarkCompleted ? (
          <div className="rounded-xl border border-[var(--color-border)] px-3 py-2.5 text-xs leading-relaxed text-[var(--color-text-secondary)]">
            Mark completed unlocks after at least one assigned member accepts coverage.
          </div>
        ) : null}

        {showCompletionHint && canMarkCompleted && !eventDateReached ? (
          <div className="rounded-xl border border-[var(--color-border)] px-3 py-2.5 text-xs leading-relaxed text-[var(--color-text-secondary)]">
            Scheduled event date is {item.eventDateLabel}. You may mark completed when documentation is
            finished, including multi-day or extended campus events that run past that date.
          </div>
        ) : null}

        {showReject && (
          <div className="space-y-1.5">
            <label className="text-xs font-bold text-[var(--color-text-secondary)]">
              Rejection reason (min 8 characters)
            </label>
            <textarea
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              rows={3}
              className="w-full rounded-xl border border-[var(--color-border)] bg-white px-3 py-2 text-sm"
            />
          </div>
        )}

        {error && <div className="text-sm text-red-600">{error}</div>}
      </AdminDrawer>

      <AdminConfirmDialog
        open={showApproveConfirm}
        title="Approve documentation request?"
        message={`The requestor will be notified that "${item.eventTitle}" was approved. You can assign the team next.`}
        confirmLabel="Approve"
        tone="success"
        loading={submitting}
        onConfirm={approve}
        onCancel={() => setShowApproveConfirm(false)}
      />

      <AdminConfirmDialog
        open={showCompleteConfirm}
        title="Mark documentation completed?"
        message={`Confirm that documentation for "${item.eventTitle}" is finished (use your judgment for multi-day or extended events). The requestor will be notified.`}
        confirmLabel="Mark completed"
        tone="success"
        loading={submitting}
        onConfirm={markCompleted}
        onCancel={() => setShowCompleteConfirm(false)}
      />

      <AdminConfirmDialog
        open={showResubmitConfirm}
        title="Move back to Pending?"
        message={`"${item.eventTitle}" will return to the pending queue for review.`}
        confirmLabel="Move to Pending"
        loading={submitting}
        onConfirm={resubmit}
        onCancel={() => setShowResubmitConfirm(false)}
      />

      <AdminConfirmDialog
        open={showArchiveConfirm}
        title="Archive completed request?"
        message={`"${item.eventTitle}" (${requestRefLabel(item.id)}) will move to Archived. Assignments, feedback, and gallery files stay in the system for records and analytics.`}
        confirmLabel="Archive request"
        loading={submitting}
        onConfirm={archiveCompletedRequest}
        onCancel={() => setShowArchiveConfirm(false)}
      />

      <AdminConfirmDialog
        open={showRestoreConfirm}
        title="Restore archived request?"
        message={`"${item.eventTitle}" (${requestRefLabel(item.id)}) will return to the Completed list.`}
        confirmLabel="Restore"
        loading={submitting}
        onConfirm={restoreArchivedRequest}
        onCancel={() => setShowRestoreConfirm(false)}
      />
    </>
  )
}
