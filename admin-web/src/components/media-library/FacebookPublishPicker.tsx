import { X } from 'lucide-react'
import type { MediaAsset } from '../../lib/mediaLibrary'

interface Props {
  items: MediaAsset[]
  open: boolean
  onClose: () => void
  onPick: (item: MediaAsset) => void
}

export function FacebookPublishPicker({ items, open, onClose, onPick }: Props) {
  if (!open) return null

  const choices = items.slice(0, 30)

  return (
    <>
      <button
        type="button"
        aria-label="Close"
        className="fixed inset-0 z-50 bg-black/40"
        onClick={onClose}
      />
      <div className="fixed left-1/2 top-1/2 z-50 max-h-[80vh] w-full max-w-md -translate-x-1/2 -translate-y-1/2 overflow-hidden rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-xl">
        <div className="flex items-center justify-between border-b border-[var(--color-border)] px-5 py-4">
          <h2 className="text-base font-extrabold text-[var(--color-text-primary)]">Publish to Facebook</h2>
          <button type="button" onClick={onClose} className="rounded-lg p-1 text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)]">
            <X size={18} />
          </button>
        </div>
        <p className="px-5 pt-3 text-xs text-[var(--color-text-secondary)]">
          Select media to open Facebook and publish. Photos work best for the share dialog.
        </p>
        <ul className="max-h-[50vh] overflow-y-auto px-3 pb-4 pt-2">
          {choices.length === 0 ? (
            <li className="px-2 py-6 text-center text-sm text-[var(--color-text-secondary)]">
              No media to publish. Upload photos first.
            </li>
          ) : (
            choices.map((item) => (
              <li key={item.id}>
                <button
                  type="button"
                  onClick={() => {
                    onPick(item)
                    onClose()
                  }}
                  className="flex w-full items-center gap-3 rounded-xl px-2 py-2.5 text-left hover:bg-[var(--color-surface-hover)]"
                >
                  <div className="h-12 w-12 shrink-0 overflow-hidden rounded-lg bg-[var(--color-surface-muted)]">
                    {item.thumbnailUrl && item.isPhoto ? (
                      <img src={item.thumbnailUrl} alt="" className="h-full w-full object-cover" />
                    ) : (
                      <div className="flex h-full items-center justify-center text-[10px] text-[var(--color-text-muted)]">
                        {item.isVideo ? 'Video' : '—'}
                      </div>
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-semibold text-[var(--color-text-primary)]">
                      {item.eventName}
                    </div>
                    <div className="truncate text-xs text-[var(--color-text-secondary)]">{item.fileName}</div>
                  </div>
                </button>
              </li>
            ))
          )}
        </ul>
      </div>
    </>
  )
}
