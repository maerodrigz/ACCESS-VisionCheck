import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { Calendar, FileText, FolderOpen } from 'lucide-react'
import { AdminDrawer } from '../AdminDrawer'
import { DrawerBackButton } from '../AdminBackButton'
import { MediaPipelineLinks } from '../AdminCrossLinks'
import { documentationRequestUrl, eventCalendarUrl, memberPortfolioUrl } from '../../lib/adminCrossLinks'
import { canPublishToFacebook, type MediaAsset } from '../../lib/mediaLibrary'
import { facebookPostUrl } from '../../lib/facebookShare'
import { MediaPreviewContent } from './MediaPreviewContent'

interface Props {
  item: MediaAsset | null
  isAdmin: boolean
  publishing?: boolean
  integrityFlagged?: boolean
  onClose: () => void
  onDownload: () => void
  onMoveToAlbum: () => void
  onArchive: () => void
  onDelete: () => void
  onToggleBestShot: () => void
  onPublishFacebook: () => void
}

export function MediaPreviewDrawer({
  item,
  isAdmin,
  publishing = false,
  integrityFlagged = false,
  onClose,
  onDownload,
  onMoveToAlbum,
  onArchive,
  onDelete,
  onToggleBestShot,
  onPublishFacebook,
}: Props) {
  if (!item) return null
  const m = item
  const isEventDoc = m.mediaCategory === 'event_documentation'
  const isMemberEval = m.mediaCategory === 'member_evaluation'
  const canPublish = canPublishToFacebook(m)
  const facebookViewUrl = facebookPostUrl(m.facebookPostId)

  return (
    <AdminDrawer
      open
      onClose={onClose}
      title={m.fileName}
      maxWidth="lg"
      bodyClassName="px-5 pb-5"
      header={
        <div className="flex items-center gap-2 border-b border-[var(--color-border)] px-5 py-4">
          <DrawerBackButton onClick={onClose} label="Back" />
          <div className="min-w-0 flex-1 pr-2">
            <h2 className="truncate text-base font-extrabold text-[var(--color-text-primary)]">{m.fileName}</h2>
            <p className="mt-0.5 text-[10px] font-semibold uppercase tracking-wide text-[var(--color-text-secondary)]">
              {isEventDoc ? 'Event Documentation' : 'Member Evaluation'}
            </p>
          </div>
        </div>
      }
    >
          <div className="overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)]">
            <MediaPreviewContent
              url={m.thumbnailUrl}
              isVideo={m.isVideo}
              fileName={m.fileName}
              mode="preview"
            />
          </div>

          {isEventDoc && (
            <Section title="Event information">
              <InfoRow label="Event name" value={m.eventName} />
              {m.eventDate && <InfoRow label="Event date" value={m.eventDate} />}
              {m.eventDescription && <InfoRow label="Description" value={m.eventDescription} />}
              <InfoRow label="Album" value={m.albumName} />
              <InfoRow label="Upload date" value={m.uploadDateLabel ?? '—'} />
              {m.requestId ? (
                <div className="mt-2 flex flex-wrap gap-1.5">
                  <Link
                    to={documentationRequestUrl(m.requestId)}
                    onClick={onClose}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-1.5 text-[11px] font-semibold text-[var(--color-accent-blue)] hover:bg-[var(--color-surface-hover)]"
                  >
                    <FileText size={12} />
                    Open request
                  </Link>
                  <Link
                    to={eventCalendarUrl({ requestId: m.requestId })}
                    onClick={onClose}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-1.5 text-[11px] font-semibold text-[var(--color-accent-blue)] hover:bg-[var(--color-surface-hover)]"
                  >
                    <Calendar size={12} />
                    View on calendar
                  </Link>
                </div>
              ) : null}
            </Section>
          )}

          <Section title="Media details">
            <InfoRow label="File name" value={m.fileName} />
            <InfoRow label="File type" value={m.mediaTypeLabel} />
            <InfoRow label="Resolution" value={m.resolutionLabel} />
            <InfoRow label="File size" value={m.estimatedFileSize} />
          </Section>

          <Section title="Uploader">
            <div className="mb-2 flex gap-3 text-xs">
              <span className="w-28 shrink-0 text-[var(--color-text-secondary)]">{m.uploaderRoleLabel}</span>
              <Link
                to={memberPortfolioUrl({ userId: m.uploadedBy, memberName: m.uploaderName })}
                onClick={onClose}
                className="font-semibold text-[var(--color-accent-blue)] hover:underline"
              >
                {m.uploaderName}
              </Link>
            </div>
          </Section>

          {isEventDoc && (
            <Section title="Facebook">
              <InfoRow label="Best pick" value={m.isBestShot ? 'Yes — eligible to publish' : 'No'} />
              <InfoRow label="Facebook status" value={m.publishedStatusLabel} />
              {m.facebookPublishedAt && (
                <InfoRow label="Published at" value={m.facebookPublishedAt.toLocaleString()} />
              )}
              {m.facebookPostId && <InfoRow label="Facebook post ID" value={m.facebookPostId} />}
            </Section>
          )}

          {isMemberEval && (
            <>
              <div className="admin-alert--warning mt-3 rounded-lg px-3 py-2 text-xs">
                Member evaluation media is used for quality scoring and competency feedback only. It is never published
                to Facebook.
              </div>
              <MediaPipelineLinks
                mediaId={m.id}
                uploadedBy={m.uploadedBy}
                uploaderName={m.uploaderName}
                showIntegrity={integrityFlagged}
                onNavigate={onClose}
              />
            </>
          )}

          {m.facebookPublishStatus === 'published' && isEventDoc && (
            <div className="mt-3 space-y-2">
              <div className="flex items-center gap-2 rounded-lg border border-blue-500/30 bg-blue-500/10 px-3 py-2 text-xs font-semibold text-[#1877F2]">
                <FacebookIcon />
                Published to Facebook
              </div>
              {facebookViewUrl && (
                <a
                  href={facebookViewUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2 text-xs font-semibold text-[var(--color-accent-blue)] hover:underline"
                >
                  View post on Facebook
                </a>
              )}
            </div>
          )}

          {!m.isBestShot && isEventDoc && isAdmin && (
            <div className="mt-3 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2 text-xs text-[var(--color-text-secondary)]">
              Mark this as a best pick before publishing to Facebook.
            </div>
          )}

          <div className="mt-5 flex flex-wrap gap-2">
            <ActionBtn label="Download" onClick={onDownload} />
            {isEventDoc && (
              <ActionBtn label="Move to Album" onClick={onMoveToAlbum} icon={<FolderOpen size={14} />} />
            )}
            {isAdmin && (
              <>
                {isEventDoc && (
                  <ActionBtn
                    label={m.isBestShot ? 'Remove best pick' : 'Mark as best pick'}
                    onClick={onToggleBestShot}
                    accent
                  />
                )}
                {isEventDoc && canPublish && (
                  <ActionBtn
                    label={publishing ? 'Publishing…' : 'Publish to Facebook'}
                    onClick={onPublishFacebook}
                    facebook
                    disabled={publishing}
                  />
                )}
                <ActionBtn label="Archive" onClick={onArchive} />
                <ActionBtn label="Delete permanently" onClick={onDelete} danger />
              </>
            )}
          </div>
    </AdminDrawer>
  )
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="mt-4">
      <h4 className="text-sm font-bold text-[var(--color-text-primary)]">{title}</h4>
      <div className="mt-2">{children}</div>
    </div>
  )
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="mb-2 flex gap-3 text-xs">
      <span className="w-28 shrink-0 text-[var(--color-text-secondary)]">{label}</span>
      <span className="font-semibold text-[var(--color-text-primary)]">{value}</span>
    </div>
  )
}

