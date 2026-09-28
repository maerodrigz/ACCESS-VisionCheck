import { ChevronDown, ChevronUp, FolderOpen, Image, Loader2, Sparkles, Star, Video } from 'lucide-react'
import { useMemo, useState } from 'react'
import { AdminCard } from '../AdminCard'
import type { MediaAlbum, MediaAsset } from '../../lib/mediaLibrary'
import { formatMediaDate } from '../../lib/mediaLibrary'
import { MediaPreviewContent } from './MediaPreviewContent'
import { MediaTile } from './MediaTile'

interface AlbumsProps {
  albums: MediaAlbum[]
  selectedAlbumId: string | null
  onAlbumTap: (album: MediaAlbum) => void
  onClearAlbum: () => void
}

export function EventAlbumsSection({ albums, selectedAlbumId, onAlbumTap, onClearAlbum }: AlbumsProps) {
  if (albums.length === 0) return null

  return (
    <AdminCard padding="none" className="overflow-hidden border-[var(--color-border)] bg-transparent shadow-none">
      <div className="border-b border-[var(--color-border)] px-4 py-3">
        <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <FolderOpen size={16} className="text-[var(--color-accent-blue)]" />
          <h2 className="text-sm font-bold text-[var(--color-text-primary)]">Event albums</h2>
          <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
            {albums.length}
          </span>
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
      <div className="px-4 pb-4">
      <div className="flex gap-3 overflow-x-auto pb-1">
        {albums.map((album) => {
          const selected = selectedAlbumId === album.id
          return (
            <button
              key={album.id}
              type="button"
              onClick={() => onAlbumTap(album)}
              className={[
                'w-48 shrink-0 overflow-hidden rounded-xl border text-left transition',
                selected
                  ? 'border-[var(--color-accent-blue)] ring-2 ring-[var(--color-accent-blue)]/20'
                  : 'border-[var(--color-border)] bg-[var(--color-surface)] hover:border-[var(--color-accent-cyan)]/40',
              ].join(' ')}
            >
              <div className="relative aspect-[4/3] overflow-hidden bg-[var(--color-surface-muted)]">
                {album.coverUrl ? (
                  <img src={album.coverUrl} alt="" className="h-full w-full object-cover" />
                ) : (
                  <div className="flex h-full items-center justify-center text-xs text-[var(--color-text-muted)]">No cover</div>
                )}
                <span className="absolute bottom-2 right-2 rounded-full bg-black/60 px-2 py-0.5 text-[10px] font-bold text-white">
                  {album.totalCount}
                </span>
              </div>
              <div className="p-3">
                <div className="truncate text-xs font-bold text-[var(--color-text-primary)]">{album.name}</div>
                <div className="mt-0.5 text-[10px] text-[var(--color-text-secondary)]">
                  {album.photoCount} photos · {album.videoCount} videos
                </div>
                {album.date && (
                  <div className="mt-0.5 text-[10px] text-[var(--color-text-secondary)]">{formatMediaDate(album.date)}</div>
                )}
              </div>
            </button>
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
      <div className="border-b border-amber-500/15 px-4 py-3">
        <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <Star size={16} className="fill-amber-400 text-amber-400" />
            <h2 className="text-sm font-bold text-[var(--color-text-primary)]">Best picks</h2>
            <span className="rounded-full bg-amber-500/20 px-2 py-0.5 text-[10px] font-bold text-amber-300">{items.length}</span>
          </div>
          <p className="mt-1 text-xs text-[var(--color-text-secondary)]">
            Star items in the gallery, then publish. Published items leave this row and lose their star.
          </p>
        </div>
        {isAdmin && onPublishAll && items.length > 0 && (
          <button
            type="button"
            disabled={
              !facebookReady ||
              publishReadyCount === 0 ||
              (!facebookGraphReady && publishReadyCount > 1)
            }
            title={
              !facebookReady
                ? 'Facebook publishing disabled'
                : !facebookGraphReady && publishReadyCount > 1
                  ? 'Add Page token for bulk publish, or star and publish one item'
                  : undefined
            }
            onClick={onPublishAll}
            className="inline-flex h-9 items-center gap-1.5 rounded-xl bg-[#1877F2] px-3 text-xs font-bold text-white hover:opacity-95 disabled:opacity-50"
          >
            Publish best picks ({publishReadyCount})
          </button>
        )}
        </div>
      </div>

      <div className="px-4 py-4">
      {items.length === 0 ? (
        <div className="flex items-center gap-3 rounded-xl border border-dashed border-amber-500/30 bg-amber-500/5 px-4 py-5">
          <Sparkles size={20} className="shrink-0 text-amber-500" />
          <p className="text-sm text-[var(--color-text-secondary)]">
            No best picks yet. Use the{' '}
            <Star size={12} className="inline fill-amber-400 text-amber-400" /> star on event photos and videos to
            curate what gets published.
          </p>
        </div>
      ) : (
        <div className="flex gap-3 overflow-x-auto pb-1">
          {items.map((item) => (
            <div
              key={item.id}
              className="w-32 shrink-0 overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-sm"
            >
              <button type="button" onClick={() => onPreview(item)} className="block w-full text-left">
                <div className="relative aspect-square overflow-hidden bg-[var(--color-surface-muted)]">
                  <MediaPreviewContent
                    url={item.thumbnailUrl}
                    isVideo={item.isVideo}
                    fileName={item.fileName}
                    mode="thumbnail"
                    className="h-full w-full"
                  />
                  <span className="absolute left-1.5 top-1.5 rounded bg-black/55 px-1.5 py-0.5 text-[9px] font-bold text-white">
                    {item.isVideo ? 'Video' : 'Photo'}
                  </span>
                </div>
                <div className="p-2">
                  <div className="truncate text-[10px] font-bold text-[var(--color-text-primary)]">{item.eventName}</div>
                </div>
              </button>
              {isAdmin && (
                <button
                  type="button"
                  onClick={() => onToggleBestShot(item)}
                  className="w-full border-t border-[var(--color-border)] py-1.5 text-[10px] font-semibold text-amber-300 hover:bg-amber-500/10"
                >
                  Remove
                </button>
              )}
            </div>
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
    <AdminCard padding="md">
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
        <div className="mt-4 space-y-6">
          {items.length === 0 ? (
            <p className="text-sm text-[var(--color-text-secondary)]">No published media yet.</p>
          ) : (
            <>
              {publishedPhotos.length > 0 && (
                <section>
                  <div className="mb-3 flex items-center gap-2">
                    <Image size={16} className="text-[var(--color-accent-cyan)]" />
                    <h3 className="text-sm font-bold text-[var(--color-text-primary)]">Photos</h3>
                    <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
                      {publishedPhotos.length}
                    </span>
                  </div>
                  <div className="grid grid-cols-[repeat(auto-fill,minmax(168px,1fr))] gap-4">
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
                  <div className="mb-3 flex items-center gap-2">
                    <Video size={16} className="text-[var(--color-accent-blue)]" />
                    <h3 className="text-sm font-bold text-[var(--color-text-primary)]">Videos</h3>
                    <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
                      {publishedVideos.length}
                    </span>
                  </div>
                  <div className="grid grid-cols-[repeat(auto-fill,minmax(168px,1fr))] gap-4">
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
    </AdminCard>
  )
}
