import { Check, Loader2, X } from 'lucide-react'
import { useState } from 'react'
import { AdminCard } from '../AdminCard'
import type { PendingRegistration } from '../../lib/teamMembers'
import { formatTeamDate } from '../../lib/teamMembers'
import { MemberAvatar } from './TeamMemberBadges'

interface Props {
  registration: PendingRegistration
  onApprove: (id: number) => Promise<void>
  onReject: (id: number, reason: string) => Promise<void>
}

export function PendingRegistrationCard({ registration, onApprove, onReject }: Props) {
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
    <AdminCard padding="md">
      <div className="flex items-start gap-3">
        <MemberAvatar
          name={registration.name}
          avatarUrl={registration.avatarUrl}
          size="sm"
          fallbackClassName="bg-amber-500/15 text-amber-300"
        />
        <div className="min-w-0 flex-1">
          <h3 className="font-bold text-[var(--color-text-primary)]">{registration.name}</h3>
          <p className="text-xs text-[var(--color-text-secondary)]">{registration.email}</p>
          {registration.studentId && (
            <p className="mt-1 text-xs text-[var(--color-text-secondary)]">ID: {registration.studentId}</p>
          )}
          {registration.skillLevel && (
            <p className="mt-1 text-xs font-semibold text-[var(--color-accent-blue)]">
              {registration.skillLevel}
            </p>
          )}
          <p className="mt-1 text-[10px] text-[var(--color-text-secondary)]">
            Registered {formatTeamDate(registration.dateRegistered)}
          </p>
        </div>
      </div>

      {showReject ? (
        <div className="mt-4 space-y-2">
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Rejection reason (min 3 characters)…"
            rows={3}
            className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2 text-sm outline-none focus:border-[var(--color-accent-cyan)]"
          />
          <div className="flex gap-2">
            <button
              type="button"
              disabled={busy !== null || reason.trim().length < 3}
              onClick={handleReject}
              className="inline-flex flex-1 items-center justify-center gap-1 rounded-lg bg-red-600 py-2 text-sm font-semibold text-white disabled:opacity-50"
            >
              {busy === 'reject' ? <Loader2 size={14} className="animate-spin" /> : <X size={14} />}
              Confirm reject
            </button>
            <button
              type="button"
              disabled={busy !== null}
              onClick={() => setShowReject(false)}
              className="rounded-lg border border-[var(--color-border)] px-4 py-2 text-sm font-semibold text-[var(--color-text-secondary)]"
            >
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <div className="mt-4 flex gap-2">
          <button
            type="button"
            disabled={busy !== null}
            onClick={handleApprove}
            className="inline-flex flex-1 items-center justify-center gap-1 rounded-lg bg-[var(--color-accent-blue)] py-2 text-sm font-semibold text-white disabled:opacity-50"
          >
            {busy === 'approve' ? <Loader2 size={14} className="animate-spin" /> : <Check size={14} />}
            Approve
          </button>
          <button
            type="button"
            disabled={busy !== null}
            onClick={() => setShowReject(true)}
            className="inline-flex flex-1 items-center justify-center gap-1 rounded-lg border border-red-200 py-2 text-sm font-semibold text-red-600 disabled:opacity-50"
          >
            <X size={14} />
            Reject
          </button>
        </div>
      )}
    </AdminCard>
  )
}