function ActionBtn({
  label,
  onClick,
  icon,
  danger,
  facebook,
  accent,
  disabled,
}: {
  label: string
  onClick: () => void
  icon?: ReactNode
  danger?: boolean
  facebook?: boolean
  accent?: boolean
  disabled?: boolean
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={[
        'inline-flex items-center gap-1.5 rounded-lg border px-3 py-2 text-xs font-semibold disabled:opacity-50',
        facebook
          ? 'border-[#1877F2] bg-[#1877F2] text-white hover:bg-[#166fe5]'
          : accent
            ? 'border-[color-mix(in_srgb,var(--color-success)_35%,transparent)] bg-[color-mix(in_srgb,var(--color-success)_10%,transparent)] text-[var(--color-success-text)] hover:opacity-95'
            : danger
              ? 'border-[color-mix(in_srgb,var(--color-danger)_35%,transparent)] text-[var(--color-danger-text)] hover:bg-[color-mix(in_srgb,var(--color-danger)_10%,transparent)]'
              : 'border-[var(--color-border)] bg-[var(--color-surface-elevated)] text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]',
      ].join(' ')}
    >
      {facebook ? <FacebookIcon size={14} /> : icon}
      {label}
    </button>
  )
}

function FacebookIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
    </svg>
  )
}
