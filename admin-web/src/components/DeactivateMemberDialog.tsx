import { Loader2, X } from 'lucide-react'

interface Props {
  open: boolean
  memberName: string
  loading?: boolean
  onConfirm: () => void
  onCancel: () => void
}

export function DeactivateMemberDialog({
  open,
  memberName,
  loading = false,
  onConfirm,
  onCancel,
}: Props) {
  if (!open) return null

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
            <h2 className="text-base font-extrabold text-[var(--color-text-primary)]">Deactivate member?</h2>
            <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
              {memberName} will lose sign-in access until you reactivate the account. Uploads, evaluation
              scores, AI review history, assignments, and rankings stay in the system.
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
        <p className="px-5 py-3 text-xs text-[var(--color-text-secondary)]">
          To permanently delete an account and optionally remove uploads, use Account Management → Actions →
          Delete account permanently.
        </p>
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
            onClick={onConfirm}
            disabled={loading}
            className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[var(--color-danger)] py-2.5 text-sm font-bold text-white disabled:opacity-60"
          >
            {loading ? <Loader2 size={16} className="animate-spin" /> : null}
            Deactivate
          </button>
        </div>
      </div>
    </>
  )
}
