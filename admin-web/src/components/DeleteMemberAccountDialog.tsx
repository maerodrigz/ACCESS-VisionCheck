import { useEffect, useState } from 'react'
import { Loader2, X } from 'lucide-react'
import { fetchMemberMediaUploadCount } from '../api/admin'
import type { AccountRole } from '../lib/accountManagement'

interface Props {
  open: boolean
  memberName: string
  memberEmail: string
  userId: number
  accountRole?: AccountRole
  loading?: boolean
  onConfirm: (confirmationEmail: string) => void
  onCancel: () => void
}

export function DeleteMemberAccountDialog({
  open,
  memberName,
  memberEmail,
  userId,
  accountRole = 'Member',
  loading = false,
  onConfirm,
  onCancel,
}: Props) {
  const isRequestor = accountRole === 'Organization'
  const accountLabel = isRequestor ? 'requestor' : 'member'
  const [confirmEmail, setConfirmEmail] = useState('')
  const [uploadCount, setUploadCount] = useState<number | null>(null)

  useEffect(() => {
    if (!open) {
      setConfirmEmail('')
      return
    }
    let cancelled = false
    fetchMemberMediaUploadCount(userId)
      .then((n) => {
        if (!cancelled) setUploadCount(n)
      })
      .catch(() => {
        if (!cancelled) setUploadCount(null)
      })
    return () => {
      cancelled = true
    }
  }, [open, userId])

  if (!open) return null

  const emailMatches = confirmEmail.trim().toLowerCase() === memberEmail.trim().toLowerCase()
  const canSubmit = emailMatches && !loading

  return (
    <>
      <button
        type="button"
        aria-label="Close dialog"
        className="fixed inset-0 z-[60] bg-black/40"
        onClick={loading ? undefined : onCancel}
      />
      <div
        role="dialog"
        aria-modal="true"
        className="fixed left-1/2 top-1/2 z-[70] w-full max-w-md -translate-x-1/2 -translate-y-1/2 overflow-hidden rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-xl"
      >
        <div className="flex items-start justify-between border-b border-[var(--color-border)] px-5 py-4">
          <div>
            <h2 className="text-base font-extrabold text-[var(--color-text-primary)]">
              Delete {accountLabel} account permanently?
            </h2>
            <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
              This removes <strong className="text-[var(--color-text-primary)]">{memberName}</strong> and
              eligible {accountLabel}-owned data: practice evaluations, AI detection history, rankings,
              assignments, and uploaded media (database and Supabase when configured). Shared documentation
              owned by other users is not removed.
              {isRequestor
                ? ' Requestors with active documentation requests must resolve those first (use Deactivate instead).'
                : null}{' '}
              This cannot be undone. Use Deactivate if you only need to block sign-in while keeping everything.
            </p>
          </div>
          <button
            type="button"
            onClick={onCancel}
            disabled={loading}
            className="rounded-lg p-1 text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] disabled:opacity-50"
          >
            <X size={18} />
          </button>
        </div>
        <div className="space-y-3 px-5 py-4">
          {uploadCount != null ? (
            <p className="text-xs font-semibold text-[var(--color-text-secondary)]">
              {uploadCount} uploaded file(s) will be targeted for removal with this account.
            </p>
          ) : null}
          <label className="block">
            <span className="text-xs font-bold text-[var(--color-text-secondary)]">
              Type the account email to confirm
            </span>
            <input
              type="email"
              autoComplete="off"
              value={confirmEmail}
              disabled={loading}
              placeholder={memberEmail}
              onChange={(e) => setConfirmEmail(e.target.value)}
              className="admin-input mt-1.5 w-full rounded-lg py-2 text-sm"
            />
          </label>
        </div>
        <div className="flex gap-2 px-5 py-4">
          <button
            type="button"
            onClick={onCancel}
            disabled={loading}
            className="flex-1 rounded-xl border border-[var(--color-border)] py-2.5 text-sm font-semibold text-[var(--color-text-secondary)] disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={() => onConfirm(confirmEmail.trim())}
            disabled={!canSubmit}
            className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[var(--color-danger)] py-2.5 text-sm font-bold text-white disabled:opacity-50"
          >
            {loading ? <Loader2 size={16} className="animate-spin" /> : null}
            Delete permanently
          </button>
        </div>
      </div>
    </>
  )
}
