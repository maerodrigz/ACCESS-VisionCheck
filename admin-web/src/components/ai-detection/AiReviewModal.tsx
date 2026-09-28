import { useEffect, useRef, useState, type FormEvent } from 'react'
import { Archive, Loader2, Maximize2 } from 'lucide-react'
import { DrawerBackButton } from '../AdminBackButton'
import { AdminConfirmDialog } from '../AdminConfirmDialog'
import { MediaPipelineLinks } from '../AdminCrossLinks'
import { AdminSelect } from '../AdminSelect'
import { MediaLightbox } from '../MediaLightbox'
import {
  archiveAiDetectionMedia,
  fetchAiReviewHistory,
  updateAiDetectionReview,
} from '../../api/admin'
import type { AiDetectionRow, AiReviewHistoryEntry, ReviewStatus } from '../../api/media'
import { adminMediaStreamUrl, isVideoMediaPath, mediaUrl } from '../../api/media'
import { MediaPreviewContent } from '../media-library/MediaPreviewContent'
import { formatScannedDate, reviewStatusLabel } from '../../lib/aiDetection'
import { AiResultBadge, ConfidenceBar, ReviewStatusBadge } from './Badges'
import { ExifMetadataPanel } from './ExifMetadataPanel'

const REVIEW_ACTIONS: {
  status: ReviewStatus
  label: string
  exampleRemarks: string
  confirm?: { title: string; message: string; tone?: 'default' | 'danger' | 'success' }
}[] = [
  {
    status: 'verified_human',
    label: 'Verify as Human',
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
    exampleRemarks: 'Please upload a new original photo or video.',
  },
]

const FINAL_REVIEW_STATUSES: ReviewStatus[] = [
  'verified_human',
  'confirmed_ai_generated',
  'reupload_requested',
]

