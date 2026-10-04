import { Star } from 'lucide-react'
import type { MediaAsset } from '../../lib/mediaLibrary'
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

export function MediaTile({ item, selected, isAdmin, onTap, onToggleBestShot }: Props) {
  const isEventDoc = item.mediaCategory === 'event_documentation'
  const fbPublished = item.facebookPublishStatus === 'published'
  const fbFailed = item.facebookPublishStatus === 'failed'
  const showBestPickStar = isAdmin && isEventDoc && !fbPublished

  return (
    <article
      className={[
        'group relative flex h-full flex-col overflow-hidden rounded-xl border bg-[var(--color-surface)] shadow-[0_1px_3px_rgba(15,39,68,0.06)] transition',
        selected
          ? 'border-[var(--color-accent-blue)] ring-2 ring-[var(--color-accent-blue)]/25'
          : 'border-[var(--color-border)] hover:border-[var(--color-accent-cyan)]/45 hover:shadow-[0_4px_12px_rgba(15,39,68,0.08)]',
      ].join(' ')}
    >
      <button
        type="button"
        onClick={onTap}
        className="group relative block aspect-[4/3] w-full shrink-0 overflow-hidden bg-[var(--color-surface-muted)]"
      >
        <MediaPreviewContent
          url={item.thumbnailUrl}
          isVideo={item.isVideo}
          fileName={item.fileName}
          mode="thumbnail"
          className="h-full w-full"
        />

        {!isEventDoc && (
          <span className="absolute left-2 top-2 rounded-md bg-violet-600/85 px-1.5 py-0.5 text-[9px] font-bold text-white">
            Evaluation
          </span>
        )}
      </button>

      {showBestPickStar ? (
        <button
          type="button"
          title={item.isBestShot ? 'Remove best pick' : 'Add to best picks'}
          onClick={(e) => {
            e.stopPropagation()
            onToggleBestShot()
          }}
          className={[
            'absolute right-1.5 top-1.5 drop-shadow-[0_1px_2px_rgba(0,0,0,0.75)] transition',
            item.isBestShot ? 'text-amber-400' : 'text-white hover:text-amber-200',
          ].join(' ')}
        >
          <Star size={16} className={item.isBestShot ? 'fill-current' : ''} />
        </button>
      ) : null}

      <div className="flex min-h-[52px] flex-1 items-start justify-between gap-2 border-t border-[var(--color-border)] px-2.5 py-2">
        <div className="min-w-0 flex-1">
          <p className="truncate text-[11px] font-semibold text-[var(--color-text-primary)]" title={item.fileName}>
            {item.fileName}
          </p>
          {item.uploadDateLabel ? (
            <p className="mt-0.5 text-[10px] text-[var(--color-text-secondary)]">{item.uploadDateLabel}</p>
          ) : null}
        </div>
        {isEventDoc && fbPublished && (
          <span className="shrink-0 rounded-md bg-emerald-500/12 px-1.5 py-0.5 text-[9px] font-bold text-emerald-600">
            Published
          </span>
        )}
        {isEventDoc && fbFailed && (
          <span className="shrink-0 rounded-md bg-red-500/12 px-1.5 py-0.5 text-[9px] font-bold text-red-600">
            Failed
          </span>
        )}
        {item.isBestShot && isEventDoc && !fbPublished && (
          <span className="shrink-0 rounded-md bg-amber-500/12 px-1.5 py-0.5 text-[9px] font-bold text-amber-600">
            Best pick
          </span>
        )}
      </div>
    </article>
  )
}
