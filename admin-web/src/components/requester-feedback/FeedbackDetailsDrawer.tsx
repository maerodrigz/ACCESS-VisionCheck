import { useEffect, useState, type ReactNode } from 'react'
import { ExternalLink } from 'lucide-react'
import { Link } from 'react-router-dom'
import { AdminDrawer } from '../AdminDrawer'
import { DrawerBackButton } from '../AdminBackButton'
import type { RequesterFeedbackItem } from '../../lib/requesterFeedback'
import {
  DEFAULT_ADMIN_RESPONSE,
  formatFeedbackDate,
  parseFeedbackComment,
} from '../../lib/requesterFeedback'
import { FeedbackStatusBadge, LowRatingAlertBanner, StarRatingDisplay } from './FeedbackBadges'

interface Props {
  item: RequesterFeedbackItem | null
  focusResponse?: boolean
  onClose: () => void
  onSendResponse: (response: string) => void
  onMarkReviewed: () => void
  onArchive: () => void
}

export function FeedbackDetailsDrawer({
  item,
  focusResponse = false,
  onClose,
  onSendResponse,
  onMarkReviewed,
  onArchive,
}: Props) {
  const [response, setResponse] = useState(DEFAULT_ADMIN_RESPONSE)

  useEffect(() => {
    if (item) setResponse(item.adminResponse ?? DEFAULT_ADMIN_RESPONSE)
  }, [item])

  useEffect(() => {
    if (focusResponse && item) {
      document.getElementById('admin-feedback-response')?.focus()
    }
  }, [focusResponse, item])

  if (!item) return null

  const summary = item.eventSummary
  const parsedComment = parseFeedbackComment(item.comment)
  const hasResponse = Boolean(item.adminResponse?.trim())
  const showMarkReviewed = item.reviewStatus === 'pending' && !hasResponse
  const sendLabel = hasResponse ? 'Update response' : 'Send response'

  return (
    <AdminDrawer
      open
      onClose={onClose}
      title="Feedback details"
      maxWidth="xl"
      bodyClassName="px-5 pb-5"
      header={
        <div className="flex items-center gap-2 border-b border-[var(--color-border)] px-5 py-4">
          <DrawerBackButton onClick={onClose} label="Back" />
          <div className="min-w-0 flex-1">
            <h2 className="text-base font-extrabold text-[var(--color-text-primary)]">Feedback details</h2>
            <FeedbackStatusBadge status={item.reviewStatus} />
          </div>
        </div>
      }
      footer={
        <div className="flex flex-wrap gap-2 bg-[var(--color-surface-muted)] p-4">
          <button
            type="button"
            onClick={() => onSendResponse(response)}
            className="rounded-lg bg-[var(--color-accent-blue)] px-4 py-2 text-sm font-semibold text-white"
          >
            {sendLabel}
          </button>
          {showMarkReviewed ? (
            <button
              type="button"
              onClick={onMarkReviewed}
              className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-4 py-2 text-sm font-semibold"
            >
              Mark as reviewed
            </button>
          ) : null}
          <button
            type="button"
            onClick={onArchive}
            className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-4 py-2 text-sm font-semibold"
          >
            Archive
          </button>
        </div>
      }
    >
          <Section title="Event information">
            <InfoRow label="Event name" value={item.eventName} />
            <InfoRow label="Organization" value={item.organization} />
            <InfoRow label="Requester" value={item.requesterName} />
            <InfoRow label="Event date" value={formatFeedbackDate(item.eventDate)} />
            <InfoRow label="Completion date" value={formatFeedbackDate(item.completionDate)} />
            <Link
              to={`/documentation-requests?request=${item.requestId}`}
              className="mt-2 inline-flex items-center gap-1.5 text-xs font-semibold text-[var(--color-accent-blue)] hover:underline"
            >
              <ExternalLink size={12} />
              Open documentation request
            </Link>
          </Section>

          <Section title="Service summary">
            <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3.5 text-xs">
              <InfoRow label="Photographers" value={summary.photographers.join(', ') || '—'} />
              <InfoRow label="Videographers" value={summary.videographers.join(', ') || '—'} />
              <InfoRow label="Photos / Videos" value={`${summary.photoCount} / ${summary.videoCount}`} />
              <InfoRow label="Facebook published" value={summary.facebookPublished ? 'Yes' : 'No'} />
            </div>
          </Section>

          <Section title="Requester rating">
            <StarRatingDisplay rating={item.rating} size={24} showValue />
            {item.needsAttention && item.attentionReason && (
              <div className="mt-3">
                <LowRatingAlertBanner reason={item.attentionReason} />
              </div>
            )}
          </Section>

          <Section title="Requester comments">
            <p className="mb-2 text-xs font-semibold text-[var(--color-text-secondary)]">
              Type: <span className="text-[var(--color-text-primary)]">{parsedComment.type}</span>
            </p>
            <p className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3.5 text-sm leading-relaxed">
              {parsedComment.body.trim() || 'No written comment provided.'}
            </p>
          </Section>

          <Section title="Admin response">
            {hasResponse ? (
              <div className="mb-3 rounded-xl border border-[rgba(34,197,94,0.35)] bg-[rgba(34,197,94,0.08)] p-3.5">
                <p className="text-xs font-extrabold text-[var(--color-success)]">Response sent to requestor</p>
                <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-primary)]">{item.adminResponse}</p>
              </div>
            ) : null}
            <p className="mb-2 text-[11px] font-semibold text-[var(--color-text-secondary)]">
              {hasResponse ? 'Edit response (optional)' : 'Write a reply for the requestor'}
            </p>
            <textarea
              id="admin-feedback-response"
              value={response}
              onChange={(e) => setResponse(e.target.value)}
              rows={5}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2 text-sm outline-none focus:border-[var(--color-accent-cyan)]"
            />
          </Section>
    </AdminDrawer>
  )
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="mt-5">
      <h4 className="text-xs font-extrabold uppercase tracking-wide text-[var(--color-text-secondary)]">{title}</h4>
      <div className="mt-2">{children}</div>
    </div>
  )
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="mb-2 flex gap-3 text-xs">
      <span className="w-32 shrink-0 text-[var(--color-text-secondary)]">{label}</span>
      <span className="font-semibold text-[var(--color-text-primary)]">{value}</span>
    </div>
  )
}
