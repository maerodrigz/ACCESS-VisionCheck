import { Loader2, X } from 'lucide-react'
import {
  ACCOUNT_ROLES,
  accountRoleLabel,
  type AdminAccountUser,
} from '../../lib/accountManagement'

export type AccountActionKind =
  | 'confirm-deactivate'
  | 'confirm-activate'
  | 'confirm-reset-password'
  | 'change-role'
  | 'reset-success'

export interface AccountActionState {
  kind: AccountActionKind
  user: AdminAccountUser
  role?: string
  loading?: boolean
  error?: string | null
  temporaryPassword?: string
}

interface Props {
  action: AccountActionState | null
  onClose: () => void
  onConfirm: () => void
  onRoleChange: (role: string) => void
}

const CONFIRM_CONFIG: Record<
  'confirm-deactivate' | 'confirm-activate' | 'confirm-reset-password',
  { title: string; text: (name: string) => string; confirm: string; danger: boolean }
> = {
  'confirm-deactivate': {
    title: 'Deactivate Account',
    text: (name) =>
      `Deactivate ${name}? They will not be able to sign in until reactivated.`,
    confirm: 'Deactivate Account',
    danger: true,
  },
  'confirm-activate': {
    title: 'Activate Account',
    text: (name) => `Activate ${name}? They will be able to sign in again.`,
    confirm: 'Activate Account',
    danger: false,
  },
  'confirm-reset-password': {
    title: 'Reset Password',
    text: (name) =>
      `Reset password for ${name}? A new temporary password will be generated.`,
    confirm: 'Reset Password',
    danger: true,
  },
}

export function AccountActionModal({ action, onClose, onConfirm, onRoleChange }: Props) {
  if (!action) return null

  const loading = action.loading === true
  const { user } = action

  if (action.kind === 'reset-success') {
    return (
      <div className="account-mgmt__modal-backdrop" onClick={onClose}>
        <div
          className="account-mgmt__modal account-mgmt__modal--form"
          role="dialog"
          aria-labelledby="reset-success-title"
          aria-modal="true"
          onClick={(e) => e.stopPropagation()}
        >
          <div className="account-mgmt__modal-header">
            <h2 id="reset-success-title">Password Reset</h2>
            <button type="button" className="account-mgmt__modal-close" onClick={onClose} aria-label="Close">
              <X size={18} aria-hidden />
            </button>
          </div>
          <div className="account-mgmt__modal-body">
            <p className="account-mgmt__confirm-text">
              Temporary password for <strong>{user.name}</strong>. Copy it now. It will not be shown
              again.
            </p>
            <div className="account-mgmt__temp-password">{action.temporaryPassword || ''}</div>
          </div>
          <div className="account-mgmt__modal-footer">
            <button type="button" className="account-mgmt__btn account-mgmt__btn--primary" onClick={onClose}>
              Done
            </button>
          </div>
        </div>
      </div>
    )
  }

  if (action.kind === 'change-role') {
    const role = action.role || user.role
    return (
      <div className="account-mgmt__modal-backdrop" onClick={loading ? undefined : onClose}>
        <div
          className="account-mgmt__modal account-mgmt__modal--form"
          role="dialog"
          aria-labelledby="change-role-title"
          aria-modal="true"
          onClick={(e) => e.stopPropagation()}
        >
          <div className="account-mgmt__modal-header">
            <h2 id="change-role-title">Change Role</h2>
            <button
              type="button"
              className="account-mgmt__modal-close"
              onClick={onClose}
              disabled={loading}
              aria-label="Close"
            >
              <X size={18} aria-hidden />
            </button>
          </div>
          {action.error ? (
            <div className="account-mgmt__form-alert" role="alert">
              {action.error}
            </div>
          ) : null}
          <div className="account-mgmt__modal-body">
            <p className="account-mgmt__confirm-text">
              Update role for <strong>{user.name}</strong>
            </p>
            <label className="account-mgmt__field">
              <span>Role</span>
              <select
                value={role}
                onChange={(e) => onRoleChange(e.target.value)}
                disabled={loading}
              >
                {ACCOUNT_ROLES.map((r) => (
                  <option key={r} value={r}>
                    {accountRoleLabel(r)}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <div className="account-mgmt__modal-footer">
            <button
              type="button"
              className="account-mgmt__btn account-mgmt__btn--ghost"
              onClick={onClose}
              disabled={loading}
            >
              Cancel
            </button>
            <button
              type="button"
              className="account-mgmt__btn account-mgmt__btn--primary"
              onClick={onConfirm}
              disabled={loading}
            >
              {loading ? (
                <>
                  <Loader2 size={16} className="account-mgmt__spin" aria-hidden />
                  Saving…
                </>
              ) : (
                'Save Role'
              )}
            </button>
          </div>
        </div>
      </div>
    )
  }

  const cfg = CONFIRM_CONFIG[action.kind]
  if (!cfg) return null

  return (
    <div className="account-mgmt__modal-backdrop" onClick={loading ? undefined : onClose}>
      <div
        className="account-mgmt__modal account-mgmt__modal--form"
        role="dialog"
        aria-labelledby="action-title"
        aria-modal="true"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="account-mgmt__modal-header">
          <h2 id="action-title">{cfg.title}</h2>
          <button
            type="button"
            className="account-mgmt__modal-close"
            onClick={onClose}
            disabled={loading}
            aria-label="Close"
          >
            <X size={18} aria-hidden />
          </button>
        </div>
        {action.error ? (
          <div className="account-mgmt__form-alert" role="alert">
            {action.error}
          </div>
        ) : null}
        <div className="account-mgmt__modal-body">
          <p className="account-mgmt__confirm-text">{cfg.text(user.name)}</p>
        </div>
        <div className="account-mgmt__modal-footer">
          <button
            type="button"
            className="account-mgmt__btn account-mgmt__btn--ghost"
            onClick={onClose}
            disabled={loading}
          >
            Cancel
          </button>
          <button
            type="button"
            className={`account-mgmt__btn ${cfg.danger ? 'account-mgmt__btn--danger' : 'account-mgmt__btn--primary'}`}
            onClick={onConfirm}
            disabled={loading}
          >
            {loading ? (
              <>
                <Loader2 size={16} className="account-mgmt__spin" aria-hidden />
                Working…
              </>
            ) : (
              cfg.confirm
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
