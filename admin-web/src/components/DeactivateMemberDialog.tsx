import { useEffect, useState } from 'react'
import { Loader2, X } from 'lucide-react'
import { fetchMemberMediaUploadCount } from '../api/admin'

interface Props {
  open: boolean
  memberName: string
  userId: number
  /** When known (e.g. Member Management), skips API count fetch. */
  uploadCount?: number | null
  loading?: boolean
  onConfirm: (deleteUploads: boolean) => void
  onCancel: () => void
}

export function DeactivateMemberDialog({
  open,
  memberName,
  userId,
  uploadCount: uploadCountProp,
  loading = false,
  onConfirm,
  onCancel,
}: Props) {
  const [deleteUploads, setDeleteUploads] = useState(false)
  const [uploadCount, setUploadCount] = useState<number | null>(uploadCountProp ?? null)
  const [countLoading, setCountLoading] = useState(false)

  useEffect(() => {
    if (!open) {
      setDeleteUploads(false)
      return
    }
    if (uploadCountProp != null) {
      setUploadCount(uploadCountProp)
      return
    }
    let cancelled = false
    setCountLoading(true)
    fetchMemberMediaUploadCount(userId)
      .then((n) => {
        if (!cancelled) setUploadCount(n)
      })
      .catch(() => {
        if (!cancelled) setUploadCount(null)
      })
      .finally(() => {
        if (!cancelled) setCountLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [open, userId, uploadCountProp])

  if (!open) return null

  const countLabel =
    uploadCount != null ? `${uploadCount} uploaded file(s) on record.` : null

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
              {memberName} will lose access until you set their account back to approved.
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
          {countLoading ? (
            <p className="text-xs text-[var(--color-text-secondary)]">Loading upload count…</p>
          ) : countLabel ? (
            <p className="text-xs text-[var(--color-text-secondary)]">{countLabel}</p>
          ) : null}
          <label className="flex cursor-pointer items-start gap-2.5 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3">
            <input
              type="checkbox"
              className="mt-0.5"
              checked={deleteUploads}
              disabled={loading}
              onChange={(e) => setDeleteUploads(e.target.checked)}
            />
            <span className="text-sm text-[var(--color-text-primary)]">
              Also permanently delete all photos and videos uploaded by this account
              <span className="mt-1 block text-xs font-normal text-[var(--color-text-secondary)]">
                Removes files from server storage and the media library. This cannot be undone.
              </span>
            </span>
          </label>
        </div>
        <p className="px-5 pb-1 text-xs text-[var(--color-text-secondary)]">
          To permanently delete an account (member or requestor), use Account Management → Actions →
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
            onClick={() => onConfirm(deleteUploads)}
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