interface Props {
  row: AiDetectionRow
  onClose: () => void
  onSaved: () => void
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
      onSaved()
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
        remarksRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' })
      })
    }
    if (action.confirm) {
      setConfirm({
        title: action.confirm.title,
        message: `${action.confirm.message} You can add optional feedback for the member, then click Save review. This panel stays open until then.`,
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
      onSaved()
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Archive failed')
    } finally {
      setSaving(false)
    }
  }

  const previewUrl = row.media_id ? adminMediaStreamUrl(row.media_id) : mediaUrl(row.media_url)
  const openUrl = mediaUrl(row.media_url) || previewUrl
  const isVideo =
    isVideoMediaPath(row.media_name) ||
    isVideoMediaPath(row.media_url) ||
    row.file_type?.toLowerCase().includes('video') === true

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
        <div className="flex max-h-[90vh] w-full max-w-2xl flex-col overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] shadow-xl">
          <div className="sticky top-0 flex items-center gap-2 border-b border-[var(--color-border)] bg-[var(--color-surface)] px-5 py-4">
            <DrawerBackButton onClick={onClose} label="Back" />
            <div className="min-w-0 flex-1">
              <h2 className="text-lg font-extrabold text-[var(--color-text-primary)]">Review scan</h2>
              <p className="text-xs text-[var(--color-text-secondary)]">{row.media_name} · {row.member_name}</p>
            </div>
          </div>

          <div className="space-y-5 overflow-y-auto p-5">
            <div className="space-y-3">
              {previewUrl ? (
                <div className="overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)]">
                  <MediaPreviewContent
                    url={previewUrl}
                    isVideo={isVideo}
                    fileName={row.media_name}
                    fileType={row.file_type}
                    mode="preview"
                    className="max-w-full"
                  />
                  <div className="flex flex-wrap items-center justify-between gap-2 border-t border-[var(--color-border)] px-3 py-2">
                    <p className="text-[10px] text-[var(--color-text-secondary)]">
                      {isVideo ? 'Use video controls to play' : 'Scroll or pinch in full-screen inspect'}
                    </p>
                    <button
                      type="button"
                      onClick={() => setShowFullMedia(true)}
                      className="inline-flex items-center gap-1.5 rounded-lg border border-[var(--color-border)] px-2.5 py-1.5 text-[11px] font-semibold text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]"
                    >
                      <Maximize2 size={14} />
                      Full screen
                    </button>
                  </div>
                </div>
              ) : (
                <div className="rounded-xl border border-dashed border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-8 text-center text-xs text-[var(--color-text-secondary)]">
                  Preview unavailable (missing media file URL).
                </div>
              )}
              <div className="space-y-2">
                <div className="flex flex-wrap gap-2">
                  <AiResultBadge label={row.ai_label} />
                  <ReviewStatusBadge status={row.review_status} />
                </div>
                <p className="text-xs text-[var(--color-text-secondary)]">Scanned {formatScannedDate(row.scanned_at)}</p>
                <ConfidenceBar
                  score={row.confidence_score}
                  label={row.confidence_text}
                  level={row.confidence_level}
                />
              </div>
            </div>

            {openUrl ? (
              <p className="text-[11px] text-[var(--color-text-muted)]">
                Direct file link:{' '}
                <a href={openUrl} target="_blank" rel="noreferrer" className="font-semibold text-[var(--color-accent-blue)]">
                  Open original
                </a>
              </p>
            ) : null}

            {row.detection_remarks && (
              <div className="rounded-xl bg-[var(--color-surface-muted)] px-4 py-3 text-sm text-[var(--color-text-secondary)]">
                <div className="mb-1 text-xs font-bold uppercase tracking-wide text-[var(--color-text-primary)]">
                  Detection notes
                </div>
                {row.detection_remarks}
              </div>
            )}

            <ExifMetadataPanel metadata={row.exif_metadata} />

            <MediaPipelineLinks
              mediaId={row.media_id}
              uploaderName={row.member_name}
              showIntegrity
              onNavigate={onClose}
            />

            <form onSubmit={handleSubmit} className="space-y-3 border-t border-[var(--color-border)] pt-4">
              <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
                Admin feedback (optional)
                <textarea
                  ref={remarksRef}
                  value={remarks}
                  onChange={(e) => {
                    setRemarks(e.target.value)
                    if (error) setError(null)
                  }}
                  rows={4}
                  placeholder={
                    remarksExample
                      ? `Optional note for the member. Example: ${remarksExample}`
                      : 'Optional note for the member about this review.'
                  }
                  className="mt-1.5 w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2 text-sm outline-none focus:border-[var(--color-accent-cyan)]"
                />
              </label>
              {selectedActionLabel ? (
                <p className="rounded-lg border border-[var(--color-accent-cyan)]/30 bg-[var(--color-surface-muted)] px-3 py-2 text-xs text-[var(--color-text-secondary)]">
                  Quick action <span className="font-semibold text-[var(--color-text-primary)]">{selectedActionLabel}</span>{' '}
                  selected. Confirm status below if needed, optionally add a note, then Save review. This panel stays open until you save or go back.
                </p>
              ) : null}
              <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
                Review status
                <div className="mt-1.5">
                  <AdminSelect
                    value={status}
                    onChange={(v) => setStatus(v as ReviewStatus)}
                    aria-label="Review status"
                    options={(
                      [
                        'pending_review',
                        'needs_further_review',
                        'automated_low_ai_risk',
                        ...FINAL_REVIEW_STATUSES,
                        'accepted_with_warning',
                        'rejected',
                      ] as ReviewStatus[]
                    ).map((s) => ({ value: s, label: reviewStatusLabel(s) }))}
                  />
                </div>
              </label>
              <div>
                <div className="mb-2 text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                  Quick actions
                </div>
                <p className="mb-2 text-[11px] text-[var(--color-text-muted)]">
                  Choose a final decision, optionally add a note, then Save review. Historical statuses remain readable on old records.
                </p>
                <div className="flex flex-wrap gap-2">
                  {REVIEW_ACTIONS.map((a) => {
                    const active = selectedActionLabel === a.label && status === a.status
                    return (
                      <button
                        key={`${a.label}-${a.status}`}
                        type="button"
                        disabled={saving}
                        onClick={() => applyQuickAction(a)}
                        className={`rounded-lg border px-3 py-1.5 text-[11px] font-semibold disabled:opacity-50 ${
                          active
                            ? 'border-[var(--color-accent-blue)] bg-[var(--color-accent-blue)]/10 text-[var(--color-accent-blue)]'
                            : 'border-[var(--color-border)] text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]'
                        }`}
                      >
                        {a.label}
                      </button>
                    )
                  })}
                </div>
              </div>
              {error && <div className="text-sm text-red-600">{error}</div>}
              <div className="flex flex-wrap gap-2">
                <button
                  type="submit"
                  disabled={saving || !FINAL_REVIEW_STATUSES.includes(status)}
                  className="inline-flex items-center gap-2 rounded-xl bg-[var(--color-accent-blue)] px-4 py-2 text-sm font-bold text-white disabled:opacity-60"
                >
                  {saving && <Loader2 size={14} className="animate-spin" />}
                  Save review
                </button>
                <button
                  type="button"
                  onClick={requestArchive}
                  disabled={saving}
                  className="inline-flex items-center gap-2 rounded-xl border border-[var(--color-border)] px-4 py-2 text-sm font-semibold text-[var(--color-text-secondary)]"
                >
                  <Archive size={14} />
                  Archive
                </button>
              </div>
            </form>

            {history.length > 0 && (
              <div>
                <div className="mb-2 text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                  Review history
                </div>
                <ul className="space-y-2">
                  {history.map((h) => (
                    <li key={h.id} className="rounded-lg bg-[var(--color-surface-muted)] px-3 py-2 text-xs">
                      <div className="font-semibold text-[var(--color-text-primary)]">
                        {h.new_status.replace(/_/g, ' ')}
                      </div>
                      {h.admin_remarks && (
                        <div className="text-[var(--color-text-secondary)]">{h.admin_remarks}</div>
                      )}
                      <div className="mt-1 text-[10px] text-[var(--color-text-muted)]">
                        {h.reviewed_by_name ?? 'Admin'} · {h.reviewed_at ?? ''}
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>
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
