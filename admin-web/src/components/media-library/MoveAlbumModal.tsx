import { useEffect, useState } from 'react'
import { FolderOpen, Loader2, X } from 'lucide-react'
import type { MediaAlbum } from '../../lib/mediaLibrary'
import { AdminSelect } from '../AdminSelect'

interface Props {
  open: boolean
  albums: MediaAlbum[]
  itemCount: number
  loading?: boolean
  onConfirm: (albumName: string) => void
  onClose: () => void
}

export function MoveAlbumModal({ open, albums, itemCount, loading = false, onConfirm, onClose }: Props) {
  const [albumId, setAlbumId] = useState('')

  useEffect(() => {
    if (open && albums.length > 0) {
      setAlbumId(String(albums[0].id))
    }
  }, [open, albums])

  if (!open) return null

  const selected = albums.find((a) => String(a.id) === albumId)

  return (
    <>
      <button type="button" aria-label="Close" className="fixed inset-0 z-[60] bg-black/40" onClick={loading ? undefined : onClose} />
      <div
        role="dialog"
        aria-modal="true"
        className="fixed left-1/2 top-1/2 z-[70] w-full max-w-md -translate-x-1/2 -translate-y-1/2 overflow-hidden rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-xl"
      >
        <div className="flex items-start justify-between border-b border-[var(--color-border)] px-5 py-4">
          <div className="flex items-start gap-3">
            <div className="rounded-xl bg-[var(--color-accent-primary)]/15 p-2 text-[var(--color-accent-primary)]">
              <FolderOpen size={18} />
            </div>
            <div>
              <h2 className="text-base font-extrabold text-[var(--color-text-primary)]">Move to album</h2>
              <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
                {itemCount === 1 ? 'Choose an album for this item.' : `Choose an album for ${itemCount} selected items.`}
              </p>
            </div>
          </div>
          <button type="button" onClick={onClose} disabled={loading} className="rounded-lg p-1 hover:bg-[var(--color-surface-hover)] disabled:opacity-50">
            <X size={18} />
          </button>
        </div>
        <div className="space-y-4 px-5 py-4">
          <div>
            <label className="mb-1.5 block text-xs font-bold text-[var(--color-text-secondary)]">Album</label>
            <AdminSelect
              value={albumId}
              onChange={setAlbumId}
              options={albums.map((a) => ({
                value: String(a.id),
                label: `${a.name} (${a.totalCount})`,
              }))}
            />
          </div>
        </div>
        <div className="flex gap-2 border-t border-[var(--color-border)] px-5 py-4">
          <button
            type="button"
            onClick={onClose}
            disabled={loading}
            className="flex-1 rounded-xl border border-[var(--color-border)] py-2.5 text-sm font-semibold text-[var(--color-text-secondary)] disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={loading || !selected}
            onClick={() => selected && onConfirm(selected.name)}
            className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[var(--color-accent-primary)] py-2.5 text-sm font-bold text-white disabled:opacity-60"
          >
            {loading ? <Loader2 size={16} className="animate-spin" /> : null}
            Move
          </button>
        </div>
      </div>
    </>
  )
}
