import { Loader2, X } from 'lucide-react'

interface Props {
  open: boolean
  summary: string
  saving: boolean
  onConfirm: () => void
  onCancel: () => void
}

export function SecurityConfirmModal({ open, summary, saving, onConfirm, onCancel }: Props) {
  if (!open) return null

  return (
    <div className="sys-config__modal-backdrop" onClick={saving ? undefined : onCancel}>
      <div
        className="sys-config__modal"
        role="dialog"
        aria-labelledby="security-confirm-title"
        aria-modal="true"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="sys-config__modal-header">
          <h3 id="security-confirm-title" className="sys-config__modal-title">
            Apply security changes?
          </h3>
          <button
            type="button"
            className="sys-config__modal-close"
            onClick={onCancel}
            disabled={saving}
            aria-label="Close"
          >
            <X size={18} />
          </button>
        </div>
        <div className="sys-config__modal-body">
          <p className="sys-config__confirm-lead">
            These settings affect sign-in, sessions, and password rules for all accounts.
          </p>
          <div className="sys-config__confirm-summary">
            {summary.split('\n').map((line) => (
              <div key={line}>{line}</div>
            ))}
          </div>
          <p className="sys-config__confirm-note">
            Existing sessions keep their current expiry until users sign in again. Passwords and
            authentication secrets are never shown or stored in this panel.
          </p>
        </div>
        <div className="sys-config__modal-footer">
          <button
            type="button"
            className="sys-config__btn sys-config__btn--ghost"
            onClick={onCancel}
            disabled={saving}
          >
            Cancel
          </button>
          <button
            type="button"
            className="sys-config__btn sys-config__btn--danger"
            onClick={onConfirm}
            disabled={saving}
          >
            {saving ? (
              <>
                <Loader2 size={16} className="animate-spin" aria-hidden />
                Saving…
              </>
            ) : (
              'Apply Changes'
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
