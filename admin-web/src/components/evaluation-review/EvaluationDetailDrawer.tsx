import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Loader2 } from 'lucide-react'
import { MediaPipelineLinks } from '../AdminCrossLinks'
import { mediaIntegrityUrl } from '../../lib/adminCrossLinks'
import { isVideoMediaPath, mediaUrl } from '../../api/media'
import { AdminConfirmDialog } from '../AdminConfirmDialog'
import { AdminDrawer } from '../AdminDrawer'
import { MediaPreviewContent } from '../media-library/MediaPreviewContent'
import type { EvaluationReviewItem } from '../../lib/evaluationReview'
import { formatEvalDate, isEvaluationFlagged, scoreTone } from '../../lib/evaluationReview'

interface Props {
  item: EvaluationReviewItem | null
  saving?: boolean
  onClose: () => void
  onSaveRemarks: (remarks: string) => Promise<void>
  onArchive: () => Promise<void>
}

function ScoreRow({ label, value }: { label: string; value: number | null }) {
  return (
    <div className="flex items-center justify-between text-xs">
      <span className="text-[var(--color-text-secondary)]">{label}</span>
      <span className="font-bold text-[var(--color-text-primary)]">
        {value != null ? `${Math.round(value)}%` : 'N/A'}
      </span>
    </div>
  )
}

export function EvaluationDetailDrawer({
  item,
  saving = false,
  onClose,
  onSaveRemarks,
  onArchive,
}: Props) {
  const [remarks, setRemarks] = useState('')
  const [confirmArchive, setConfirmArchive] = useState(false)

  useEffect(() => {
    if (item) setRemarks(item.adminRemarks ?? '')
  }, [item])

  if (!item) return null

  const flagged = isEvaluationFlagged(item)
  const previewUrl = mediaUrl(item.fileUrl)

  return (
    <>
      <AdminDrawer
        open
        onClose={onClose}
        title="Evaluation review"
        subtitle={`${item.memberName} · ${formatEvalDate(item.evaluatedAt)}`}
        maxWidth="lg"
        bodyClassName="space-y-4 px-5 pb-5"
        footer={
          <div className="flex flex-wrap gap-2 bg-[var(--color-surface-muted)] p-4">
            <button
              type="button"
              disabled={saving}
              onClick={() => void onSaveRemarks(remarks.trim())}
              className="rounded-lg bg-[var(--color-accent-blue)] px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            >
              {saving ? <Loader2 size={14} className="animate-spin" /> : 'Save admin notes'}
            </button>
            <button
              type="button"
              disabled={saving}
              onClick={() => setConfirmArchive(true)}
              className="rounded-lg border border-[var(--color-border)] px-4 py-2 text-sm font-semibold disabled:opacity-50"
            >
              Archive media
            </button>
            {flagged ? (
              <Link
                to={mediaIntegrityUrl(item.mediaId)}
                onClick={onClose}
                className="inline-flex items-center gap-1.5 rounded-lg px-4 py-2 text-sm font-semibold admin-alert--warning"
              >
                Open Media Integrity
              </Link>
            ) : null}
          </div>
        }
      >
        <MediaPipelineLinks
          mediaId={item.mediaId}
          uploaderName={item.memberName}
          showIntegrity={flagged}
          onNavigate={onClose}
        />

        {flagged ? (
          <div className="admin-alert--warning mt-3 rounded-xl px-3 py-2.5 text-xs">
            AI scan flagged this upload ({item.aiResult?.replace(/_/g, ' ')}). Review in Media Integrity if
            needed.
          </div>
        ) : null}

        <div className="max-w-full overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)]">
          <MediaPreviewContent
            url={previewUrl}
            fileName={item.fileName}
            isVideo={isVideoMediaPath(item.fileUrl) || isVideoMediaPath(item.fileName)}
            className="max-w-full"
          />
        </div>

        <div className="grid gap-3 sm:grid-cols-2">
          <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3">
            <div className="text-[10px] font-bold uppercase text-[var(--color-text-secondary)]">Overall</div>
            <div className={`mt-1 text-2xl font-extrabold ${scoreTone(item.overallScore)}`}>
              {Math.round(item.overallScore)}%
            </div>
            <div className="mt-1 text-xs text-[var(--color-text-secondary)]">
              {item.qualityLevel ?? 'No quality tier'}
            </div>
          </div>
          <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3">
            <div className="text-[10px] font-bold uppercase text-[var(--color-text-secondary)]">Source</div>
            <div className="mt-1 text-sm font-bold text-[var(--color-text-primary)]">{item.sourceLabel}</div>
            {item.eventTitle ? (
              <div className="mt-1 text-xs text-[var(--color-text-secondary)]">{item.eventTitle}</div>
            ) : null}
          </div>
        </div>

        <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3">
          <div className="mb-2 text-xs font-bold text-[var(--color-text-primary)]">Criterion scores</div>
          <div className="space-y-1.5">
            <ScoreRow label="Sharpness" value={item.sharpnessScore} />
            <ScoreRow label="Brightness" value={item.brightnessScore} />
            <ScoreRow label="Contrast" value={item.contrastScore} />
            <ScoreRow label="Blur" value={item.blurScore} />
            <ScoreRow label="Noise" value={item.noiseScore} />
          </div>
        </div>

        {item.recommendation ? (
          <div className="rounded-xl border border-[var(--color-accent-blue)]/20 bg-[var(--color-accent-blue)]/10 p-3">
            <div className="text-[10px] font-bold uppercase text-[var(--color-text-secondary)]">
              System recommendation
            </div>
            <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-primary)]">{item.recommendation}</p>
          </div>
        ) : null}

        {item.feedback ? (
          <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3">
            <div className="text-[10px] font-bold uppercase text-[var(--color-text-secondary)]">
              Member feedback
            </div>
            <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-primary)]">{item.feedback}</p>
          </div>
        ) : null}

        <div>
          <label htmlFor="eval-admin-remarks" className="text-xs font-bold text-[var(--color-text-primary)]">
            Admin notes
          </label>
          <textarea
            id="eval-admin-remarks"
            value={remarks}
            onChange={(e) => setRemarks(e.target.value)}
            rows={4}
            maxLength={2000}
            placeholder="Internal notes for competency or coaching follow-up…"
            className="admin-input mt-2 w-full rounded-xl px-3 py-2 text-sm"
          />
        </div>
      </AdminDrawer>

      <AdminConfirmDialog
        open={confirmArchive}
        title="Archive evaluated media?"
        message="The upload will be moved to the archive. Members will no longer see it in active galleries."
        confirmLabel="Archive"
        tone="danger"
        loading={saving}
        onConfirm={() => {
          setConfirmArchive(false)
          void onArchive()
        }}
        onCancel={() => setConfirmArchive(false)}
      />
    </>
  )
}
