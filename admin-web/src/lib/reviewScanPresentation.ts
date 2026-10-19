import type { AiDetectionRow, ExifMetadata, ExifMetadataField, ReviewStatus } from '../api/media'
import { reviewStatusLabel } from './aiDetection'

export type VisualRiskBand = 'LOW' | 'SUSPICIOUS' | 'HIGH'

export type CameraMetadataStatus = 'Present' | 'Partial' | 'Missing' | 'Unknown'

const MANUAL_REVIEW_STATUSES: ReviewStatus[] = ['pending_review', 'needs_further_review']

/** PROBE visual risk band — detector only (not filename / provenance queue rules). */
export function detectorAiRiskBand(row: AiDetectionRow): VisualRiskBand {
  const level = String(row.exif_metadata?.visual_risk_level ?? '').toLowerCase()
  if (level === 'high') return 'HIGH'
  if (level === 'suspicious') return 'SUSPICIOUS'
  if (level === 'low') return 'LOW'
  const p = row.exif_metadata?.visual_ai_probability
  if (p != null && !Number.isNaN(p)) {
    if (p >= 0.45) return 'HIGH'
    if (p >= 0.3) return 'SUSPICIOUS'
    return 'LOW'
  }
  return 'LOW'
}

/** @deprecated Prefer detectorAiRiskBand for assessment UI. */
export function visualAiRiskBand(row: AiDetectionRow): VisualRiskBand {
  return detectorAiRiskBand(row)
}

export function visualAiRiskColor(band: VisualRiskBand): string {
  if (band === 'HIGH') return 'var(--color-danger)'
  if (band === 'SUSPICIOUS') return 'var(--color-warning)'
  return 'var(--color-success)'
}

/** PROBE raw P(fake) from persisted metadata (not legacy classifier probability). */
export function probeRawPFakePercent(row: AiDetectionRow): string | null {
  const probe = row.exif_metadata?.visual_ai_probability
  if (probe != null && !Number.isNaN(probe)) {
    return `${Math.round(Math.min(1, Math.max(0, probe)) * 100)}%`
  }
  return null
}

export function detectorAiRiskSummaryLabel(row: AiDetectionRow): string {
  const band = detectorAiRiskBand(row)
  const word = band.charAt(0) + band.slice(1).toLowerCase()
  const pct = probeRawPFakePercent(row)
  return pct ? `${word} (${pct} P(fake))` : word
}

/** @deprecated Prefer detectorAiRiskSummaryLabel. */
export function visualAiRiskSummaryLabel(row: AiDetectionRow): string {
  return detectorAiRiskSummaryLabel(row)
}

export interface SourceVerificationDisplay {
  status: 'Verified' | 'Partially verified' | 'Requires review' | 'Unknown'
  detail: string
  color: string
}

/** Source / provenance verification — separate from PROBE AI-generation risk. */
export function sourceVerificationDisplay(row: AiDetectionRow): SourceVerificationDisplay {
  const outcome = (row.exif_metadata?.provenance_policy_outcome ?? '').trim().toLowerCase()
  const cam = cameraMetadataStatus(row.exif_metadata)

  if (outcome === 'source_unverified') {
    return {
      status: 'Requires review',
      detail: 'File source could not be verified from metadata.',
      color: 'var(--color-warning)',
    }
  }
  if (outcome === 'source_partially_verified' || cam === 'Partial') {
    return {
      status: 'Partially verified',
      detail: 'Some device or container metadata is present, but not full in-camera proof.',
      color: 'var(--color-warning)',
    }
  }
  if (outcome === 'low_ai_risk' || cam === 'Present') {
    return {
      status: 'Verified',
      detail: 'Provenance checks passed under current policy (does not prove image authenticity).',
      color: 'var(--color-success)',
    }
  }
  if (cam === 'Missing') {
    return {
      status: 'Requires review',
      detail: 'Camera-identifying metadata is missing or incomplete.',
      color: 'var(--color-warning)',
    }
  }
  return {
    status: 'Unknown',
    detail: 'Limited provenance data for this file.',
    color: 'var(--color-text-secondary)',
  }
}

