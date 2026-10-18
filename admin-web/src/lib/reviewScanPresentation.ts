import type { AiDetectionRow, ExifMetadata, ExifMetadataField, ReviewStatus } from '../api/media'
import { aiReviewRiskTier } from './aiDetection'

export type VisualRiskBand = 'LOW' | 'SUSPICIOUS' | 'HIGH'

export type CameraMetadataStatus = 'Present' | 'Partial' | 'Missing' | 'Unknown'

const MANUAL_REVIEW_STATUSES: ReviewStatus[] = ['pending_review', 'needs_further_review']

/** Display band from backend `visual_risk_level`, else inbox tier fallback (see note in modal docs). */
export function visualAiRiskBand(row: AiDetectionRow): VisualRiskBand {
  const level = String(row.exif_metadata?.visual_risk_level ?? '').toLowerCase()
  if (level === 'high') return 'HIGH'
  if (level === 'suspicious') return 'SUSPICIOUS'
  if (level === 'low') return 'LOW'
  const tier = aiReviewRiskTier(row)
  if (tier === 'high') return 'HIGH'
  if (tier === 'suspicious') return 'SUSPICIOUS'
  return 'LOW'
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

export function visualAiRiskSummaryLabel(row: AiDetectionRow): string {
  const band = visualAiRiskBand(row)
  const word = band.charAt(0) + band.slice(1).toLowerCase()
  const pct = probeRawPFakePercent(row)
  return pct ? `${word} (${pct})` : word
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
  const fields = meta.fields ?? []
  const make = findFieldValue(fields, ['Make', 'make'], ['camera make', 'manufacturer'])
  const model = findFieldValue(fields, ['Model', 'model'], ['camera model'])
  if (make || model) return 'Present'
  const strength = (meta.camera_provenance_strength ?? '').toLowerCase()
  if (strength === 'partial') return 'Partial'
  if (strength === 'strong') return 'Present'
  if (strength === 'absent' || (!meta.has_exif && fields.length === 0)) return 'Missing'
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

  const strength = (meta.camera_provenance_strength ?? '').trim()
  if (strength) {
    rows.push({ label: 'Camera provenance', value: capitalizeWord(strength) })
  }

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

/** Short manual-review reason for the integrity modal (display only). */
export function integrityReviewReason(row: AiDetectionRow): string | null {
  const meta = row.exif_metadata
  const reasons =
    meta?.camera_provenance_reasons
      ?.map((r) => normalizeScanDisplayText(r))
      .filter((r) => r.length > 0) ?? []
  if (reasons.length > 0) return reasons.join(' ')
  const outcome = meta?.provenance_policy_outcome?.trim()
  if (outcome) return outcome.replace(/_/g, ' ')
  if (!MANUAL_REVIEW_STATUSES.includes(row.review_status)) return null
  const band = visualAiRiskBand(row)
  if (band === 'HIGH') return 'Elevated AI-generation risk'
  if (band === 'SUSPICIOUS') return 'Suspicious AI-generation indicators'
  return 'Manual review required'
}

/** Plain-language assessment summary for administrators (no raw EXIF strings). */
export function integrityAssessmentSummary(row: AiDetectionRow): string {
  const band = visualAiRiskBand(row)
  const cam = cameraMetadataStatus(row.exif_metadata)
  const outcome = (row.exif_metadata?.provenance_policy_outcome ?? '').trim().toLowerCase()
  const status = row.review_status
  const parts: string[] = []

  if (band === 'HIGH') {
    parts.push('The detector indicates high AI-generation risk.')
  } else if (band === 'SUSPICIOUS') {
    parts.push('The detector indicates elevated AI-generation risk.')
  } else {
    parts.push('The detector indicates low AI-generation risk.')
  }

  if (cam === 'Present') {
    parts.push(
      'Camera information is present in the file metadata, but this does not establish image authenticity.',
    )
  } else if (cam === 'Partial') {
    parts.push(
      'Video or file container metadata is only partially verified (for example, creation time without full device identity).',
    )
  } else if (cam === 'Missing') {
    parts.push('Camera-identifying metadata is missing or incomplete.')
  } else {
    parts.push('Camera metadata is limited or inconclusive.')
  }

  if (MANUAL_REVIEW_STATUSES.includes(status)) {
    if (outcome === 'source_unverified') {
      parts.push('Source verification could not be completed. Manual review is required.')
    } else if (outcome === 'elevated_ai_risk' || outcome === 'high_ai_risk') {
      parts.push('Manual review is required based on current risk and provenance policy.')
    } else {
      parts.push('Manual review is required.')
    }
  } else if (status === 'automated_low_ai_risk') {
    parts.push('Automated routing marked this scan as low AI risk with acceptable provenance for the current policy.')
  } else if (status === 'verified_human') {
    parts.push('An administrator verified this media as human-made.')
  } else if (status === 'confirmed_ai_generated') {
    parts.push('An administrator confirmed AI-generated or manipulated content.')
  } else if (status === 'reupload_requested') {
    parts.push('An administrator requested a new upload from the member.')
  }

  return parts.join(' ')
}

export const PROBE_DETECTOR_DISPLAY_NAME = 'PROBE-DINOv2'

export const INTEGRITY_AI_DISCLAIMER = 'AI detection provides a risk estimate, not definitive proof.'