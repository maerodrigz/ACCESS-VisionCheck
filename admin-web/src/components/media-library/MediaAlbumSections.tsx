import { Archive, ChevronDown, ChevronUp, FolderOpen, Loader2, MoreHorizontal, Sparkles, Star, Trash2 } from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { AdminCard } from '../AdminCard'
import type { MediaAlbum, MediaAsset } from '../../lib/mediaLibrary'
import { formatMediaDate } from '../../lib/mediaLibrary'
import { MediaPreviewContent } from './MediaPreviewContent'
import { MEDIA_GALLERY_GRID_CLASS } from './MediaTileGrid'
import { MediaTile } from './MediaTile'

function AlbumCoverImage({ url, alt }: { url?: string; alt: string }) {
  const [failed, setFailed] = useState(false)
  if (!url || failed) {
    return (
      <MediaPreviewContent url="" isVideo={false} mode="thumbnail" className="h-full w-full" />
    )
  }
  return (
    <img
      src={url}
      alt={alt}
      loading="lazy"
      decoding="async"
      className="h-full w-full object-cover"
      onError={() => setFailed(true)}
    />
  )
}

interface AlbumsProps {
  albums: MediaAlbum[]
  selectedAlbumId: string | null
  isAdmin?: boolean
  onAlbumTap: (album: MediaAlbum) => void
  onClearAlbum: () => void
  onDeleteAlbum?: (album: MediaAlbum) => void
  onArchiveAlbum?: (album: MediaAlbum) => void
}

function AlbumOptionsMenu({
  album,
  onDelete,
  onArchive,
}: {
  album: MediaAlbum
  onDelete?: (album: MediaAlbum) => void
  onArchive?: (album: MediaAlbum) => void
}) {
  const [open, setOpen] = useState(false)
  const rootRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    function onPointerDown(event: MouseEvent) {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', onPointerDown)
    return () => document.removeEventListener('mousedown', onPointerDown)
  }, [open])

  return (
    <div ref={rootRef} className="absolute right-1.5 top-1.5 z-20">
      <button
        type="button"
        aria-label={`Options for ${album.name}`}
        aria-expanded={open}
        onClick={(event) => {
          event.stopPropagation()
          setOpen((value) => !value)
        }}
        className="flex h-7 w-7 items-center justify-center rounded-md bg-black/55 text-white shadow-sm hover:bg-black/75"
      >
        <MoreHorizontal size={16} />
      </button>
      {open ? (
        <div
          role="menu"
          className="absolute right-0 top-8 w-40 overflow-hidden rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] py-1 shadow-lg"
        >
          <button
            type="button"
            role="menuitem"
            onClick={(event) => {
              event.stopPropagation()
              setOpen(false)
              onArchive?.(album)
            }}
            className="flex w-full items-center gap-2 px-3 py-1.5 text-left text-xs font-semibold text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]"
          >
            <Archive size={13} />
            Archive album
          </button>
          <button
            type="button"
            role="menuitem"
            onClick={(event) => {
              event.stopPropagation()
              setOpen(false)
              onDelete?.(album)
            }}
            className="flex w-full items-center gap-2 px-3 py-1.5 text-left text-xs font-semibold text-red-600 hover:bg-[var(--color-surface-hover)]"
          >
            <Trash2 size={13} />
            Delete album
          </button>
        </div>
      ) : null}
    </div>
  )
}

