import type {
  AiDetectionRow,
  AiDetectionSummary,
  AiResultLabel,
  ConfidenceLevel,
  ExifMetadata,
  ExifMetadataField,
  ExifMetadataFlag,
  ReviewStatus,
} from '../api/media'
import { isVideoMedia } from '../api/media'

export function aiLabelForResult(raw?: string | null): AiResultLabel {
  if (!raw) return 'pending'
  const n = raw.toLowerCase().replace(/ /g, '_')
  if (n.includes('ai') || n.includes('generated')) return 'ai_generated'
  if (n.includes('suspicious')) return 'suspicious'
  if (n.includes('human') || n.includes('authentic')) return 'human'
  return 'pending'
}

/** Match backend SUSPICIOUS_THRESHOLD in ai_authenticity_detector.py (0.36). */
const SUSPICIOUS_SYNTHETIC_THRESHOLD = 0.36

export function aiLabelForDetection(raw?: string | null, aiProb = 0): AiResultLabel {
  const base = aiLabelForResult(raw)
  if (base === 'human' && aiProb >= SUSPICIOUS_SYNTHETIC_THRESHOLD) return 'suspicious'
  return base
}

export function confidenceLevelForScore(score: number): ConfidenceLevel {
  const pct = score * 100
  if (pct >= 80) return 'high'
  if (pct >= 50) return 'medium'
  return 'low'
}

export function parseReviewStatus(raw?: string | null): ReviewStatus {
  if (!raw) return 'pending_review'
  const n = raw.toLowerCase()
  if (n.includes('automated_low') || n === 'automated_low_ai_risk') return 'automated_low_ai_risk'
  if (n.includes('verified_human') || n === 'verified human') return 'verified_human'
  if (n.includes('confirmed_ai') || n.includes('verified_ai')) return 'confirmed_ai_generated'
  if (n.includes('accepted') && n.includes('warning')) return 'accepted_with_warning'
  if (n.includes('reupload')) return 'reupload_requested'
  if (n.includes('reject')) return 'rejected'
  if (n.includes('further') || n.includes('suspicious') || n.includes('needs')) {
    return 'needs_further_review'
  }
  return 'pending_review'
}

export function reviewStatusLabel(s: ReviewStatus): string {
  const labels: Record<ReviewStatus, string> = {
    pending_review: 'Pending Review',
    verified_human: 'Verified Human',
    confirmed_ai_generated: 'Confirmed AI-Generated',
    needs_further_review: 'Suspicious / Needs Further Review',
    accepted_with_warning: 'Accepted with Warning',
    reupload_requested: 'Reupload Requested',
    rejected: 'Rejected',
    automated_low_ai_risk: 'Low AI risk (auto)',
  }
  return labels[s]
}

export function aiResultLabelText(label: AiResultLabel): string {
  const map: Record<AiResultLabel, string> = {
    human: 'Human',
    ai_generated: 'AI Generated',
    suspicious: 'Suspicious',
    pending: 'Pending',
  }
  return map[label]
}

function parseExifMetadata(raw: unknown): ExifMetadata | undefined {
  if (!raw || typeof raw !== 'object') return undefined
  const m = raw as Record<string, unknown>
  const fieldsRaw = Array.isArray(m.fields) ? m.fields : []
  const flagsRaw = Array.isArray(m.flags) ? m.flags : []

  const fields: ExifMetadataField[] = fieldsRaw
    .map((item) => {
      if (!item || typeof item !== 'object') return null
      const f = item as Record<string, unknown>
      const key = String(f.key ?? '')
      const label = String(f.label ?? key)
      const value = String(f.value ?? '').trim()
      if (!key || !value) return null
      return { key, label, value }
    })
    .filter((f): f is ExifMetadataField => f != null)

  const flags: ExifMetadataFlag[] = flagsRaw
    .map((item) => {
      if (!item || typeof item !== 'object') return null
      const f = item as Record<string, unknown>
      const code = String(f.code ?? '')
      const label = String(f.label ?? '')
      const severity = String(f.severity ?? 'info')
      if (!code || !label) return null
      const sev =
        severity === 'danger' || severity === 'warning' || severity === 'info'
          ? severity
          : 'info'
      return { code, label, severity: sev }
    })
    .filter((f): f is ExifMetadataFlag => f != null)

  const reasonsRaw = m.camera_provenance_reasons
  const reasons = Array.isArray(reasonsRaw)
    ? reasonsRaw.map((r) => String(r)).filter(Boolean)
    : undefined

  return {
    has_exif: Boolean(m.has_exif),
    is_video: m.is_video != null ? Boolean(m.is_video) : undefined,
    format: m.format != null ? String(m.format) : null,
    field_count: Number(m.field_count ?? fields.length),
    fields,
    flags,
    summary: m.summary != null ? String(m.summary) : undefined,
    camera_provenance_strength:
      m.camera_provenance_strength != null ? String(m.camera_provenance_strength) : undefined,
    camera_provenance_reasons: reasons,
    visual_risk_level: m.visual_risk_level != null ? String(m.visual_risk_level) : undefined,
    provenance_policy_outcome:
      m.provenance_policy_outcome != null ? String(m.provenance_policy_outcome) : undefined,
    visual_ai_probability:
      m.visual_ai_probability != null ? Number(m.visual_ai_probability) : undefined,
  }
}

