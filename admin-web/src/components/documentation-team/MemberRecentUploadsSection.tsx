import { useState } from 'react'
import { Play } from 'lucide-react'
import { DrawerBackButton } from '../AdminBackButton'
import { MediaPreviewContent } from '../media-library/MediaPreviewContent'
import type { MemberUploadPreview } from '../../lib/teamMembers'

interface Props {
  memberName: string
  uploads: MemberUploadPreview[]
  emptyMessage?: string
}

export function MemberRecentUploadsSection({
  memberName,
  uploads,
  emptyMessage = 'No photos or videos uploaded yet. Practice evaluations and event coverage will appear here.',
}: Props) {
  const [preview, setPreview] = useState<MemberUploadPreview | null>(null)

  if (uploads.length === 0) {
    return (
      <p className="text-xs text-[var(--color-text-secondary)]">{emptyMessage}</p>
    )
  }

  return (
    <>
      <div className="grid grid-cols-3 gap-2 sm:grid-cols-4">
        {uploads.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => setPreview(item)}
            className="group relative aspect-square overflow-hidden rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)]"
          >
            <MediaPreviewContent
              url={item.thumbnailUrl}
              isVideo={item.isVideo}
              fileName={item.fileName}
              mode="thumbnail"
              className="h-full w-full"
            />
            {item.isVideo ? (
              <span className="pointer-events-none absolute inset-0 flex items-center justify-center">
                <span className="flex h-8 w-8 items-center justify-center rounded-full bg-black/45 text-white">
                  <Play size={14} fill="currentColor" className="ml-0.5" />
                </span>
              </span>
            ) : null}
            <span className="pointer-events-none absolute left-1.5 top-1.5 rounded bg-black/55 px-1.5 py-0.5 text-[9px] font-bold uppercase text-white">
              {item.isVideo ? 'Video' : 'Photo'}
            </span>
            {item.overallScore != null && item.overallScore > 0 ? (
              <span className="pointer-events-none absolute bottom-1.5 right-1.5 rounded bg-[var(--color-accent-blue)]/90 px-1.5 py-0.5 text-[9px] font-bold text-white">
                {Math.round(item.overallScore)}%
              </span>
            ) : null}
          </button>
        ))}
      </div>

      <p className="mt-2 text-[10px] text-[var(--color-text-muted)]">
        Latest {uploads.length} upload{uploads.length === 1 ? '' : 's'} for {memberName} (event coverage and
        practice).
      </p>

      {preview ? (
        <>
          <button
            type="button"
            aria-label="Close preview"
            className="fixed inset-0 z-[60] bg-black/35"
            onClick={() => setPreview(null)}
          />
          <div
            role="dialog"
            aria-modal="true"
            aria-label={preview.fileName}
            className="fixed inset-y-0 right-0 z-[70] flex w-full max-w-md flex-col overflow-hidden border-l border-[var(--color-border)] bg-[var(--color-surface)] shadow-xl"
          >
            <div className="flex items-center gap-2 border-b border-[var(--color-border)] px-4 py-3">
              <DrawerBackButton onClick={() => setPreview(null)} label="Back" />
              <div className="min-w-0 flex-1">
                <h3 className="truncate text-sm font-extrabold text-[var(--color-text-primary)]">
                  {preview.fileName}
                </h3>
                <p className="text-[10px] text-[var(--color-text-secondary)]">
                  {memberName} · {preview.uploadDateLabel}
                </p>
              </div>
            </div>
            <div className="flex-1 space-y-3 overflow-y-auto overscroll-contain p-4">
              <div className="max-w-full overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)]">
                <MediaPreviewContent
                  url={preview.thumbnailUrl}
                  isVideo={preview.isVideo}
                  fileName={preview.fileName}
                  className="max-w-full"
                />
              </div>
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3 text-xs">
                <div className="font-semibold text-[var(--color-text-primary)]">{preview.sourceLabel}</div>
                {preview.eventName && preview.eventName !== preview.sourceLabel ? (
                  <div className="mt-1 text-[var(--color-text-secondary)]">{preview.eventName}</div>
                ) : null}
                <div className="mt-1 text-[var(--color-text-muted)]">
                  {preview.mediaCategory === 'member_evaluation' ? 'Practice evaluation' : 'Event documentation'}
                  {preview.overallScore != null && preview.overallScore > 0
                    ? ` · ${Math.round(preview.overallScore)}% score`
                    : ''}
                </div>
              </div>
            </div>
          </div>
        </>
      ) : null}
    </>
  )
}
