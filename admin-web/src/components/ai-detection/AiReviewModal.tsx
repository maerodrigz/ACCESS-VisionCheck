import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react'
import { Archive, ChevronDown, Loader2, Maximize2 } from 'lucide-react'
import { DrawerBackButton } from '../AdminBackButton'
import { AdminConfirmDialog } from '../AdminConfirmDialog'
import { MediaLightbox } from '../MediaLightbox'
import {
  archiveAiDetectionMedia,
  fetchAiReviewHistory,
  updateAiDetectionReview,
} from '../../api/admin'
import type { AiDetectionRow, AiReviewHistoryEntry, ReviewStatus } from '../../api/media'
import { adminMediaStreamUrl, isVideoMediaPath, mediaUrl } from '../../api/media'
import { MediaPreviewContent } from '../media-library/MediaPreviewContent'
import { formatScannedDate } from '../../lib/aiDetection'
import {
  cameraMetadataStatus,
  integrityAssessmentSummary,
  integrityReviewReason,
  INTEGRITY_AI_DISCLAIMER,
  visualAiRiskBand,
  visualAiRiskColor,
  visualAiRiskSummaryLabel,
} from '../../lib/reviewScanPresentation'
import { ReviewStatusBadge } from './Badges'
import { ReviewScanTechnicalDetails } from './ReviewScanTechnicalDetails'

const REVIEW_ACTIONS: {
  status: ReviewStatus
  label: string
  color: string
  exampleRemarks: string
  confirm?: { title: string; message: string; tone?: 'default' | 'danger' | 'success' }
}[] = [
  {
    status: 'verified_human',
    label: 'Verify as Human',
    color: 'var(--color-success)',
    exampleRemarks: 'Verified as human-made media.',
    confirm: {
      title: 'Verify as human?',
      message: 'Release stored quality scores and feedback to the member.',
      tone: 'success',
    },
  },
  {
    status: 'confirmed_ai_generated',
    label: 'Confirm AI / Manipulated',
    color: 'var(--color-danger)',
    exampleRemarks: 'Confirmed AI-generated or manipulated content.',
    confirm: {
      title: 'Confirm as AI / manipulated?',
      message: 'Quality scores and XP will not be released for this submission.',
      tone: 'danger',
    },
  },
  {
    status: 'reupload_requested',
    label: 'Request Re-upload',
    color: 'var(--color-warning)',
    exampleRemarks: 'Please upload a new original photo or video.',
  },
]

const FINAL_REVIEW_STATUSES: ReviewStatus[] = [
  'verified_human',
  'confirmed_ai_generated',
  'reupload_requested',
]

function tint(color: string, pct: number) {
  return `color-mix(in srgb, ${color} ${pct}%, transparent)`
}

function AssessmentRow({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-3 py-1.5">
      <dt className="text-xs text-[var(--color-text-secondary)]">{label}</dt>
      <dd className="min-w-0 text-right text-xs font-semibold text-[var(--color-text-primary)]">{children}</dd>
    </div>
  )
}

function Collapsible({ title, children }: { title: string; children: ReactNode }) {
  return (
    <details className="group rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)]">
      <summary className="flex cursor-pointer list-none items-center justify-between gap-2 px-3 py-2 text-xs font-bold text-[var(--color-text-primary)] [&::-webkit-details-marker]:hidden">
        {title}
        <ChevronDown size={14} className="text-[var(--color-text-muted)] transition group-open:rotate-180" />
      </summary>
      <div className="border-t border-[var(--color-border)] px-3 py-3">{children}</div>
    </details>
  )
}

interface Props {
  row: AiDetectionRow
  onClose: () => void
  onSaved: (status: ReviewStatus) => void
}