export function parseAiDetectionRow(m: Record<string, unknown>): AiDetectionRow {
  const aiProb = Number(m.ai_probability ?? 0)
  const result = String(m.ai_result ?? m.detection_result ?? '')
  const label = aiLabelForDetection(result, aiProb)
  const conf = Number(m.confidence_score ?? (label === 'ai_generated' ? aiProb : 1 - aiProb))

  return {
    id: Number(m.id ?? 0),
    media_id: Number(m.media_id ?? 0),
    media_name: String(m.media_name ?? m.file_name ?? 'Untitled'),
    media_url: String(m.media_url ?? m.file_url ?? ''),
    file_type: m.file_type != null ? String(m.file_type) : undefined,
    member_name: String(m.member_name ?? m.uploader_name ?? 'Unknown'),
    member_id: m.member_id != null ? Number(m.member_id) : undefined,
    ai_result: result,
    ai_probability: aiProb,
    confidence_score: conf,
    confidence_level: String(m.confidence_level ?? confidenceLevelForScore(conf)) as ConfidenceLevel,
    review_status: parseReviewStatus(String(m.review_status ?? '')),
    admin_remarks: m.admin_remarks != null ? String(m.admin_remarks) : undefined,
    detection_remarks: m.detection_remarks != null ? String(m.detection_remarks) : undefined,
    exif_metadata: parseExifMetadata(m.exif_metadata),
    reviewed_by_admin: Boolean(m.reviewed_by_admin),
    scanned_at: m.scanned_at != null ? String(m.scanned_at) : m.created_at != null ? String(m.created_at) : undefined,
    ai_label: label,
    confidence_text: confidenceText(label, conf),
  }
}

function confidenceText(label: AiResultLabel, score: number): string {
  const pct = Math.round(score * 100)
  switch (label) {
    case 'ai_generated':
      return `${pct}% AI-generated confidence`
    case 'suspicious':
      return `${pct}% Suspicious confidence`
    case 'pending':
      return 'Pending scan'
    default:
      return `${pct}% Human confidence`
  }
}

export function formatScannedDate(iso?: string): string {
  if (!iso) return 'N/A'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return 'N/A'
  return new Intl.DateTimeFormat(undefined, {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  }).format(d)
}

export function summaryFromRows(rows: AiDetectionRow[]): AiDetectionSummary {
  let human = 0
  let ai = 0
  let suspicious = 0
  let pending = 0
  for (const r of rows) {
    if (r.ai_label === 'human') human++
    else if (r.ai_label === 'ai_generated') ai++
    else if (r.ai_label === 'suspicious') suspicious++
    if (r.review_status === 'pending_review' || r.review_status === 'needs_further_review') pending++
  }
  return {
    total_scanned: rows.length,
    human_count: human,
    ai_generated_count: ai,
    suspicious_count: suspicious,
    pending_review_count: pending,
  }
}

export type IntegrityInboxFilter =
  | 'needs_action'
  | 'all'
  | 'human'
  | 'suspicious'
  | 'ai_generated'
  | 'pending_scan'
  | 'resolved'

const RESOLVED_STATUSES: ReviewStatus[] = [
  'verified_human',
  'confirmed_ai_generated',
  'verified_ai_generated',
  'accepted_with_warning',
  'reupload_requested',
  'rejected',
  'automated_low_ai_risk',
]

export function isResolvedIntegrityReview(status: ReviewStatus): boolean {
  return RESOLVED_STATUSES.includes(status)
}

export type AiReviewRiskTier = 'high' | 'suspicious' | 'low'

export function aiReviewRiskTier(row: AiDetectionRow): AiReviewRiskTier {
  const risk = String(row.exif_metadata?.visual_risk_level ?? '').toLowerCase()
  if (row.ai_label === 'ai_generated' || risk === 'high') return 'high'
  if (row.ai_label === 'suspicious') return 'suspicious'
  return 'low'
}

export function aiReviewRiskLabel(tier: AiReviewRiskTier): string {
  if (tier === 'high') return 'High Risk'
  if (tier === 'suspicious') return 'Suspicious'
  return 'Low Risk'
}

export function matchesIntegrityInbox(row: AiDetectionRow, filter: IntegrityInboxFilter): boolean {
  if (filter === 'all') return true
  if (filter === 'needs_action') {
    return row.review_status === 'pending_review' || row.review_status === 'needs_further_review'
  }
  if (filter === 'resolved') return RESOLVED_STATUSES.includes(row.review_status)
  if (filter === 'human') return row.ai_label === 'human'
  if (filter === 'suspicious') return row.ai_label === 'suspicious'
  if (filter === 'ai_generated') return row.ai_label === 'ai_generated'
  if (filter === 'pending_scan') return row.ai_label === 'pending'
  return true
}

export function sortDetectionRows(rows: AiDetectionRow[]): AiDetectionRow[] {
  return [...rows].sort((a, b) => {
    const ta = a.scanned_at ? new Date(a.scanned_at).getTime() : 0
    const tb = b.scanned_at ? new Date(b.scanned_at).getTime() : 0
    return tb - ta
  })
}

export function isVideoDetectionRow(row: AiDetectionRow): boolean {
  if (row.exif_metadata?.is_video != null) return row.exif_metadata.is_video
  return isVideoMedia(row.file_type, row.media_name, row.media_url)
}

export type IntegrityFormatFilter = 'all' | 'photos' | 'videos'

/** Display name prefix for backend PROBE E2E smoke uploads (see smoke_probe_step8a/b.py). */
export const PROBE_SMOKE_MEDIA_PREFIX = 'PROBE smoke'

const LEGACY_PROBE_SMOKE_NAME = /^step8[ab]\b/i

/** PROBE smoke tests and legacy Step8A/Step8B upload names from the same scripts. */
export function isProbeSmokeTestRow(row: Pick<AiDetectionRow, 'media_name'>): boolean {
  const name = row.media_name.trim()
  if (!name) return false
  if (name.toLowerCase().startsWith(PROBE_SMOKE_MEDIA_PREFIX.toLowerCase())) return true
  return LEGACY_PROBE_SMOKE_NAME.test(name)
}