export function EventAlbumsSection({
  albums,
  selectedAlbumId,
  isAdmin = false,
  onAlbumTap,
  onClearAlbum,
  onDeleteAlbum,
  onArchiveAlbum,
}: AlbumsProps) {
  if (albums.length === 0) return null

  return (
    <AdminCard padding="none" className="overflow-hidden border-[var(--color-border)] bg-transparent shadow-none">
      <div className="border-b border-[var(--color-border)] px-4 py-3">
        <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <FolderOpen size={16} className="text-[var(--color-accent-blue)]" />
          <h2 className="text-sm font-bold text-[var(--color-text-primary)]">
            Event albums <span className="font-semibold text-[var(--color-text-secondary)]">({albums.length})</span>
          </h2>
        </div>
        {selectedAlbumId && (
          <button
            type="button"
            onClick={onClearAlbum}
            className="text-xs font-semibold text-[var(--color-accent-blue)] hover:underline"
          >
            Clear album filter
          </button>
        )}
        </div>
      </div>
      <div className="px-4 pb-3 pt-3">
        <div className="grid grid-cols-[repeat(auto-fill,minmax(168px,1fr))] gap-3">
          {albums.map((album) => {
            const selected = selectedAlbumId === album.id
            return (
              <div key={album.id} className="relative">
                <button
                  type="button"
                  onClick={() => onAlbumTap(album)}
                  className={[
                    'flex h-full w-full flex-col overflow-hidden rounded-xl border bg-[var(--color-surface)] text-left shadow-[0_1px_3px_rgba(15,39,68,0.06)] transition',
                    selected
                      ? 'border-[var(--color-accent-blue)] ring-2 ring-[var(--color-accent-blue)]/20'
                      : 'border-[var(--color-border)] hover:border-[var(--color-accent-cyan)]/40 hover:shadow-[0_4px_12px_rgba(15,39,68,0.08)]',
                  ].join(' ')}
                >
                  <div className="relative aspect-[4/3] w-full shrink-0 overflow-hidden bg-[var(--color-surface-muted)]">
                    <AlbumCoverImage url={album.coverUrl} alt={album.name} />
                    <span className="absolute bottom-2 right-2 rounded-md bg-black/60 px-2 py-0.5 text-[10px] font-bold text-white">
                      {album.totalCount}
                    </span>
                  </div>
                  <div className="flex flex-col p-2">
                    <div className="line-clamp-2 text-xs font-bold leading-snug text-[var(--color-text-primary)]">
                      {album.name}
                    </div>
                    <div className="mt-1 text-[10px] text-[var(--color-text-secondary)]">
                      {album.photoCount} photos · {album.videoCount} videos
                    </div>
                    {album.date ? (
                      <div className="mt-0.5 text-[10px] text-[var(--color-text-secondary)]">
                        {formatMediaDate(album.date)}
                      </div>
                    ) : null}
                  </div>
                </button>
                {isAdmin ? (
                  <AlbumOptionsMenu album={album} onDelete={onDeleteAlbum} onArchive={onArchiveAlbum} />
                ) : null}
              </div>
            )
          })}
        </div>
      </div>
    </AdminCard>
  )
}

