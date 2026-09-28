import { ExternalLink } from 'lucide-react'
import { AdminCard } from '../AdminCard'
import type { AiDetectionRow } from '../../api/media'
import { adminMediaStreamUrl, mediaUrl } from '../../api/media'
import { formatScannedDate, isProbeSmokeTestRow, isVideoDetectionRow } from '../../lib/aiDetection'
import { MediaPreviewContent } from '../media-library/MediaPreviewContent'
import { AiResultBadge, ConfidenceBar, ReviewStatusBadge } from './Badges'

interface Props {
  row: AiDetectionRow
  onDetails: (row: AiDetectionRow) => void
}

export function AiDetectionRowCard({ row, onDetails }: Props) {
  const previewUrl = row.media_id ? adminMediaStreamUrl(row.media_id) : mediaUrl(row.media_url)
  const openUrl = mediaUrl(row.media_url) || previewUrl
  const isVideo = isVideoDetectionRow(row)
  const probeSmoke = isProbeSmokeTestRow(row)
  const needsAction =
    row.review_status === 'pending_review' || row.review_status === 'needs_further_review'

  return (
    <AdminCard
      as="article"
      hover
      padding="sm"
      bodyClassName="flex gap-4"
      className={needsAction ? 'border-amber-200/80' : undefined}
    >
      <div className="relative h-[80px] w-[80px] shrink-0 overflow-hidden rounded-xl bg-[var(--color-surface-muted)]">
        <MediaPreviewContent
          url={previewUrl}
          isVideo={isVideo}
          fileName={row.media_name}
          fileType={row.file_type}
          mode="thumbnail"
          className="h-full w-full"
        />
        <span className="absolute left-1 top-1 rounded bg-black/55 px-1.5 py-0.5 text-[9px] font-bold text-white">
          {isVideo ? 'Video' : 'Photo'}
        </span>
      </div>

      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-start justify-between gap-2">
          <div className="min-w-0">
            <h3 className="truncate text-sm font-bold text-[var(--color-text-primary)]">{row.media_name}</h3>
            <div className="mt-0.5 flex flex-wrap items-center gap-2">
              <p className="text-xs text-[var(--color-text-secondary)]">{row.member_name}</p>
              {probeSmoke ? (
                <span className="rounded bg-[var(--color-surface-muted)] px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-[var(--color-text-muted)]">
                  PROBE smoke
                </span>
              ) : null}
            </div>
          </div>
          <AiResultBadge label={row.ai_label} />
        </div>
        <div className="mt-3">
          <ConfidenceBar score={row.confidence_score} label={row.confidence_text} level={row.confidence_level} />
        </div>
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <ReviewStatusBadge status={row.review_status} />
          <span className="text-[11px] text-[var(--color-text-secondary)]">
            Scanned {formatScannedDate(row.scanned_at)}
          </span>
        </div>
        {row.detection_remarks && (
          <p className="mt-2 line-clamp-2 text-[11px] leading-relaxed text-[var(--color-text-secondary)]">
            {row.detection_remarks}
          </p>
        )}
      </div>

      <div className="flex shrink-0 flex-col items-end justify-between gap-2">
        <button
          type="button"
          onClick={() => onDetails(row)}
          className={[
            'rounded-lg px-3 py-2 text-xs font-bold transition',
            needsAction
              ? 'bg-[var(--color-accent-blue)] text-white hover:opacity-95'
              : 'border border-[var(--color-border)] bg-[var(--color-surface-elevated)] text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]',
          ].join(' ')}
        >
          Review
        </button>
        {openUrl && (
          <a
            href={openUrl}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1 rounded-lg px-2 py-1 text-[11px] font-semibold text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]"
          >
            <ExternalLink size={12} />
            Open
          </a>
        )}
      </div>
    </AdminCard>
  )
}
