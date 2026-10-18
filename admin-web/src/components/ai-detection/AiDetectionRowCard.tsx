import type { AiDetectionRow } from '../../api/media'
import { adminIntegrityPreviewUrl } from '../../api/media'
import { formatScannedDate, isProbeSmokeTestRow, isVideoDetectionRow } from '../../lib/aiDetection'
import { MediaPreviewContent } from '../media-library/MediaPreviewContent'
import { AiProbability, ReviewStatusBadge, RiskBadge } from './Badges'

interface Props {
  row: AiDetectionRow
  showFormat?: boolean
  onDetails: (row: AiDetectionRow) => void
}

export function AiDetectionRowCard({ row, showFormat = true, onDetails }: Props) {
  const previewUrl = adminIntegrityPreviewUrl({
    mediaId: row.media_id,
    mediaUrl: row.media_url,
    fileName: row.media_name,
    fileType: row.file_type,
  })
  const isVideo = isVideoDetectionRow(row)
  const probeSmoke = isProbeSmokeTestRow(row)

  return (
    <article className="flex items-center gap-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2.5 shadow-[0_1px_2px_rgba(15,39,68,0.04)] transition hover:border-[var(--color-accent-cyan)]/50">
      <button
        type="button"
        onClick={() => onDetails(row)}
        aria-label={`Review ${row.media_name}`}
        className="relative h-16 w-16 shrink-0 overflow-hidden rounded-lg bg-[var(--color-surface-muted)]"
      >
        <MediaPreviewContent
          url={previewUrl}
          isVideo={isVideo}
          fileName={row.media_name}
          fileType={row.file_type}
          mode="thumbnail"
          className="h-full w-full"
        />
      </button>

      <div className="min-w-0 flex-1">
        <div className="flex min-w-0 items-center gap-1.5">
          <h3 className="truncate text-[13px] font-bold text-[var(--color-text-primary)]" title={row.media_name}>
            {row.media_name}
          </h3>
          {showFormat ? (
            <span className="shrink-0 rounded bg-[var(--color-surface-muted)] px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
              {isVideo ? 'Video' : 'Photo'}
            </span>
          ) : null}
          {probeSmoke ? (
            <span className="shrink-0 rounded bg-[var(--color-surface-muted)] px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-[var(--color-text-muted)]">
              PROBE smoke
            </span>
          ) : null}
        </div>
        <p className="mt-0.5 truncate text-[11px] text-[var(--color-text-secondary)]">
          {row.member_name} · Scanned {formatScannedDate(row.scanned_at)}
        </p>
        <div className="mt-1.5 flex flex-wrap items-center gap-x-2 gap-y-1">
          <RiskBadge label={row.ai_label} />
          <AiProbability label={row.ai_label} probability={row.ai_probability} />
        </div>
      </div>

      <div className="flex shrink-0 flex-col items-end gap-1.5">
        <ReviewStatusBadge status={row.review_status} compact />
        <button
          type="button"
          onClick={() => onDetails(row)}
          className="rounded-lg bg-[var(--color-accent-blue)] px-3.5 py-1.5 text-xs font-bold text-white transition hover:opacity-95"
        >
          Review
        </button>
      </div>
    </article>
  )
}
