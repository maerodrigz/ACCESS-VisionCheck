import './profile-dropdown.css'

interface LogoutConfirmDialogProps {
  open: boolean
  onCancel: () => void
  onConfirm: () => void
}

/** Shared sign-out confirmation (profile menu + sidebar footer). */
export function LogoutConfirmDialog({ open, onCancel, onConfirm }: LogoutConfirmDialogProps) {
  return (
    <div
      className={['pd-modal-overlay', open ? 'is-visible' : ''].filter(Boolean).join(' ')}
      role="dialog"
      aria-modal="true"
      aria-labelledby="logout-modal-title"
      aria-hidden={!open}
      onClick={(e) => {
        if (e.target === e.currentTarget) onCancel()
      }}
    >
      <div className="pd-modal">
        <h2 id="logout-modal-title" className="pd-modal__title">
          Sign out?
        </h2>
        <p className="pd-modal__message">
          You will return to the login screen. Any unsaved changes may be lost.
        </p>
        <div className="pd-modal__actions">
          <button type="button" className="pd-modal__btn pd-modal__btn--cancel" onClick={onCancel}>
            Cancel
          </button>
          <button type="button" className="pd-modal__btn pd-modal__btn--confirm" onClick={onConfirm}>
            Sign out
          </button>
        </div>
      </div>
    </div>
  )
}
