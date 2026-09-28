import { Link } from 'react-router-dom'
import { ShieldAlert, UserCircle } from 'lucide-react'
import { mediaIntegrityUrl, memberPortfolioUrl } from '../lib/adminCrossLinks'

const linkClass =
  'inline-flex items-center gap-1.5 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-1.5 text-[11px] font-semibold text-[var(--color-accent-blue)] hover:bg-[var(--color-surface-hover)]'

const warnLinkClass =
  'inline-flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-[11px] font-semibold hover:opacity-95 admin-alert--warning'

interface MediaPipelineLinksProps {
  mediaId: number
  uploadedBy?: number | null
  uploaderName?: string
  /** When true, show Media Integrity link (AI flagged). */
  showIntegrity?: boolean
  onNavigate?: () => void
}

/** Member upload + integrity deep links for flagged media. */
export function MediaPipelineLinks({
  mediaId,
  uploadedBy = null,
  uploaderName = '',
  showIntegrity = false,
  onNavigate,
}: MediaPipelineLinksProps) {
  if (!mediaId) return null
  const portfolioTo = memberPortfolioUrl({ userId: uploadedBy, memberName: uploaderName })

  return (
    <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3">
      <p className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
        Media pipeline
      </p>
      <p className="mt-1 text-[11px] leading-relaxed text-[var(--color-text-secondary)]">
        Open the member competency portfolio or Media Integrity when AI flags this file.
      </p>
      <div className="mt-2 flex flex-wrap gap-1.5">
        <Link to={portfolioTo} onClick={onNavigate} className={linkClass}>
          <UserCircle size={12} />
          Member portfolio
        </Link>
        {showIntegrity ? (
          <Link to={mediaIntegrityUrl(mediaId)} onClick={onNavigate} className={warnLinkClass}>
            <ShieldAlert size={12} />
            Media Integrity
          </Link>
        ) : null}
      </div>
    </div>
  )
}