export function AiReviewModal({ row, onClose, onSaved }: Props) {
  const [remarks, setRemarks] = useState(row.admin_remarks ?? '')
  const [status, setStatus] = useState<ReviewStatus>(row.review_status)
  const [saving, setSaving] = useState(false)
  const [history, setHistory] = useState<AiReviewHistoryEntry[]>([])
  const [error, setError] = useState<string | null>(null)
  const [confirm, setConfirm] = useState<{
    title: string
    message: string
    tone?: 'default' | 'danger' | 'success'
    onConfirm: () => void
  } | null>(null)
  const [showFullMedia, setShowFullMedia] = useState(false)
  const [remarksExample, setRemarksExample] = useState<string | null>(null)
  const [selectedActionLabel, setSelectedActionLabel] = useState<string | null>(null)
  const remarksRef = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    fetchAiReviewHistory(row.id)
      .then(setHistory)
      .catch(() => setHistory([]))
  }, [row.id])

  async function save(nextStatus: ReviewStatus, nextRemarks: string) {
    setSaving(true)
    setError(null)
    try {
      await updateAiDetectionReview(row.id, {
        review_status: nextStatus,
        admin_remarks: nextRemarks.trim(),
      })
      onSaved(nextStatus)
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save review')
    } finally {
      setSaving(false)
    }
  }

  function applyQuickAction(action: (typeof REVIEW_ACTIONS)[number]) {
    const applyLocal = () => {
      setStatus(action.status)
      setSelectedActionLabel(action.label)
      setRemarksExample(action.exampleRemarks)
      setError(null)
      requestAnimationFrame(() => {
        remarksRef.current?.focus()
        remarksRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      })
    }
    if (action.confirm) {
      setConfirm({
        title: action.confirm.title,
        message: `${action.confirm.message} You can add optional feedback for the member, then click Save Review. This panel stays open until then.`,
        tone: action.confirm.tone,
        onConfirm: () => {
          setConfirm(null)
          applyLocal()
        },
      })
      return
    }
    applyLocal()
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    await save(status, remarks)
  }

  function requestArchive() {
    setConfirm({
      title: 'Archive media?',
      message: `"${row.media_name}" will be moved to archives.`,
      tone: 'danger',
      onConfirm: () => {
        setConfirm(null)
        void handleArchive()
      },
    })
  }

  async function handleArchive() {
    setSaving(true)
    try {
      await archiveAiDetectionMedia(row.id)
      onSaved(status)
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Archive failed')
    } finally {
      setSaving(false)
    }
  }

  const previewUrl = row.media_id ? adminMediaStreamUrl(row.media_id) : mediaUrl(row.media_url)
  const isVideo =
    isVideoMediaPath(row.media_name) ||
    isVideoMediaPath(row.media_url) ||
    row.file_type?.toLowerCase().includes('video') === true
  const reviewReason = integrityReviewReason(row)
  const visualBand = visualAiRiskBand(row)
  const visualRiskColor = visualAiRiskColor(visualBand)
  const cameraMeta = cameraMetadataStatus(row.exif_metadata)
  const assessmentSummary = integrityAssessmentSummary(row)

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-3 md:p-5">
        <div className="flex max-h-full w-full max-w-6xl flex-col overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-content-bg)] shadow-xl">
          <div className="flex shrink-0 items-center gap-2 border-b border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2">
            <DrawerBackButton onClick={onClose} label="Back" />
            <div className="min-w-0 flex-1">
              <h2 className="text-sm font-extrabold text-[var(--color-text-primary)]">Review Scan</h2>
              <p className="truncate text-xs text-[var(--color-text-secondary)]">
                <span className="font-semibold text-[var(--color-text-primary)]">{row.media_name}</span>
                {row.media_id ? ` · Media ID ${row.media_id}` : ''} · {row.member_name}
              </p>
            </div>
          </div>

          <div className="flex min-h-0 flex-1 flex-col overflow-hidden p-3 lg:grid lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)] lg:gap-3">
              <section className="shrink-0 overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] lg:min-h-0 lg:self-start">
                {previewUrl ? (
                  <>
                    <div className="flex flex-wrap items-center justify-between gap-1.5 border-b border-[var(--color-border)] bg-[var(--color-surface)] px-2.5 py-1.5">
                      <p className="text-[10px] text-[var(--color-text-muted)]">
                        {isVideo ? 'Use video controls to play.' : 'Open full screen to zoom in.'}
                      </p>
                      <div className="flex items-center gap-1.5">
                        <button
                          type="button"
                          onClick={() => setShowFullMedia(true)}
                          className="inline-flex items-center gap-1 rounded-md border border-[var(--color-border)] px-2 py-1 text-[10px] font-semibold text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]"
                        >
                          <Maximize2 size={13} />
                          Full Screen
                        </button>
                      </div>
                    </div>
                    <div className="flex min-h-[180px] items-center justify-center bg-[var(--color-surface-muted)]">
                      <MediaPreviewContent
                        url={previewUrl}
                        isVideo={isVideo}
                        fileName={row.media_name}
                        fileType={row.file_type}
                        mode="preview"
                        className="max-h-[52vh]! max-w-full"
                      />
                    </div>
                  </>
                ) : (
                  <div className="px-4 py-10 text-center text-xs text-[var(--color-text-secondary)]">
                    Preview unavailable (missing media file URL).
                  </div>
                )}
              </section>

              <div className="min-h-0 flex-1 space-y-3 overflow-y-auto overscroll-y-contain pr-0.5 lg:max-h-full">
                <section className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-4 py-3">
                  <h3 className="mb-1 text-sm font-bold text-[var(--color-text-primary)]">Integrity Assessment</h3>
                  <dl className="divide-y divide-[var(--color-border)]">
                    <AssessmentRow label="Visual AI Risk">
                      <span className="inline-flex items-center justify-end gap-1.5">
                        <span
                          className="h-2 w-2 shrink-0 rounded-full"
                          style={{ backgroundColor: visualRiskColor }}
                          aria-hidden
                        />
                        <span>{visualAiRiskSummaryLabel(row)}</span>
                      </span>
                    </AssessmentRow>
                    <AssessmentRow label="Review Status">
                      <ReviewStatusBadge status={row.review_status} />
                    </AssessmentRow>
                    {reviewReason ? (
                      <AssessmentRow label="Review Reason">
                        <span className="max-w-[14rem] text-left text-[11px] font-medium leading-snug sm:text-right">
                          {reviewReason}
                        </span>
                      </AssessmentRow>
                    ) : null}
                    <AssessmentRow label="Camera Metadata">{cameraMeta}</AssessmentRow>
                    <AssessmentRow label="Scan Date">{formatScannedDate(row.scanned_at)}</AssessmentRow>
                  </dl>

                  <div className="mt-2 rounded-lg bg-[var(--color-surface-muted)] px-3 py-2">
                    <p className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                      Assessment Summary
                    </p>
                    <p className="mt-1 text-[11px] leading-relaxed text-[var(--color-text-primary)]">
                      {assessmentSummary}
                    </p>
                  </div>

                  <p className="mt-2 text-[11px] leading-snug text-[var(--color-text-muted)]">
                    {INTEGRITY_AI_DISCLAIMER}
                  </p>
                </section>

                <Collapsible title="Technical Details">
                  <ReviewScanTechnicalDetails row={row} />
                </Collapsible>

                {history.length > 0 ? (
                  <Collapsible title={`Review History (${history.length})`}>
                    <ul className="space-y-1.5">
                      {history.map((h) => (
                        <li key={h.id} className="rounded-lg bg-[var(--color-surface-muted)] px-3 py-2 text-xs">
                          <div className="font-semibold capitalize text-[var(--color-text-primary)]">
                            {h.new_status.replace(/_/g, ' ')}
                          </div>
                          {h.admin_remarks && (
                            <div className="text-[var(--color-text-secondary)]">{h.admin_remarks}</div>
                          )}
                          <div className="mt-0.5 text-[10px] text-[var(--color-text-muted)]">
                            {h.reviewed_by_name ?? 'Admin'} · {h.reviewed_at ?? ''}
                          </div>
                        </li>
                      ))}
                    </ul>
                  </Collapsible>
                ) : null}
              </div>
          </div>

          <form
            onSubmit={handleSubmit}
            className="shrink-0 space-y-1.5 border-t border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2"
          >
            <div className="flex flex-wrap items-center justify-between gap-x-2 gap-y-1">
              <div className="min-w-0">
                <h3 className="text-xs font-bold text-[var(--color-text-primary)]">Admin Decision</h3>
                {selectedActionLabel ? (
                  <p className="text-[10px] leading-snug text-[var(--color-text-secondary)]">
                    <span className="font-semibold text-[var(--color-text-primary)]">{selectedActionLabel}</span>
                    {' · '}
                    Save when ready.
                  </p>
                ) : null}
              </div>
              <div className="flex flex-wrap gap-1">
                {REVIEW_ACTIONS.map((a) => {
                  const active = selectedActionLabel === a.label && status === a.status
                  return (
                    <button
                      key={a.status}
                      type="button"
                      disabled={saving}
                      onClick={() => applyQuickAction(a)}
                      aria-pressed={active}
                      className="rounded-md border px-2 py-1 text-[10px] font-bold leading-tight transition hover:brightness-95 disabled:opacity-50 sm:text-[11px]"
                      style={{
                        color: a.color,
                        borderColor: active ? a.color : tint(a.color, 45),
                        backgroundColor: tint(a.color, active ? 20 : 7),
                        boxShadow: active ? `0 0 0 2px ${tint(a.color, 25)}` : undefined,
                      }}
                    >
                      {a.label}
                    </button>
                  )
                })}
              </div>
            </div>

            <div className="flex flex-col gap-1.5 md:flex-row md:items-end md:gap-2">
              <label className="block min-w-0 flex-1 text-[10px] font-bold text-[var(--color-text-secondary)]">
                Admin Feedback (optional)
                <textarea
                  ref={remarksRef}
                  value={remarks}
                  onChange={(e) => {
                    setRemarks(e.target.value)
                    if (error) setError(null)
                  }}
                  rows={1}
                  placeholder={
                    remarksExample
                      ? `Optional note for the member. Example: ${remarksExample}`
                      : 'Optional note for the member about this review.'
                  }
                  className="mt-0.5 max-h-16 w-full resize-none rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-2.5 py-1.5 text-xs font-normal outline-none focus:border-[var(--color-accent-cyan)]"
                />
              </label>
              <div className="flex shrink-0 gap-1.5">
                <button
                  type="submit"
                  disabled={saving || !FINAL_REVIEW_STATUSES.includes(status)}
                  title={
                    FINAL_REVIEW_STATUSES.includes(status)
                      ? undefined
                      : 'Choose Verify as Human, Confirm AI / Manipulated, or Request Re-upload first'
                  }
                  className="inline-flex items-center justify-center gap-1.5 rounded-lg bg-[var(--color-accent-blue)] px-3 py-1.5 text-xs font-bold text-white disabled:opacity-60"
                >
                  {saving && <Loader2 size={12} className="animate-spin" />}
                  Save Review
                </button>
                <button
                  type="button"
                  onClick={requestArchive}
                  disabled={saving}
                  className="inline-flex items-center gap-1 rounded-lg border border-[var(--color-border)] px-2.5 py-1.5 text-xs font-semibold text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]"
                >
                  <Archive size={12} />
                  Archive
                </button>
              </div>
            </div>
            {error && <div className="text-xs text-[var(--color-danger)]">{error}</div>}
          </form>
        </div>
      </div>

      <AdminConfirmDialog
        open={confirm != null}
        title={confirm?.title ?? ''}
        message={confirm?.message ?? ''}
        tone={confirm?.tone}
        loading={saving}
        confirmLabel="Confirm"
        onConfirm={() => confirm?.onConfirm()}
        onCancel={() => !saving && setConfirm(null)}
      />

      {showFullMedia && previewUrl && (
        <MediaLightbox
          url={previewUrl}
          title={row.media_name}
          isVideo={isVideo}
          onClose={() => setShowFullMedia(false)}
        />
      )}
    </>
  )
}
