import { Check, Loader2, X } from 'lucide-react'
import { useState } from 'react'
import { AdminEmptyState } from '../AdminEmptyState'
import type { PendingRegistration } from '../../lib/teamMembers'
import { formatTeamDate } from '../../lib/teamMembers'
import { MemberAvatar } from './TeamMemberBadges'

interface Props {
  registrations: PendingRegistration[]
  onApprove: (id: number) => Promise<void>
  onReject: (id: number, reason: string) => Promise<void>
}

function PendingRegistrationRow({
  registration,
  onApprove,
  onReject,
}: {
  registration: PendingRegistration
  onApprove: (id: number) => Promise<void>
  onReject: (id: number, reason: string) => Promise<void>
}) {
  const [busy, setBusy] = useState<'approve' | 'reject' | null>(null)
  const [showReject, setShowReject] = useState(false)
  const [reason, setReason] = useState('')

  async function handleApprove() {
    setBusy('approve')
    try {
      await onApprove(registration.id)
    } finally {
      setBusy(null)
    }
  }

  async function handleReject() {
    if (reason.trim().length < 3) return
    setBusy('reject')
    try {
      await onReject(registration.id, reason.trim())
      setShowReject(false)
      setReason('')
    } finally {
      setBusy(null)
    }
  }

  return (
    <>
      <tr className="border-b border-[var(--color-border-subtle)] last:border-0">
        <td className="px-4 py-3">
          <div className="flex items-center gap-3">
            <MemberAvatar
              name={registration.name}
              avatarUrl={registration.avatarUrl}
              size="sm"
              fallbackClassName="bg-amber-500/15 text-amber-300"
            />
            <div>
              <div className="font-bold text-[var(--color-text-primary)]">{registration.name}</div>
              <div className="text-xs text-[var(--color-text-secondary)]">{registration.email}</div>
            </div>
          </div>
        </td>
        <td className="px-4 py-3 text-xs text-[var(--color-text-secondary)]">
          {registration.studentId ?? '—'}
        </td>
        <td className="px-4 py-3 text-xs font-semibold text-[var(--color-accent-blue)]">
          {registration.skillLevel ?? '—'}
        </td>
        <td className="px-4 py-3 text-xs text-[var(--color-text-secondary)]">
          {formatTeamDate(registration.dateRegistered)}
        </td>
        <td className="px-4 py-3">
          <div className="flex justify-end gap-2">
            <button
              type="button"
              disabled={busy !== null}
              onClick={handleApprove}
              className="inline-flex items-center gap-1 rounded-lg bg-[var(--color-accent-blue)] px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-50"
            >
              {busy === 'approve' ? <Loader2 size={14} className="animate-spin" /> : <Check size={14} />}
              Approve
            </button>
            <button
              type="button"
              disabled={busy !== null}
              onClick={() => setShowReject((v) => !v)}
              className="inline-flex items-center gap-1 rounded-lg border border-red-500/30 px-3 py-1.5 text-xs font-semibold text-red-300 disabled:opacity-50"
            >
              <X size={14} />
              Reject
            </button>
          </div>
        </td>
      </tr>
      {showReject && (
        <tr className="border-b border-[var(--color-border-subtle)] bg-[var(--color-surface-muted)]">
          <td colSpan={5} className="px-4 py-3">
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="Rejection reason (min 3 characters)…"
              rows={2}
              className="admin-input w-full rounded-xl px-3 py-2 text-sm"
            />
            <div className="mt-2 flex gap-2">
              <button
                type="button"
                disabled={busy !== null || reason.trim().length < 3}
                onClick={handleReject}
                className="inline-flex items-center gap-1 rounded-lg bg-red-600 px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-50"
              >
                {busy === 'reject' ? <Loader2 size={14} className="animate-spin" /> : <X size={14} />}
                Confirm reject
              </button>
              <button
                type="button"
                disabled={busy !== null}
                onClick={() => setShowReject(false)}
                className="rounded-lg border border-[var(--color-border)] px-3 py-1.5 text-xs font-semibold text-[var(--color-text-secondary)]"
              >
                Cancel
              </button>
            </div>
          </td>
        </tr>
      )}
    </>
  )
}

export function PendingRegistrationsTable({ registrations, onApprove, onReject }: Props) {
  if (registrations.length === 0) {
    return (
      <AdminEmptyState title="No pending member registrations">
        New member sign-ups will appear here for approval.
      </AdminEmptyState>
    )
  }

  return (
    <div className="overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)]">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[720px] text-left text-sm">
          <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
            <tr>
              <th className="px-4 py-3">Applicant</th>
              <th className="px-4 py-3">Student ID</th>
              <th className="px-4 py-3">Skill</th>
              <th className="px-4 py-3">Registered</th>
              <th className="px-4 py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {registrations.map((r) => (
              <PendingRegistrationRow
                key={r.id}
                registration={r}
                onApprove={onApprove}
                onReject={onReject}
              />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
