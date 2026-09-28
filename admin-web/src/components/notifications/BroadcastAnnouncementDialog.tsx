import { useState } from 'react'
import { Loader2, Megaphone, X } from 'lucide-react'
import { broadcastNotification } from '../../api/adminIntegrations'
import { AdminErrorBanner } from '../AdminAlert'

interface Props {
  open: boolean
  onClose: () => void
  onSent: () => void
}

const AUDIENCE_OPTIONS = [
  { value: 'all', label: 'All approved users' },
  { value: 'member', label: 'Members only' },
  { value: 'organization', label: 'Organizations only' },
  { value: 'admin', label: 'Administrators only' },
] as const

export function BroadcastAnnouncementDialog({ open, onClose, onSent }: Props) {
  const [title, setTitle] = useState('')
  const [message, setMessage] = useState('')
  const [audience, setAudience] = useState<(typeof AUDIENCE_OPTIONS)[number]['value']>('all')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  if (!open) return null

  async function handleSend() {
    if (title.trim().length < 1 || message.trim().length < 1) return
    setBusy(true)
    setError(null)
    try {
      await broadcastNotification({
        title: title.trim(),
        message: message.trim(),
        audience,
      })
      setTitle('')
      setMessage('')
      setAudience('all')
      onSent()
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Broadcast failed')
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <button
        type="button"
        aria-label="Close broadcast dialog"
        className="fixed inset-0 z-[60] bg-black/40"
        onClick={busy ? undefined : onClose}
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="broadcast-dialog-title"
        className="fixed left-1/2 top-1/2 z-[70] w-full max-w-lg -translate-x-1/2 -translate-y-1/2 overflow-hidden rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-xl"
      >
        <div className="flex items-start justify-between border-b border-[var(--color-border)] px-5 py-4">
          <div className="flex items-start gap-3">
            <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--color-accent-blue)]/15 text-[var(--color-accent-blue)]">
              <Megaphone size={20} />
            </span>
            <div>
              <h2 id="broadcast-dialog-title" className="text-base font-extrabold text-[var(--color-text-primary)]">
                Broadcast announcement
              </h2>
              <p className="mt-0.5 text-xs text-[var(--color-text-secondary)]">
                Sends an in-app notification when announcements are enabled in System Configuration.
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            disabled={busy}
            aria-label="Close"
            className="rounded-lg p-1 text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] disabled:opacity-50"
          >
            <X size={20} />
          </button>
        </div>

        <div className="space-y-3 px-5 py-4">
          {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

          <div>
            <label htmlFor="broadcast-audience" className="text-xs font-bold text-[var(--color-text-primary)]">
              Audience
            </label>
            <select
              id="broadcast-audience"
              value={audience}
              onChange={(e) => setAudience(e.target.value as typeof audience)}
              className="admin-input mt-1 w-full rounded-xl px-3 py-2 text-sm"
            >
              {AUDIENCE_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label htmlFor="broadcast-title" className="text-xs font-bold text-[var(--color-text-primary)]">
              Title
            </label>
            <input
              id="broadcast-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={200}
              className="admin-input mt-1 w-full rounded-xl px-3 py-2 text-sm"
              placeholder="Platform maintenance tonight"
            />
          </div>

          <div>
            <label htmlFor="broadcast-message" className="text-xs font-bold text-[var(--color-text-primary)]">
              Message
            </label>
            <textarea
              id="broadcast-message"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              rows={4}
              className="admin-input mt-1 w-full rounded-xl px-3 py-2 text-sm"
              placeholder="Share details members and organizations should know…"
            />
          </div>
        </div>

        <div className="flex justify-end gap-2 border-t border-[var(--color-border)] px-5 py-4">
          <button
            type="button"
            disabled={busy}
            onClick={onClose}
            className="rounded-xl border border-[var(--color-border)] px-4 py-2 text-sm font-semibold disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={busy || title.trim().length < 1 || message.trim().length < 1}
            onClick={() => void handleSend()}
            className="inline-flex items-center gap-2 rounded-xl bg-[var(--color-accent-blue)] px-4 py-2 text-sm font-bold text-white disabled:opacity-50"
          >
            {busy ? <Loader2 size={16} className="animate-spin" /> : <Megaphone size={16} />}
            Send broadcast
          </button>
        </div>
      </div>
    </>
  )
}