export interface AdminDecisionDisplay {
  label: string
  pending: boolean
  color: string
}

/** Admin workflow state from backend review_status (display only). */
export function adminDecisionDisplay(status: ReviewStatus): AdminDecisionDisplay {
  switch (status) {
    case 'pending_review':
    case 'needs_further_review':
      return { label: 'Pending', pending: true, color: 'var(--color-warning)' }
    case 'verified_human':
    case 'accepted_with_warning':
      return { label: 'Verified (human)', pending: false, color: 'var(--color-success)' }
    case 'confirmed_ai_generated':
    case 'verified_ai_generated':
      return { label: 'Confirmed AI / manipulated', pending: false, color: 'var(--color-danger)' }
    case 'reupload_requested':
      return { label: 'Re-upload requested', pending: false, color: 'var(--color-accent-blue)' }
    case 'rejected':
      return { label: 'Rejected', pending: false, color: 'var(--color-danger)' }
    case 'automated_low_ai_risk':
      return { label: 'Auto-cleared', pending: false, color: 'var(--color-success)' }
    default:
      return { label: reviewStatusLabel(status), pending: false, color: 'var(--color-text-secondary)' }
  }
}

/** Collapse EXIF padding and non-breaking spaces for readable admin copy (display only). */
export function normalizeScanDisplayText(raw: string): string {
  return raw
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function fieldHasValue(value: string): boolean {
  const v = normalizeScanDisplayText(value)
  return v.length > 0 && v !== '—' && v !== '-' && v.toLowerCase() !== 'n/a'
}

function findFieldValue(fields: ExifMetadataField[], keys: string[], labelIncludes: string[] = []): string | undefined {
  for (const f of fields) {
    const key = f.key.toLowerCase()
    const label = f.label.toLowerCase()
    const keyMatch = keys.some((k) => key === k.toLowerCase() || key.endsWith(`:${k.toLowerCase()}`))
    const labelMatch = labelIncludes.some((part) => label.includes(part.toLowerCase()))
    if (!keyMatch && !labelMatch) continue
    if (!fieldHasValue(f.value)) continue
    return normalizeScanDisplayText(f.value)
  }
  return undefined
}

function isVideoContainerMeta(meta: ExifMetadata): boolean {
  return meta.is_video === true || meta.format === 'video_container'
}

/** Camera-identifying metadata (photo EXIF or video container), display only. */
export function cameraMetadataStatus(meta?: ExifMetadata): CameraMetadataStatus {
  if (!meta) return 'Unknown'
  const strength = (meta.camera_provenance_strength ?? '').toLowerCase()
  if (strength === 'strong') return 'Present'
  if (strength === 'partial') return 'Partial'
  if (strength === 'absent') return 'Missing'
  const fields = meta.fields ?? []
  const make = findFieldValue(fields, ['Make', 'make'], ['camera make', 'manufacturer'])
  const model = findFieldValue(fields, ['Model', 'model'], ['camera model'])
  if (make && model) return 'Present'
  if (make || model) return 'Partial'
  if (!meta.has_exif || fields.length === 0) return 'Missing'
  if (isVideoContainerMeta(meta) && fields.length > 0) return 'Partial'
  return 'Unknown'
}

export interface CameraFileDisplayRow {
  label: string
  value: string
}

const EXIF_MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'] as const

function formatCaptureParts(year: string, month: number, day: number, hour24: number, minute: string): string {
  const monthIdx = Math.max(0, Math.min(11, month - 1))
  const ampm = hour24 >= 12 ? 'PM' : 'AM'
  const hour12 = hour24 % 12 || 12
  return `${EXIF_MONTHS[monthIdx]} ${day}, ${year} · ${hour12}:${minute} ${ampm}`
}

/** Format EXIF or ISO container datetime strings for display without timezone conversion. */
export function formatExifCaptureDate(raw: string): string {
  const text = normalizeScanDisplayText(raw)
  const exif = text.match(/^(\d{4}):(\d{2}):(\d{2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?/)
  if (exif) {
    return formatCaptureParts(exif[1], parseInt(exif[2], 10), parseInt(exif[3], 10), parseInt(exif[4], 10), exif[5])
  }
  const iso = text.match(/^(\d{4})-(\d{2})-(\d{2})[T\s](\d{2}):(\d{2})/)
  if (iso) {
    return formatCaptureParts(iso[1], parseInt(iso[2], 10), parseInt(iso[3], 10), parseInt(iso[4], 10), iso[5])
  }
  return text
}

function formatFileFormatLabel(meta: ExifMetadata): string | undefined {
  const format = meta.format ? normalizeScanDisplayText(meta.format) : ''
  if (!format || !fieldHasValue(format)) return undefined
  if (format === 'video_container') return 'Video container (MP4/MOV metadata)'
  return format
}

function capitalizeWord(raw: string): string {
  const t = raw.trim()
  if (!t) return t
  return t.charAt(0).toUpperCase() + t.slice(1).toLowerCase()
}

function parsePixelDimension(raw?: string): number | null {
  if (!raw) return null
  const match = normalizeScanDisplayText(raw).match(/(\d{2,5})/)
  if (!match) return null
  const n = parseInt(match[1], 10)
  return Number.isFinite(n) && n > 0 ? n : null
}

function formatImageResolution(widthRaw?: string, heightRaw?: string): string | null {
  const w = parsePixelDimension(widthRaw)
  const h = parsePixelDimension(heightRaw)
  if (w != null && h != null) return `${w} × ${h} px`
  if (w != null) return `Width: ${w} px`
  if (h != null) return `Height: ${h} px`
  return null
}

/** Admin-friendly camera and file fields extracted from stored EXIF (display only). */
export function cameraFileDisplayRows(meta?: ExifMetadata): CameraFileDisplayRow[] {
  if (!meta) return []

  const fields = meta.fields ?? []
  const rows: CameraFileDisplayRow[] = []
  const videoContainer = isVideoContainerMeta(meta)

  const make = findFieldValue(
    fields,
    ['Make', 'make', 'com.android.manufacturer'],
    ['camera make', 'manufacturer'],
  )
  const model = findFieldValue(fields, ['Model', 'model', 'com.android.model'], ['camera model'])
  const captureRaw = findFieldValue(
    fields,
    [
      'DateTimeOriginal',
      'DateTime',
      'DateTimeDigitized',
      'creation_time',
      'com.apple.quicktime.creationdate',
    ],
    ['date taken', 'file date', 'digitized', 'capture', 'creation'],
  )
  const software = findFieldValue(fields, ['Software'], ['software'])
  const handler = findFieldValue(fields, ['handler_name', 'encoder'], ['handler', 'encoder'])
  const widthRaw = findFieldValue(
    fields,
    ['ImageWidth', 'ExifImageWidth', 'PixelXDimension'],
    ['width', 'image width'],
  )
  const heightRaw = findFieldValue(
    fields,
    ['ImageHeight', 'ExifImageHeight', 'PixelYDimension', 'ImageLength'],
    ['height', 'image height', 'image length'],
  )

  const strength = (meta.camera_provenance_strength ?? '').trim().toLowerCase()
  if (strength) {
    let provLabel = capitalizeWord(strength)
    if (strength === 'partial' && (make || model)) {
      provLabel = 'Partial (device tags in file; not full in-camera proof)'
    } else if (strength === 'strong') {
      provLabel = 'Strong (coherent in-camera metadata)'
    }
    rows.push({ label: 'Camera provenance', value: provLabel })
  }

  if (make) rows.push({ label: videoContainer ? 'Device make' : 'Camera Make', value: make })
  if (model) rows.push({ label: videoContainer ? 'Device model' : 'Camera Model', value: model })
  if (captureRaw) {
    rows.push({
      label: videoContainer ? 'Container creation time' : 'Capture Date',
      value: formatExifCaptureDate(captureRaw),
    })
  }
  const resolution = formatImageResolution(widthRaw, heightRaw)
  if (resolution) rows.push({ label: 'Image Resolution', value: resolution })

  const formatLabel = formatFileFormatLabel(meta)
  if (formatLabel) rows.push({ label: 'File Format', value: formatLabel })
  if (software) rows.push({ label: 'Camera Software', value: software })
  if (handler && videoContainer) rows.push({ label: 'Container encoder', value: handler })

  return rows
}

export function integrityNeedsAdminAction(row: AiDetectionRow): boolean {
  return MANUAL_REVIEW_STATUSES.includes(row.review_status)
}

/** Row label: manual queue vs automated provenance context (avoids "Review Reason" on auto-cleared scans). */
export function integrityContextRowLabel(row: AiDetectionRow): string {
  if (integrityNeedsAdminAction(row)) return 'Review reason'
  return 'Provenance notes'
}

function rawProvenanceReasons(row: AiDetectionRow): string[] {
  return (
    row.exif_metadata?.camera_provenance_reasons
      ?.map((r) => normalizeScanDisplayText(r))
      .filter((r) => r.length > 0) ?? []
  )
}

/** Turn backend provenance strings into short admin-readable lines. */
function humanizeProvenanceReason(raw: string): { kind: 'trigger' | 'fact'; text: string } {
  const lower = raw.toLowerCase()
  if (lower.includes('filename suggests') && (lower.includes('gallery') || lower.includes('download'))) {
    return {
      kind: 'trigger',
      text: 'The file name looks like a gallery save or download, not a direct from-camera name.',
    }
  }
  if (lower.includes('filename suggests') && lower.includes('re-export')) {
    return {
      kind: 'trigger',
      text: 'The file name looks like a re-export or saved copy, not an original camera filename.',
    }
  }
  if (lower.includes('admin review required')) {
    return { kind: 'trigger', text: 'Integrity policy requires an officer to confirm this upload.' }
  }
  const makeModel = raw.match(/camera make\/model present\s*\(([^)]+)\)/i)
  if (makeModel) {
    return { kind: 'fact', text: `Device recorded in metadata: ${makeModel[1].trim()}.` }
  }
  if (lower.includes('partial camera tag')) {
    const tag = raw.replace(/^partial camera tag:\s*/i, '').trim()
    return { kind: 'fact', text: tag ? `Partial device tag: ${tag}.` : 'Partial device tag in metadata.' }
  }
  if (lower.includes('capture timestamp present')) {
    return { kind: 'fact', text: 'Capture date and time are stored in the file metadata.' }
  }
  if (lower.includes('lens metadata')) {
    return { kind: 'fact', text: 'Lens information is present in metadata.' }
  }
  if (lower.includes('software tag present') || lower.includes('device/camera software')) {
    return { kind: 'fact', text: 'Camera or device software is listed in metadata.' }
  }
  if (lower.includes('no exif') || lower.includes('without camera exif')) {
    return { kind: 'fact', text: 'No usable camera EXIF was found in this file.' }
  }
  if (lower.includes('container') && lower.includes('device')) {
    return { kind: 'fact', text: raw.replace(/; admin review required\.?$/i, '').trim() }
  }
  const cleaned = raw.replace(/; admin review required\.?$/i, '').trim()
  return { kind: 'fact', text: cleaned }
}

/** One concise paragraph: why manual review is required (detector vs source separated). */
export function integrityManualReviewParagraph(row: AiDetectionRow): string | null {
  if (!integrityNeedsAdminAction(row)) return null

  const outcome = (row.exif_metadata?.provenance_policy_outcome ?? '').trim().toLowerCase()
  const band = detectorAiRiskBand(row)
  const pct = probeRawPFakePercent(row)
  const parsed = rawProvenanceReasons(row).map(humanizeProvenanceReason)
  const trigger = parsed.find((p) => p.kind === 'trigger')

  const sentences: string[] = []

  if (band === 'HIGH' || band === 'SUSPICIOUS') {
    sentences.push(
      `PROBE-DINOv2 reports ${band === 'HIGH' ? 'high' : 'elevated'} AI-generation risk${pct ? ` (${pct} P(fake))` : ''}.`,
    )
  } else if (pct) {
    sentences.push(`AI-generation risk from the detector is low (${pct} P(fake)).`)
  }

  if (trigger) {
    sentences.push(trigger.text)
  } else if (outcome === 'source_unverified') {
    sentences.push('File source could not be verified from metadata alone.')
  } else if (outcome === 'source_partially_verified') {
    sentences.push('File source is only partially verified and needs an officer decision.')
  } else if (outcome === 'elevated_ai_risk' || outcome === 'high_ai_risk') {
    sentences.push('Integrity policy requires admin review for this risk and provenance mix.')
  } else if (sentences.length === 0) {
    sentences.push('This upload is in the manual review queue under the current integrity policy.')
  }

  if (band === 'LOW' && pct && sentences.length === 1 && !trigger) {
    sentences.push('Manual review is driven by source verification, not by AI-generation score.')
  }

  return sentences.join(' ')
}

/** @deprecated Use integrityManualReviewParagraph */
export function integrityManualReviewExplain(row: AiDetectionRow): {
  headline: string
  bullets: string[]
  nextStep: string
} | null {
  const paragraph = integrityManualReviewParagraph(row)
  if (!paragraph) return null
  return { headline: paragraph, bullets: [], nextStep: '' }
}

/** Bullet list for auto-cleared scans (audit notes only). */
export function integrityProvenanceBullets(row: AiDetectionRow): string[] {
  if (integrityNeedsAdminAction(row)) return []
  const seen = new Set<string>()
  const out: string[] = []
  for (const raw of rawProvenanceReasons(row)) {
    const { text } = humanizeProvenanceReason(raw)
    if (seen.has(text)) continue
    seen.add(text)
    out.push(text)
  }
  return out
}

/** @deprecated Use integrityProvenanceBullets */
export function integrityProvenanceNotes(row: AiDetectionRow): string | null {
  const bullets = integrityProvenanceBullets(row)
  return bullets.length > 0 ? bullets.join(' ') : null
}

/** @deprecated Use integrityManualReviewExplain */
export function integrityManualReviewReason(row: AiDetectionRow): string | null {
  const explain = integrityManualReviewExplain(row)
  if (!explain) return null
  return [explain.headline, ...explain.bullets].join(' ')
}

/** @deprecated Use integrityProvenanceNotes or integrityManualReviewReason */
export function integrityReviewReason(row: AiDetectionRow): string | null {
  if (integrityNeedsAdminAction(row)) return integrityManualReviewReason(row)
  return integrityProvenanceNotes(row)
}

/** Short assessment summary for administrators. */
export function integrityAssessmentSummary(row: AiDetectionRow): string {
  const risk = detectorAiRiskSummaryLabel(row)
  const source = sourceVerificationDisplay(row).status
  const decision = adminDecisionDisplay(row.review_status).label

  if (integrityNeedsAdminAction(row)) {
    return `Detector: ${risk}. Source: ${source}. Awaiting admin decision (currently ${decision}).`
  }
  if (row.review_status === 'automated_low_ai_risk') {
    return `Detector: ${risk}. Source: ${source}. Auto-cleared; override only if you disagree.`
  }
  return `Detector: ${risk}. Source: ${source}. Admin decision: ${decision}.`
}

/** Remaining EXIF fields not already shown in cameraFileDisplayRows (display only). */
export function supplementalExifFieldRows(meta?: ExifMetadata): CameraFileDisplayRow[] {
  if (!meta?.fields?.length) return []
  const shown = new Set(
    cameraFileDisplayRows(meta).map((r) => r.label.toLowerCase()),
  )
  const out: CameraFileDisplayRow[] = []
  const seen = new Set<string>()
  for (const f of meta.fields) {
    const label = normalizeScanDisplayText(f.label || f.key)
    const value = normalizeScanDisplayText(f.value)
    if (!fieldHasValue(value)) continue
    const key = `${label}:${value}`
    if (seen.has(key)) continue
    seen.add(key)
    if (shown.has(label.toLowerCase())) continue
    out.push({ label, value })
  }
  return out
}

export const PROBE_DETECTOR_DISPLAY_NAME = 'PROBE-DINOv2'

export const INTEGRITY_AI_DISCLAIMER = 'AI detection provides a risk estimate, not definitive proof.'