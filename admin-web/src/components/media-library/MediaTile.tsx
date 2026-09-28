import { Check, Play, Star, Trash2, XCircle } from 'lucide-react'
import { canPublishToFacebook, type MediaAsset } from '../../lib/mediaLibrary'
import { MediaPreviewContent } from './MediaPreviewContent'

interface Props {
  item: MediaAsset
  selected: boolean
  isAdmin: boolean
  onTap: () => void
  onSelectToggle: () => void
  onToggleBestShot: () => void
  onDelete?: () => void
}

export function MediaTile({ item, selected, isAdmin, onTap, onSelectToggle, onToggleBestShot, onDelete }: Props) {
  const isEventDoc = item.mediaCategory === 'event_documentation'
  const fbPublished = item.facebookPublishStatus === 'published'
  const fbFailed = item.facebookPublishStatus === 'failed'
  const publishReady = canPublishToFacebook(item)

  return (
    <article
      className={[
        'group relative overflow-hidden rounded-[var(--card-radius)] border bg-[var(--color-surface)] shadow-[0_2px_8px_rgba(15,39,68,0.04)] transition',
        selected
          ? 'border-[var(--color-accent-blue)] ring-2 ring-[var(--color-accent-blue)]/25'
          : 'border-[var(--color-border)] hover:border-[var(--color-accent-cyan)]/50 hover:shadow-[0_4px_16px_rgba(15,39,68,0.08)]',
      ].join(' ')}
    >
      <button type="button" onClick={onTap} className="group relative block aspect-square w-full overflow-hidden bg-[var(--color-surface-muted)]">
        <MediaPreviewContent
          url={item.thumbnailUrl}
          isVideo={item.isVideo}
          fileName={item.fileName}
          mode="thumbnail"
          className="h-full w-full"
        />

        {item.isVideo && (
          <span className="pointer-events-none absolute inset-0 flex items-center justify-center">
            <span className="flex h-10 w-10 items-center justify-center rounded-full bg-black/45 text-white backdrop-blur-sm">
              <Play size={18} fill="currentColor" className="ml-0.5" />
            </span>
          </span>
        )}

        <div className="pointer-events-none absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/75 via-black/35 to-transparent px-2.5 pb-2.5 pt-10">
          <p className="truncate text-left text-xs font-bold text-white">{item.eventName}</p>
          <p className="truncate text-left text-[10px] text-white/80">{item.uploaderName}</p>
        </div>

        <span className="absolute left-2 top-2 rounded-md bg-black/55 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-white">
          {item.isVideo ? 'Video' : 'Photo'}
        </span>

        {!isEventDoc && (
          <span className="absolute left-2 top-9 rounded-md bg-violet-600/90 px-1.5 py-0.5 text-[9px] font-bold text-white">
            Evaluation
          </span>
        )}

        {isEventDoc && fbPublished && (
          <span className="absolute bottom-14 right-2 flex h-6 w-6 items-center justify-center rounded-full bg-emerald-600/90 text-white shadow-sm">
            <Check size={12} strokeWidth={3} />
          </span>
        )}
        {isEventDoc && fbFailed && (
          <span className="absolute bottom-14 right-2 flex h-6 w-6 items-center justify-center rounded-full bg-red-600/90 text-white shadow-sm">
            <XCircle size={12} />
          </span>
        )}
        {isEventDoc && publishReady && (
          <span className="absolute bottom-14 right-2 flex h-6 w-6 items-center justify-center rounded-full bg-amber-500/90 text-white shadow-sm">
            <Star size={11} className="fill-current" />
          </span>
        )}
      </button>

      <div className="absolute right-2 top-2 flex items-center gap-1.5">
        {isAdmin && onDelete && (
          <button
            type="button"
            title="Delete permanently"
            onClick={(e) => {
              e.stopPropagation()
              onDelete()
            }}
            className="flex h-7 w-7 items-center justify-center rounded-full border border-red-400/50 bg-red-600/85 text-white opacity-0 shadow-sm transition group-hover:opacity-100 hover:bg-red-600"
          >
            <Trash2 size={13} />
          </button>
        )}
        {isAdmin && isEventDoc && !fbPublished && (
          <button
            type="button"
            title={item.isBestShot ? 'Remove best pick' : 'Mark as best pick'}
            onClick={(e) => {
              e.stopPropagation()
              onToggleBestShot()
            }}
            className={[
              'flex h-7 w-7 items-center justify-center rounded-full border shadow-sm transition',
              item.isBestShot
                ? 'border-amber-400/50 bg-amber-500/20 text-amber-300'
                : 'border-white/80 bg-black/40 text-white hover:bg-black/55',
            ].join(' ')}
          >
            <Star size={14} className={item.isBestShot ? 'fill-current' : ''} />
          </button>
        )}
        <button
          type="button"
          title={selected ? 'Deselect' : 'Select'}
          onClick={(e) => {
            e.stopPropagation()
            onSelectToggle()
          }}
          className={[
            'flex h-7 w-7 items-center justify-center rounded-full border-2 shadow-sm transition',
            selected
              ? 'border-[var(--color-accent-blue)] bg-[var(--color-accent-blue)] text-white'
              : 'border-white bg-black/40 text-transparent hover:bg-black/55',
          ].join(' ')}
        >
          <Check size={14} className={selected ? 'opacity-100' : 'opacity-0'} strokeWidth={3} />
        </button>
      </div>

      <div className="flex items-center justify-between gap-2 border-t border-[var(--color-border)] px-2.5 py-2">
        <div className="min-w-0">
          <p className="truncate text-[11px] font-semibold text-[var(--color-text-primary)]">{item.fileName}</p>
          {item.uploadDateLabel && (
            <p className="text-[10px] text-[var(--color-text-secondary)]">{item.uploadDateLabel}</p>
          )}
        </div>
        {isEventDoc && fbPublished && (
          <span className="shrink-0 rounded-full bg-emerald-500/15 px-2 py-0.5 text-[9px] font-bold text-emerald-300">
            Published
          </span>
        )}
        {isEventDoc && fbFailed && (
          <span className="shrink-0 rounded-full bg-red-500/15 px-2 py-0.5 text-[9px] font-bold text-red-300">
            Failed
          </span>
        )}
        {item.isBestShot && isEventDoc && !fbPublished && (
          <span className="shrink-0 rounded-full bg-amber-500/15 px-2 py-0.5 text-[9px] font-bold text-amber-300">
            Best pick
          </span>
        )}
      </div>
    </article>
  )
}
