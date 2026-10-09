import type { AiDetectionRow, ExifMetadata, ReviewStatus } from '../api/media'
import { aiReviewRiskTier } from './aiDetection'

export type VisualRiskBand = 'LOW' | 'SUSPICIOUS' | 'HIGH'

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

export function cameraOriginLabel(meta?: ExifMetadata): string {
  const strength = (meta?.camera_provenance_strength ?? '').trim().toLowerCase()
  if (strength === 'strong') return 'Verified'
  if (strength === 'partial') return 'Limited verification'
  if (strength === 'moderate') return 'Limited verification'
  if (!strength || strength === 'none' || strength === 'weak' || strength === 'unknown' || strength === 'absent') {
    return 'Not Verified'
  }
  return strength.charAt(0).toUpperCase() + strength.slice(1)
}

/** Human-readable provenance policy outcome (backend `provenance_policy_outcome` values). */
export function formatProvenancePolicyDisplay(raw?: string): string {
  if (!raw?.trim()) return 'Not assessed'
  const key = raw.trim().toLowerCase()
  const labels: Record<string, string> = {
    source_unverified: 'Unverified',
    low_ai_risk: 'Low AI risk',
    elevated_ai_risk: 'Elevated AI risk',
    high_ai_risk: 'High AI risk',
    source_partially_verified: 'Partially verified',
  }
  if (labels[key]) return labels[key]
  return key.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

const POLICY_REVIEW_REASON: Record<string, string> = {
  source_unverified: 'Camera origin could not be verified.',
  elevated_ai_risk: 'Elevated AI-generation risk requires administrative review.',
  high_ai_risk: 'High AI-generation risk requires administrative review.',
}

/** Short admin-facing reason when manual review is open; only backend-backed text. */
export function integrityReviewReason(row: AiDetectionRow): string | null {
  if (!MANUAL_REVIEW_STATUSES.includes(row.review_status)) return null

  const reasons = (row.exif_metadata?.camera_provenance_reasons ?? []).map((r) => r.trim()).filter(Boolean)
  if (reasons.length > 0) return reasons[0]

  const outcome = row.exif_metadata?.provenance_policy_outcome?.trim().toLowerCase()
  if (outcome && POLICY_REVIEW_REASON[outcome]) return POLICY_REVIEW_REASON[outcome]

  const remarks = row.detection_remarks?.trim()
  if (remarks) {
    const sentence = remarks.match(/^[^.!?]+[.!?]/)?.[0]?.trim()
    return sentence ?? remarks
  }

  return null
}

export function technicalProvenanceExplanation(meta?: ExifMetadata): string {
  if (!meta) return 'File metadata was not available for this scan.'
  const reasons = (meta.camera_provenance_reasons ?? []).map((r) => r.trim()).filter(Boolean)
  if (reasons.length > 0) return reasons.join(' ')
  const summary = meta.summary?.trim()
  if (summary) return summary
  if (!meta.has_exif) {
    return 'Camera origin could not be verified because credible camera metadata is missing.'
  }
  return 'Review EXIF and upload context alongside automated checks.'
}

export const PROBE_DETECTOR_DISPLAY_NAME = 'PROBE-DINOv2'

export const AI_GENERATION_RISK_HINT =
  'Low AI-generation risk does not prove human authenticity. Missing EXIF is not evidence of AI generation.'
