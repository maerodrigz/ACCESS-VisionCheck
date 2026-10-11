import { useEffect, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { Calendar } from 'lucide-react'
import { eventCalendarUrl } from '../../lib/adminCrossLinks'
import { AdminDrawer } from '../AdminDrawer'
import { DrawerBackButton } from '../AdminBackButton'
import { AdminConfirmDialog } from '../AdminConfirmDialog'
import { fetchRequestAssignments, setRequestStatus } from '../../api/admin'
import type { DocumentationRequestItem } from '../../lib/documentationRequests'
import { requestRefLabel } from '../../lib/documentationRequests'
import { AssignDocumentationTeamPanel } from './AssignDocumentationTeamPanel'
import { RequestMemberRatingsSection } from './RequestMemberRatingsSection'
import { MemberAvatarStack, PriorityBadge, StatusBadge } from './RequestBadges'

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

function ReviewBentoTile({
  label,
  children,
  className = '',
  dense,
}: {
  label: string
  children: ReactNode
  className?: string
  dense?: boolean
}) {
  return (
    <div
      className={[
        'flex min-h-[88px] flex-col rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-3.5 shadow-[0_1px_2px_rgba(15,39,68,0.04)]',
        className,
      ]
        .filter(Boolean)
        .join(' ')}
    >
      <div className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
        {label}
      </div>
      <div className={dense ? 'mt-1.5 min-w-0 flex-1 text-sm' : 'mt-2 min-w-0 flex-1 text-sm'}>
        {children}
      </div>
    </div>
  )
}

interface Props {
  item: DocumentationRequestItem
  onClose: () => void
  onUpdated: () => void | Promise<void>
}

export function RequestReviewPanel({ item: initialItem, onClose, onUpdated }: Props) {
  const [item, setItem] = useState(initialItem)
  const [submitting, setSubmitting] = useState(false)
  const [rejectReason, setRejectReason] = useState('')
  const [showReject, setShowReject] = useState(false)
  const [showApproveConfirm, setShowApproveConfirm] = useState(false)
  const [showCompleteConfirm, setShowCompleteConfirm] = useState(false)
  const [showResubmitConfirm, setShowResubmitConfirm] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [assignments, setAssignments] = useState<{ status: string }[]>([])

  useEffect(() => {
    setItem(initialItem)
  }, [initialItem])

  useEffect(() => {
    const approved =
      initialItem.displayStatus === 'approved' || initialItem.displayStatus === 'completed'
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
    item.displayStatus === 'approved' || item.displayStatus === 'completed'
  const showCompletionHint =
    item.displayStatus === 'approved' && item.rawStatus.toLowerCase() !== 'completed'
  const showMemberRatings =
    item.assignedMembers.length > 0 &&
    (item.displayStatus === 'completed' || eventDateReached)

  return (
    <>
      <AdminDrawer
        open
        onClose={onClose}
        title="Review request"
        maxWidth="2xl"
        bodyClassName="space-y-4 px-5 pb-5"
        header={
          <div className="flex items-center gap-2 border-b border-[var(--color-border)] px-5 py-4">
            <DrawerBackButton onClick={onClose} label="Back" />
            <div className="min-w-0 flex-1">
              <h2 className="text-lg font-extrabold text-[var(--color-text-primary)]">Review request</h2>
              <p className="text-xs font-semibold text-[var(--color-text-secondary)]">
                {requestRefLabel(item.id)} · Submitted {item.createdAtLabel}
              </p>
              <p className="mt-0.5 text-xs text-[var(--color-text-secondary)]">{item.eventTitle}</p>
            </div>
          </div>
        }
        footer={
          <div className="flex flex-wrap gap-2 p-4">
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
        }
      >
          <div className="flex flex-wrap gap-2">
            <StatusBadge status={item.displayStatus} />
            <PriorityBadge priority={item.priority} />
          </div>

          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 sm:auto-rows-fr">
            <ReviewBentoTile label="Event" className="sm:col-span-2 min-h-[72px]">
              <p className="text-base font-extrabold leading-snug text-[var(--color-text-primary)]">
                {item.eventTitle}
              </p>
              <p className="mt-1 text-xs font-semibold text-[var(--color-text-secondary)]">
                {requestRefLabel(item.id)}
              </p>
            </ReviewBentoTile>

            <ReviewBentoTile label="Requestor">
              <p className="font-semibold text-[var(--color-text-primary)]">{item.requestor}</p>
            </ReviewBentoTile>

            <ReviewBentoTile label="Submitted">
              <p className="font-semibold text-[var(--color-text-primary)]">{item.createdAtLabel}</p>
            </ReviewBentoTile>

            <ReviewBentoTile label="Event date">
              <p className="font-semibold text-[var(--color-text-primary)]">{item.eventDateLabel}</p>
              <p className="mt-1.5 text-xs leading-snug text-[var(--color-text-secondary)]">
                Requestor reference date (start or primary day). Mark completed when coverage is actually done.
              </p>
              {item.eventDate ? (
                <Link
                  to={eventCalendarUrl({ requestId: item.id })}
                  onClick={onClose}
                  className="mt-2 inline-flex items-center gap-1.5 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-2.5 py-1 text-[11px] font-semibold text-[var(--color-accent-blue)] hover:bg-[var(--color-surface-hover)]"
                >
                  <Calendar size={12} />
                  View on calendar
                </Link>
              ) : null}
            </ReviewBentoTile>

            <ReviewBentoTile label="Venue">
              <p className="font-semibold text-[var(--color-text-primary)]">
                {item.venue?.trim() ? item.venue : 'Not specified'}
              </p>
            </ReviewBentoTile>

            <ReviewBentoTile label="Request details" className="sm:col-span-2">
              <p className="whitespace-pre-wrap text-sm leading-relaxed text-[var(--color-text-secondary)]">
                {item.details?.trim() ? item.details : 'No additional details provided.'}
              </p>
            </ReviewBentoTile>

            {item.rejectionReason ? (
              <ReviewBentoTile
                label="Rejection reason"
                className="sm:col-span-2 border-red-500/30 bg-red-500/10"
              >
                <p className="whitespace-pre-wrap text-sm leading-relaxed text-[var(--color-danger-text)]">
                  {item.rejectionReason}
                </p>
              </ReviewBentoTile>
            ) : null}

            <ReviewBentoTile label="Assigned members" className="sm:col-span-2 min-h-[72px]" dense>
              <MemberAvatarStack members={item.assignedMembers} />
            </ReviewBentoTile>
          </div>

          <RequestMemberRatingsSection
            requestId={item.id}
            assignedMembers={item.assignedMembers}
            visible={showMemberRatings}
          />

          {canApprove && (
            <div className="rounded-xl border border-dashed border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm text-[var(--color-text-secondary)]">
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

          {showCompletionHint && !canMarkCompleted ? (
            <div className="rounded-xl border border-dashed border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm text-[var(--color-text-secondary)]">
              Mark completed unlocks after at least one assigned member accepts coverage.
            </div>
          ) : null}

          {showCompletionHint && canMarkCompleted && !eventDateReached ? (
            <div className="rounded-xl border border-dashed border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm text-[var(--color-text-secondary)]">
              Scheduled event date is {item.eventDateLabel}. You may mark completed when documentation is finished,
              including multi-day or extended campus events that run past that date.
            </div>
          ) : null}

          {showReject && (
            <div className="space-y-2">
              <label className="text-xs font-bold text-[var(--color-text-secondary)]">
                Rejection reason (min 8 characters)
              </label>
              <textarea
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
                rows={3}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2 text-sm"
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
    </>
  )
}
