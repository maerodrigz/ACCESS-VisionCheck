import { useState } from 'react'
import { Loader2, X } from 'lucide-react'
import type { MediaAsset } from '../../lib/mediaLibrary'
import { canPublishToFacebook } from '../../lib/mediaLibrary'
import { MediaPreviewContent } from './MediaPreviewContent'

interface Props {
  items: MediaAsset[]
  open: boolean
  publishing: boolean
  useGraphApi: boolean
  onClose: () => void
  onConfirm: (message: string) => void
}

export function FacebookPublishModal({ items, open, publishing, useGraphApi, onClose, onConfirm }: Props) {
  const [message, setMessage] = useState('')
  const publishable = items.filter(canPublishToFacebook)

  if (!open) return null

  return (
    <>
      <button
        type="button"
        aria-label="Close"
        className="fixed inset-0 z-50 bg-black/40"
        onClick={() => !publishing && onClose()}
      />
      <div className="fixed left-1/2 top-1/2 z-50 flex max-h-[90vh] w-full max-w-lg -translate-x-1/2 -translate-y-1/2 flex-col overflow-hidden rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-xl">
        <div className="flex items-center justify-between border-b border-[var(--color-border)] px-5 py-4">
          <div>
            <h2 className="text-base font-extrabold text-[var(--color-text-primary)]">Publish to Facebook</h2>
            <p className="mt-0.5 text-xs text-[var(--color-text-secondary)]">
              {publishing
                ? 'Please wait while we post to your Facebook Page…'
                : useGraphApi
                  ? publishable.length > 1
                    ? 'Graph API · one swipeable grid on the Page feed (10 photos max per post)'
                    : 'Graph API · posts directly to your Page'
                  : 'Browser share · opens Facebook for one item (no Page token)'}
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            disabled={publishing}
            className="rounded-lg p-1 text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] disabled:opacity-40"
          >
            <X size={18} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-4">
          {publishing ? (
            <div className="flex flex-col items-center justify-center gap-3 py-10 text-center">
              <Loader2 size={32} className="animate-spin text-[#1877F2]" />
              <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                Publishing {publishable.length} item(s) to Facebook…
              </p>
              <p className="max-w-xs text-xs text-[var(--color-text-secondary)]">
                Large batches may take a minute. Do not close this window.
              </p>
            </div>
          ) : publishable.length === 0 ? (
            <p className="text-sm text-[var(--color-text-secondary)]">
              No best picks selected. Mark event media as best picks first — member evaluation media cannot be
              published.
            </p>
          ) : (
            <>
              <p className="text-xs font-semibold text-[var(--color-text-primary)]">
                {publishable.length} file(s) ready to publish
              </p>
              <ul className="mt-3 grid max-h-48 grid-cols-3 gap-2 overflow-y-auto">
                {publishable.map((item) => (
                  <li key={item.id} className="overflow-hidden rounded-lg border border-[var(--color-border)]">
                    <MediaPreviewContent
                      url={item.thumbnailUrl}
                      isVideo={item.isVideo}
                      fileName={item.fileName}
                      mode="thumbnail"
                      className="aspect-square w-full"
                    />
                    <div className="truncate px-1.5 py-1 text-[9px] font-semibold">{item.fileName}</div>
                  </li>
                ))}
              </ul>
              <label className="mt-4 block text-xs font-semibold text-[var(--color-text-secondary)]">
                Caption (optional)
                <textarea
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  rows={3}
                  placeholder="e.g. #USTP Assembly 2026 — highlights from ACCESS documentation"
                  className="mt-1.5 w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2 text-sm outline-none focus:border-cyan-400"
                />
                <span className="mt-1 block text-[10px] font-normal text-[var(--color-text-secondary)]">
                  Leave blank to use the event title only. UUID filenames are not added. Bulk
                  publish creates one swipeable photo grid on your Page feed (like the native
                  Facebook app). More than 10 photos become multiple grid posts.
                </span>
              </label>
            </>
          )}
        </div>

        <div className="flex gap-2 border-t border-[var(--color-border)] px-5 py-4">
          <button
            type="button"
            onClick={onClose}
            disabled={publishing}
            className="flex-1 rounded-xl border border-[var(--color-border)] py-2.5 text-sm font-semibold text-[var(--color-text-secondary)]"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={publishing || publishable.length === 0}
            onClick={() => onConfirm(message.trim())}
            className="inline-flex flex-1 items-center justify-center gap-2 rounded-xl bg-[#1877F2] py-2.5 text-sm font-bold text-white disabled:opacity-50"
          >
            {publishing ? <Loader2 size={16} className="animate-spin" /> : null}
            {publishing ? 'Publishing…' : useGraphApi ? `Publish ${publishable.length} item(s)` : 'Open in Facebook'}
          </button>
        </div>
      </div>
    </>
  )
}
