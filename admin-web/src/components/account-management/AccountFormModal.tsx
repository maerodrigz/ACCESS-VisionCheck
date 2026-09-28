import { useEffect, useState, type FormEvent } from 'react'
import { Loader2, X } from 'lucide-react'
import {
  ACCOUNT_ROLES,
  accountRoleLabel,
  CREATE_STATUSES,
  isProtectedAdmin,
  isRequestorRole,
  SKILL_LEVELS,
  validateAccountForm,
  type AccountFormValues,
  type AdminAccountUser,
} from '../../lib/accountManagement'

interface Props {
  mode: 'add' | 'edit'
  open: boolean
  user: AdminAccountUser | null
  allUsers: AdminAccountUser[]
  initialValues: AccountFormValues
  saving: boolean
  apiError: string | null
  onClose: () => void
  onSubmit: (values: AccountFormValues) => void
}

export function AccountFormModal({
  mode,
  open,
  user,
  allUsers,
  initialValues,
  saving,
  apiError,
  onClose,
  onSubmit,
}: Props) {
  const [form, setForm] = useState<AccountFormValues>(initialValues)
  const [errors, setErrors] = useState<Partial<Record<keyof AccountFormValues, string>>>({})

  useEffect(() => {
    if (open) {
      setForm(initialValues)
      setErrors({})
    }
  }, [open, initialValues])

  if (!open) return null

  const protectedAdmin = mode === 'edit' && user ? isProtectedAdmin(user, allUsers) : false
  const title = mode === 'add' ? 'Add Account' : 'Edit Account'
  const subtitle =
    mode === 'add'
      ? 'Create a new user with role, skill level, and access status.'
      : `Update ${user?.name ?? 'account'}'s profile, role, and access.`

  function updateField<K extends keyof AccountFormValues>(field: K, value: AccountFormValues[K]) {
    setForm((prev) => ({ ...prev, [field]: value }))
    setErrors((prev) => {
      if (!prev[field]) return prev
      const next = { ...prev }
      delete next[field]
      return next
    })
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault()
    const nextErrors = validateAccountForm(
      allUsers,
      form,
      mode === 'edit' && user ? user.user_id : null,
    )
    if (Object.keys(nextErrors).length > 0) {
      setErrors(nextErrors)
      return
    }
    onSubmit(form)
  }

  return (
    <div className="account-mgmt__modal-backdrop" onClick={saving ? undefined : onClose}>
      <div
        className="account-mgmt__modal account-mgmt__modal--form account-mgmt__modal--wide"
        role="dialog"
        aria-labelledby={`${mode}-account-title`}
        aria-modal="true"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="account-mgmt__modal-header">
          <div>
            <h2 id={`${mode}-account-title`}>{title}</h2>
            <p className="account-mgmt__modal-subtitle">{subtitle}</p>
          </div>
          <button
            type="button"
            className="account-mgmt__modal-close"
            onClick={onClose}
            disabled={saving}
            aria-label="Close"
          >
            <X size={18} aria-hidden />
          </button>
        </div>

        {protectedAdmin ? (
          <div className="account-mgmt__form-alert account-mgmt__form-alert--info" role="status">
            This is the last active administrator. Role and account status are protected.
          </div>
        ) : null}

        {apiError ? (
          <div className="account-mgmt__form-alert" role="alert">
            {apiError}
          </div>
        ) : null}

        <form className="account-mgmt__form account-mgmt__form--grid" onSubmit={handleSubmit} noValidate>
          <div className={`account-mgmt__field${errors.name ? ' has-error' : ''}`}>
            <label htmlFor={`${mode}-name`}>
              Full Name <span className="account-mgmt__required">*</span>
            </label>
            <input
              id={`${mode}-name`}
              type="text"
              value={form.name}
              onChange={(e) => updateField('name', e.target.value)}
              autoComplete="name"
              placeholder="e.g. Juan Dela Cruz"
              disabled={saving}
            />
            {errors.name ? (
              <span className="account-mgmt__field-error" role="alert">
                {errors.name}
              </span>
            ) : (
              <span className="account-mgmt__field-error" aria-live="polite" />
            )}
          </div>

          <div className={`account-mgmt__field${errors.email ? ' has-error' : ''}`}>
            <label htmlFor={`${mode}-email`}>
              Email Address <span className="account-mgmt__required">*</span>
            </label>
            <input
              id={`${mode}-email`}
              type="email"
              value={form.email}
              onChange={(e) => updateField('email', e.target.value)}
              autoComplete="email"
              placeholder="name@access.edu"
              disabled={saving}
            />
            {errors.email ? (
              <span className="account-mgmt__field-error" role="alert">
                {errors.email}
              </span>
            ) : (
              <span className="account-mgmt__field-error" aria-live="polite" />
            )}
          </div>

          <div className={`account-mgmt__field${errors.role ? ' has-error' : ''}`}>
            <label htmlFor={`${mode}-role`}>
              Role <span className="account-mgmt__required">*</span>
            </label>
            <select
              id={`${mode}-role`}
              value={form.role}
              onChange={(e) => updateField('role', e.target.value as AccountFormValues['role'])}
              disabled={saving || protectedAdmin}
            >
              {ACCOUNT_ROLES.map((r) => (
                <option key={r} value={r}>
                  {accountRoleLabel(r)}
                </option>
              ))}
            </select>
            {errors.role ? (
              <span className="account-mgmt__field-error" role="alert">
                {errors.role}
              </span>
            ) : null}
          </div>

          {!isRequestorRole(form.role) ? (
            <div className={`account-mgmt__field${errors.skillLevel ? ' has-error' : ''}`}>
              <label htmlFor={`${mode}-skill`}>
                Skill Level <span className="account-mgmt__required">*</span>
              </label>
              <select
                id={`${mode}-skill`}
                value={form.skillLevel}
                onChange={(e) => updateField('skillLevel', e.target.value)}
                disabled={saving}
              >
                {SKILL_LEVELS.map((s) => (
                  <option key={s} value={s}>
                    {s}
                  </option>
                ))}
              </select>
              {errors.skillLevel ? (
                <span className="account-mgmt__field-error" role="alert">
                  {errors.skillLevel}
                </span>
              ) : null}
            </div>
          ) : null}

          <div
            className={`account-mgmt__field account-mgmt__field--full${errors.accountStatus ? ' has-error' : ''}`}
          >
            <label htmlFor={`${mode}-status`}>
              Account Status <span className="account-mgmt__required">*</span>
            </label>
            <select
              id={`${mode}-status`}
              value={form.accountStatus}
              onChange={(e) =>
                updateField('accountStatus', e.target.value as AccountFormValues['accountStatus'])
              }
              disabled={saving || protectedAdmin}
            >
              {CREATE_STATUSES.map((s) => (
                <option key={s.value} value={s.value}>
                  {s.label}
                </option>
              ))}
            </select>
            {errors.accountStatus ? (
              <span className="account-mgmt__field-error" role="alert">
                {errors.accountStatus}
              </span>
            ) : null}
            {mode === 'add' ? (
              <p className="account-mgmt__field-hint">
                Active users can sign in immediately. Inactive accounts stay pending. Suspended
                accounts are blocked.
              </p>
            ) : null}
          </div>

          <div className="account-mgmt__modal-footer account-mgmt__field--full">
            <button
              type="button"
              className="account-mgmt__btn account-mgmt__btn--ghost"
              onClick={onClose}
              disabled={saving}
            >
              Cancel
            </button>
            <button type="submit" className="account-mgmt__btn account-mgmt__btn--primary" disabled={saving}>
              {saving ? (
                <>
                  <Loader2 size={16} className="account-mgmt__spin" aria-hidden />
                  {mode === 'add' ? 'Creating…' : 'Saving…'}
                </>
              ) : mode === 'add' ? (
                'Create Account'
              ) : (
                'Save Changes'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
