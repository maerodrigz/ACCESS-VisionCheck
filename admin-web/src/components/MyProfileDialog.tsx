import { useEffect, useRef, useState } from 'react'
import { Camera, Loader2, X } from 'lucide-react'

import { profileImageUrl, updateProfile, uploadProfileAvatar } from '../api/profile'
import { AdminAlert } from './AdminAlert'
import { useAuth } from '../context/AuthContext'
import { roleDisplayLabel } from '../lib/roles'
import type { AuthUser } from '../types/auth'
import { MemberAvatar } from './documentation-team/TeamMemberBadges'

const ACCEPT = 'image/jpeg,image/png,image/webp'

interface Props {
  open: boolean
  user: AuthUser
  onClose: () => void
}

export function MyProfileDialog({ open, user, onClose }: Props) {
  const { updateUser } = useAuth()
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [uploading, setUploading] = useState(false)
  const [savingName, setSavingName] = useState(false)
  const [name, setName] = useState(user.name)
  const [email, setEmail] = useState(user.email)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setName(user.name)
    setEmail(user.email)
    setError(null)
    setSuccess(null)
  }, [open, user.name, user.email])

  if (!open) return null

  const role = roleDisplayLabel(user.role)
  const nameDirty = name.trim() !== user.name.trim()
  const emailDirty = email.trim().toLowerCase() !== user.email.trim().toLowerCase()

  function handleClose() {
    setError(null)
    setSuccess(null)
    setName(user.name)
    setEmail(user.email)
    onClose()
  }

  async function handleSaveName() {
    const trimmed = name.trim()
    const trimmedEmail = email.trim()
    if (!trimmed) {
      setError('Name cannot be empty.')
      return
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
      setError('Enter a valid email address.')
      return
    }
    if (!nameDirty && !emailDirty) return

    setError(null)
    setSuccess(null)
    setSavingName(true)
    try {
      const profile = await updateProfile({
        ...(nameDirty ? { name: trimmed } : {}),
        ...(emailDirty ? { email: trimmedEmail } : {}),
      })
      updateUser({
        name: profile.name,
        email: profile.email,
        profileImage: profileImageUrl(profile),
      })
      setName(profile.name)
      setEmail(profile.email)
      setSuccess('Profile updated.')
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Could not update profile.'
      setError(/already in use/i.test(message) ? 'This email is already registered.' : message)
    } finally {
      setSavingName(false)
    }
  }

  async function handleFileChange(file: File | null) {
    if (!file) return
    setError(null)
    setSuccess(null)

    const allowed = ['image/jpeg', 'image/png', 'image/webp']
    if (!allowed.includes(file.type)) {
      setError('Use JPG, PNG, or WEBP.')
      return
    }
    if (file.size > 10 * 1024 * 1024) {
      setError('Image must be 10 MB or smaller.')
      return
    }

    setUploading(true)
    try {
      const profile = await uploadProfileAvatar(file)
      updateUser({
        name: profile.name,
        email: profile.email,
        profileImage: profileImageUrl(profile),
      })
      setSuccess('Profile photo updated.')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not upload photo.')
    } finally {
      setUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  return (
    <div
      className="pd-modal-overlay is-visible"
      role="dialog"
      aria-modal="true"
      aria-labelledby="my-profile-title"
      onClick={(e) => {
        if (e.target === e.currentTarget) handleClose()
      }}
    >
      <div className="pd-modal pd-modal--wide" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 id="my-profile-title" className="pd-modal__title">
              My Profile
            </h2>
            <p className="pd-modal__message mt-1">Update your profile photo, display name, and email.</p>
          </div>
          <button
            type="button"
            onClick={handleClose}
            className="rounded-lg p-2 hover:bg-[var(--color-surface-hover)]"
            aria-label="Close"
          >
            <X size={20} />
          </button>
        </div>

        <div className="mt-5 flex flex-col items-center text-center">
          <div className="relative">
            <MemberAvatar
              name={user.name}
              avatarUrl={user.profileImage}
              size="lg"
              fallbackClassName="profile-dropdown__avatar profile-dropdown__avatar--lg !flex !h-20 !w-20 !text-2xl"
            />
            <button
              type="button"
              className="absolute -bottom-1 -right-1 flex h-9 w-9 items-center justify-center rounded-full border border-[var(--pd-border)] bg-[var(--pd-accent)] text-white shadow-md transition hover:bg-[#2563eb] disabled:opacity-60"
              onClick={() => fileInputRef.current?.click()}
              disabled={uploading}
              aria-label="Upload profile photo"
            >
              {uploading ? <Loader2 size={16} className="animate-spin" /> : <Camera size={16} />}
            </button>
          </div>
          <input
            ref={fileInputRef}
            type="file"
            accept={ACCEPT}
            className="hidden"
            onChange={(e) => void handleFileChange(e.target.files?.[0] ?? null)}
          />
          <button
            type="button"
            className="mt-3 text-sm font-semibold text-[var(--pd-accent)] hover:underline disabled:opacity-60"
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
          >
            {uploading ? 'Uploading…' : user.profileImage ? 'Change photo' : 'Upload photo'}
          </button>
        </div>

        <div className="mt-6 space-y-3 border-t border-[var(--pd-border)] pt-4">
          <div className="space-y-1.5">
            <label htmlFor="my-profile-name" className="pd-modal__detail-label block">
              Name
            </label>
            <input
              id="my-profile-name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={120}
              className="admin-input w-full rounded-xl px-3 py-2 text-sm"
              autoComplete="name"
            />
          </div>
          <div className="space-y-1.5">
            <label htmlFor="my-profile-email" className="pd-modal__detail-label block">
              Email
            </label>
            <input
              id="my-profile-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              maxLength={255}
              className="admin-input w-full rounded-xl px-3 py-2 text-sm"
              autoComplete="email"
            />
          </div>
          <div className="flex justify-end">
            <button
              type="button"
              className="pd-modal__btn pd-modal__btn--primary shrink-0 disabled:opacity-50"
              onClick={() => void handleSaveName()}
              disabled={(!nameDirty && !emailDirty) || savingName}
            >
              {savingName ? 'Saving…' : 'Save changes'}
            </button>
          </div>
          <div className="pd-modal__detail-row">
            <span className="pd-modal__detail-label">Role</span>
            <span className="pd-modal__detail-value">{role}</span>
          </div>
        </div>

        {error ? (
          <AdminAlert tone="error" className="mt-4">
            {error}
          </AdminAlert>
        ) : null}
        {success ? (
          <AdminAlert tone="success" className="mt-4">
            {success}
          </AdminAlert>
        ) : null}

        <div className="pd-modal__actions mt-5">
          <button type="button" className="pd-modal__btn pd-modal__btn--primary" onClick={handleClose}>
            Close
          </button>
        </div>
      </div>
    </div>
  )
}
