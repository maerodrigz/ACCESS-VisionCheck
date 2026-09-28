import { useState, type FormEvent } from 'react'
import { Loader2, X } from 'lucide-react'
import { changePassword } from '../api/profile'
import { AdminAlert } from './AdminAlert'
import { PasswordInput } from './PasswordInput'

interface Props {
  open: boolean
  onClose: () => void
  onSuccess?: () => void
}

export function ChangePasswordDialog({ open, onClose, onSuccess }: Props) {
  const [currentPassword, setCurrentPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  if (!open) return null

  function resetForm() {
    setCurrentPassword('')
    setNewPassword('')
    setConfirmPassword('')
    setError(null)
    setSuccess(null)
  }

  function handleClose() {
    resetForm()
    onClose()
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setSuccess(null)

    if (!currentPassword || !newPassword || !confirmPassword) {
      setError('Please fill in all fields.')
      return
    }
    if (newPassword.length < 6) {
      setError('New password must be at least 6 characters.')
      return
    }
    if (newPassword !== confirmPassword) {
      setError('New password and confirmation do not match.')
      return
    }
    if (newPassword === currentPassword) {
      setError('New password must be different from your current password.')
      return
    }

    setSaving(true)
    try {
      await changePassword({
        current_password: currentPassword,
        new_password: newPassword,
      })
      setSuccess('Password changed successfully.')
      onSuccess?.()
      resetForm()
      window.setTimeout(handleClose, 1200)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not change password.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div
      className="pd-modal-overlay is-visible"
      role="dialog"
      aria-modal="true"
      aria-labelledby="change-password-title"
      onClick={(e) => {
        if (e.target === e.currentTarget) handleClose()
      }}
    >
      <div className="pd-modal pd-modal--wide" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 id="change-password-title" className="pd-modal__title">
              Change password
            </h2>
            <p className="pd-modal__message mt-1">
              Use your current password, then choose a new one (at least 6 characters).
            </p>
          </div>
          <button type="button" onClick={handleClose} className="rounded-lg p-2 hover:bg-[var(--color-surface-hover)]" aria-label="Close">
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="mt-4 space-y-3">
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Current password
            <div className="mt-1">
              <PasswordInput
                value={currentPassword}
                onChange={setCurrentPassword}
                autoComplete="current-password"
                disabled={saving}
              />
            </div>
          </label>
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            New password
            <div className="mt-1">
              <PasswordInput
                value={newPassword}
                onChange={setNewPassword}
                autoComplete="new-password"
                disabled={saving}
              />
            </div>
          </label>
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Confirm new password
            <div className="mt-1">
              <PasswordInput
                value={confirmPassword}
                onChange={setConfirmPassword}
                autoComplete="new-password"
                disabled={saving}
              />
            </div>
          </label>

          {error ? <AdminAlert tone="error">{error}</AdminAlert> : null}
          {success ? <AdminAlert tone="success">{success}</AdminAlert> : null}

          <div className="pd-modal__actions pt-2">
            <button type="button" className="pd-modal__btn pd-modal__btn--cancel" onClick={handleClose} disabled={saving}>
              Cancel
            </button>
            <button type="submit" className="pd-modal__btn pd-modal__btn--primary" disabled={saving}>
              {saving ? (
                <span className="inline-flex items-center gap-2">
                  <Loader2 size={16} className="animate-spin" />
                  Saving…
                </span>
              ) : (
                'Update password'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