export function BestPicksSection({
  items,
  isAdmin,
  onPreview,
  onToggleBestShot,
  onPublishAll,
  publishReadyCount,
  facebookReady,
  facebookGraphReady = false,
}: {
  items: MediaAsset[]
  isAdmin: boolean
  onPreview: (item: MediaAsset) => void
  onToggleBestShot: (item: MediaAsset) => void
  onPublishAll?: () => void
  publishReadyCount: number
  facebookReady: boolean
  facebookGraphReady?: boolean
}) {
  return (
    <div className="rounded-[var(--card-radius)] border border-amber-500/20 bg-gradient-to-br from-amber-500/5 to-[var(--color-surface)]">
      <div className="border-b border-amber-500/15 px-3 py-2">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <Star size={15} className="fill-amber-400 text-amber-500" />
              <h2 className="text-sm font-bold text-[var(--color-text-primary)]">Best picks</h2>
              <span className="text-[10px] font-bold text-amber-600">({items.length})</span>
            </div>
          </div>
          {isAdmin && onPublishAll && (
            <button
              type="button"
              disabled={
                items.length === 0 ||
                !facebookReady ||
                publishReadyCount === 0 ||
                (!facebookGraphReady && publishReadyCount > 1)
              }
              title={
                !facebookReady
                  ? 'Facebook publishing disabled'
                  : items.length === 0
                    ? 'Add best picks with the star icon'
                    : !facebookGraphReady && publishReadyCount > 1
                      ? 'Add Page token for bulk publish, or star and publish one item'
                      : undefined
              }
              onClick={onPublishAll}
              className="inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg bg-[#1877F2] px-2.5 text-xs font-bold text-white hover:opacity-95 disabled:opacity-50"
            >
              Publish Best Picks{publishReadyCount > 0 ? ` (${publishReadyCount})` : ''}
            </button>
          )}
        </div>
      </div>

      <div className="px-3 py-2">
        {items.length === 0 ? (
          <div className="flex items-center gap-2 rounded-lg border border-dashed border-amber-500/25 bg-amber-500/5 px-3 py-2">
            <Sparkles size={14} className="shrink-0 text-amber-500" />
            <p className="text-xs text-[var(--color-text-secondary)]">
              No best picks yet. Use the star on a photo or video below.
            </p>
          </div>
        ) : (
          <div className="flex gap-2 overflow-x-auto pb-1">
            {items.map((item) => (
              <article
                key={item.id}
                className="group relative w-[148px] shrink-0 overflow-hidden rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]"
              >
                <button
                  type="button"
                  onClick={() => onPreview(item)}
                  className="relative block aspect-[4/3] w-full overflow-hidden bg-[var(--color-surface-muted)]"
                >
                  <MediaPreviewContent
                    url={item.thumbnailUrl}
                    isVideo={item.isVideo}
                    fileName={item.fileName}
                    mode="thumbnail"
                    className="h-full w-full"
                  />
                  {item.isVideo ? (
                    <span className="absolute left-1.5 top-1.5 rounded bg-black/50 px-1.5 py-0.5 text-[9px] font-semibold uppercase tracking-wide text-white/95">
                      Video
                    </span>
                  ) : null}
                </button>
                {isAdmin ? (
                  <button
                    type="button"
                    onClick={() => onToggleBestShot(item)}
                    className="absolute right-1.5 top-1.5 rounded-md bg-black/70 px-1.5 py-0.5 text-[10px] font-semibold text-white opacity-0 transition group-hover:opacity-100 group-focus-within:opacity-100"
                  >
                    Remove
                  </button>
                ) : null}
                <div className="border-t border-[var(--color-border)] px-2 py-1.5">
                  <p className="truncate text-[11px] font-semibold text-[var(--color-text-primary)]" title={item.fileName}>
                    {item.fileName}
                  </p>
                  {item.uploadDateLabel ? (
                    <p className="truncate text-[10px] text-[var(--color-text-secondary)]">{item.uploadDateLabel}</p>
                  ) : null}
                </div>
              </article>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

/** @deprecated use BestPicksSection */
export const BestShotsRow = BestPicksSection

export function MediaWorkflowSteps() {
  const steps = [
    { n: '1', title: 'Upload', desc: 'Add event photos and videos — they appear in the gallery immediately.' },
    { n: '2', title: 'Best pick', desc: 'Star your favorites to mark them for Facebook publishing.' },
    { n: '3', title: 'Publish', desc: 'Select best picks and bulk publish to your Facebook page.' },
  ]
  return (
    <div className="grid gap-3 sm:grid-cols-3">
      {steps.map((s) => (
        <div
          key={s.n}
          className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-4 py-3 shadow-[0_2px_8px_rgba(15,39,68,0.03)]"
        >
          <span className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-[var(--color-accent-blue)]/15 text-xs font-extrabold text-[var(--color-accent-blue)]">
            {s.n}
          </span>
          <p className="mt-2 text-sm font-bold text-[var(--color-text-primary)]">{s.title}</p>
          <p className="mt-0.5 text-xs leading-relaxed text-[var(--color-text-secondary)]">{s.desc}</p>
        </div>
      ))}
    </div>
  )
}

export function MediaBulkToolbar({
  count,
  publishableCount = 0,
  isAdmin,
  facebookReady = true,
  facebookGraphReady = false,
  facebookReminder,
  showFacebook = true,
  onClear,
  onDownload,
  onMove,
  onArchive,
  onDelete,
  onPublish,
  onMarkBestPick,
  publishing,
  uploading = false,
}: {
  count: number
  publishableCount?: number
  isAdmin: boolean
  facebookReady?: boolean
  facebookGraphReady?: boolean
  facebookReminder?: string
  showFacebook?: boolean
  onClear: () => void
  onDownload: () => void
  onMove: () => void
  onArchive: () => void
  onDelete: () => void
  onPublish?: () => void
  onMarkBestPick?: () => void
  publishing?: boolean
  uploading?: boolean
}) {
  if (count === 0) return null
  const busy = publishing || uploading

  return (
    <div className="fixed bottom-6 left-1/2 z-30 flex max-w-[calc(100vw-2rem)] -translate-x-1/2 flex-wrap items-center gap-2 rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] px-4 py-3 shadow-xl">
      <span className="mr-1 text-sm font-bold text-[var(--color-text-primary)]">{count} selected</span>
      {busy ? (
        <span className="inline-flex items-center gap-1.5 rounded-lg bg-[var(--color-surface-muted)] px-3 py-1.5 text-xs font-semibold text-[var(--color-text-secondary)]">
          <Loader2 size={12} className="animate-spin" />
          {publishing ? 'Publishing…' : 'Uploading…'}
        </span>
      ) : null}
      {isAdmin && onMarkBestPick && (
        <button
          type="button"
          disabled={busy}
          onClick={onMarkBestPick}
          className="inline-flex items-center gap-1 rounded-lg border border-amber-500/30 bg-amber-500/10 px-3 py-1.5 text-xs font-semibold text-amber-200 hover:bg-amber-500/20"
        >
          <Star size={12} className="fill-amber-400 text-amber-400" />
          Mark best pick
        </button>
      )}
      <button
        type="button"
        disabled={busy}
        onClick={onDownload}
        className="rounded-lg bg-[var(--color-surface-muted)] px-3 py-1.5 text-xs font-semibold hover:bg-slate-200 disabled:opacity-50"
      >
        Download
      </button>
      {isAdmin && (
        <>
          {showFacebook && onPublish && (
            <button
              type="button"
              disabled={busy || !facebookReady || publishableCount === 0}
              title={
                !facebookReady
                  ? facebookReminder
                  : publishableCount === 0
                    ? 'Mark selected as best picks first'
                    : !facebookGraphReady && publishableCount > 1
                      ? 'Add Page token for bulk, or select one item for browser share'
                      : undefined
              }
              onClick={onPublish}
              className="inline-flex items-center gap-1.5 rounded-lg bg-[#1877F2] px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-50"
            >
              {publishing ? <Loader2 size={12} className="animate-spin" /> : null}
              {publishing ? 'Publishing…' : `Publish${publishableCount > 0 ? ` (${publishableCount})` : ''}`}
            </button>
          )}
          <button
            type="button"
            disabled={busy}
            onClick={onMove}
            className="rounded-lg bg-[var(--color-surface-muted)] px-3 py-1.5 text-xs font-semibold hover:bg-slate-200 disabled:opacity-50"
          >
            Move
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={onArchive}
            className="rounded-lg bg-[var(--color-surface-muted)] px-3 py-1.5 text-xs font-semibold hover:bg-slate-200 disabled:opacity-50"
          >
            Archive
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={onDelete}
            className="rounded-lg border border-red-500/30 bg-red-500/10 px-3 py-1.5 text-xs font-semibold text-red-300 hover:bg-red-500/20 disabled:opacity-50"
          >
            Delete
          </button>
        </>
      )}
      <button type="button" onClick={onClear} className="rounded-lg px-3 py-1.5 text-xs font-semibold text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]">
        Clear
      </button>
    </div>
  )
}

export function FacebookHistoryCollapsible({
  items,
  failedHistory = [],
  onPreview,
}: {
  items: MediaAsset[]
  failedHistory?: {
    id: number
    file_name: string
    event_title: string | null
    status: string
    error_message: string | null
    facebook_published_at: string | null
    created_at: string | null
  }[]
  onPreview: (item: MediaAsset) => void
}) {
  const [open, setOpen] = useState(false)
  const publishedPhotos = useMemo(() => items.filter((a) => a.isPhoto), [items])
  const publishedVideos = useMemo(() => items.filter((a) => a.isVideo), [items])

  if (items.length === 0 && failedHistory.length === 0) return null

  return (
    <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2 shadow-[0_1px_2px_rgba(15,39,68,0.04)]">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="flex w-full items-center justify-between gap-2 text-left"
      >
        <h2 className="text-sm font-bold text-[var(--color-text-primary)]">Publishing history</h2>
        <span className="flex items-center gap-1 text-xs font-semibold text-[var(--color-text-secondary)]">
          {items.length} published
          {open ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
        </span>
      </button>
      {open && (
        <div className="mt-3 space-y-4">
          {items.length === 0 ? (
            <p className="text-sm text-[var(--color-text-secondary)]">No published media yet.</p>
          ) : (
            <>
              {publishedPhotos.length > 0 && (
                <section>
                  <h3 className="mb-2 text-sm font-bold text-[var(--color-text-primary)]">
                    Photos ({publishedPhotos.length})
                  </h3>
                  <div className={MEDIA_GALLERY_GRID_CLASS}>
                    {publishedPhotos.map((item) => (
                      <MediaTile
                        key={item.id}
                        item={item}
                        selected={false}
                        isAdmin={false}
                        onTap={() => onPreview(item)}
                        onSelectToggle={() => {}}
                        onToggleBestShot={() => {}}
                      />
                    ))}
                  </div>
                </section>
              )}
              {publishedVideos.length > 0 && (
                <section>
                  <h3 className="mb-2 text-sm font-bold text-[var(--color-text-primary)]">
                    Videos ({publishedVideos.length})
                  </h3>
                  <div className={MEDIA_GALLERY_GRID_CLASS}>
                    {publishedVideos.map((item) => (
                      <MediaTile
                        key={item.id}
                        item={item}
                        selected={false}
                        isAdmin={false}
                        onTap={() => onPreview(item)}
                        onSelectToggle={() => {}}
                        onToggleBestShot={() => {}}
                      />
                    ))}
                  </div>
                </section>
              )}
            </>
          )}

          {failedHistory.length > 0 && (
            <section>
              <h3 className="mb-2 text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                Failed attempts
              </h3>
              <div className="overflow-x-auto">
                <table className="w-full min-w-[480px] text-left text-xs">
                  <thead>
                    <tr className="border-b border-[var(--color-border)] text-[var(--color-text-secondary)]">
                      <th className="py-2 pr-3 font-semibold">File</th>
                      <th className="py-2 pr-3 font-semibold">Event</th>
                      <th className="py-2 pr-3 font-semibold">Error</th>
                      <th className="py-2 pr-3 font-semibold">When</th>
                    </tr>
                  </thead>
                  <tbody>
                    {failedHistory.slice(0, 10).map((row) => (
                      <tr key={row.id} className="border-b border-[var(--color-border)]/60">
                        <td className="py-2 pr-3 font-semibold text-[var(--color-text-primary)]">{row.file_name}</td>
                        <td className="py-2 pr-3 text-[var(--color-text-secondary)]">{row.event_title ?? 'N/A'}</td>
                        <td className="max-w-[220px] py-2 pr-3 text-[var(--color-danger)]">
                          {row.error_message
                            ? row.error_message.length > 80
                              ? `${row.error_message.slice(0, 80)}…`
                              : row.error_message
                            : 'N/A'}
                        </td>
                        <td className="py-2 pr-3 text-[var(--color-text-secondary)]">
                          {row.created_at ? new Date(row.created_at).toLocaleString() : 'N/A'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          )}
        </div>
      )}
    </div>
  )
}
