import { useEffect, useState } from 'react'
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
    eventDateReached &&
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
        maxWidth="xl"
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

          <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-4">
            <h4 className="text-sm font-bold text-[var(--color-text-primary)]">{item.eventTitle}</h4>
            <dl className="mt-3 space-y-3 text-sm">
              <div>
                <dt className="text-xs font-bold text-[var(--color-text-secondary)]">Requestor</dt>
                <dd className="mt-0.5 font-semibold text-[var(--color-text-primary)]">{item.requestor}</dd>
              </div>
              <div>
                <dt className="text-xs font-bold text-[var(--color-text-secondary)]">Event date</dt>
                <dd className="mt-0.5 text-[var(--color-text-primary)]">{item.eventDateLabel}</dd>
                {item.eventDate ? (
                  <dd className="mt-2">
                    <Link
                      to={eventCalendarUrl({ requestId: item.id })}
                      onClick={onClose}
                      className="inline-flex items-center gap-1.5 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-3 py-1.5 text-[11px] font-semibold text-[var(--color-accent-blue)] hover:bg-[var(--color-surface-hover)]"
                    >
                      <Calendar size={12} />
                      View on calendar
                    </Link>
                  </dd>
                ) : null}
              </div>
              {item.venue ? (
                <div>
                  <dt className="text-xs font-bold text-[var(--color-text-secondary)]">Venue</dt>
                  <dd className="mt-0.5 text-[var(--color-text-primary)]">{item.venue}</dd>
                </div>
              ) : null}
              <div>
                <dt className="text-xs font-bold text-[var(--color-text-secondary)]">Request details</dt>
                <dd className="mt-1 whitespace-pre-wrap text-sm leading-relaxed text-[var(--color-text-secondary)]">
                  {item.details?.trim() ? item.details : 'No additional details provided.'}
                </dd>
              </div>
            </dl>
          </div>

          {item.rejectionReason ? (
            <div className="rounded-xl border border-red-500/30 bg-red-500/10 px-3 py-2 text-sm text-red-300">
              <div className="text-xs font-bold">Rejection reason</div>
              <p className="mt-1 whitespace-pre-wrap leading-relaxed">{item.rejectionReason}</p>
            </div>
          ) : null}

          <div>
            <div className="mb-2 text-xs font-bold text-[var(--color-text-secondary)]">Assigned members</div>
            <MemberAvatarStack members={item.assignedMembers} />
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
              {!eventDateReached
                ? `Mark completed unlocks on ${item.eventDateLabel}, after the event has taken place.`
                : !coverageConfirmed
                  ? 'Mark completed unlocks after at least one assigned member accepts coverage.'
                  : null}
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
        message={`The requestor will be notified that documentation for "${item.eventTitle}" is complete.`}
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
