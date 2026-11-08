import { noiseColumnToQualityPercent, scoreToPercent } from './mediaEvaluationScores'
import { parseDate } from './teamMembers'

function parseCriteriaJsonBlob(raw: unknown): Record<string, unknown> | null {
  if (raw == null) return null
  if (typeof raw === 'object' && !Array.isArray(raw)) {
    return raw as Record<string, unknown>
  }
  if (typeof raw === 'string' && raw.trim()) {
    try {
      const parsed = JSON.parse(raw) as unknown
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
        ? (parsed as Record<string, unknown>)
        : null
    } catch {
      return null
    }
  }
  return null
}

export type EvaluationSourceFilter = 'all' | 'practice' | 'event' | 'flagged'

export interface EvaluationReviewItem {
  id: number
  mediaId: number
  fileName: string
  fileUrl: string
  memberName: string
  sourceType: 'practice' | 'event'
  sourceLabel: string
  eventTitle: string | null
  requestId: number | null
  overallScore: number | null
  qualityAvailable: boolean
  qualityLevel: string | null
  recommendation: string | null
  feedback: string | null
  adminRemarks: string | null
  aiProbability: number | null
  aiResult: string | null
  evaluatedAt: Date | null
  sharpnessScore: number | null
  brightnessScore: number | null
  contrastScore: number | null
  blurScore: number | null
  noiseScore: number | null
  mediaType: string | null
  qualityEngine: string | null
  opencvFallback: boolean
}

export interface EvaluationSummary {
  totalEvaluated: number
  averageOverallScore: number
  humanMediaCount: number
  aiSuspiciousCount: number
}

function num(raw: unknown): number | null {
  if (raw == null || raw === '') return null
  const n = Number(raw)
  return Number.isFinite(n) ? n : null
}

export function parseEvaluationSummary(raw: Record<string, unknown>): EvaluationSummary {
  return {
    totalEvaluated: Number(raw.total_evaluated ?? 0),
    averageOverallScore: scoreToPercent(Number(raw.average_overall_score ?? 0)),
    humanMediaCount: Number(raw.human_media_count ?? 0),
    aiSuspiciousCount: Number(raw.ai_suspicious_count ?? 0),
  }
}

function criterionPercent(
  display: Record<string, unknown> | null,
  name: string,
): number | null {
  const rows = display?.criteria
  if (!Array.isArray(rows)) return null
  const match = rows.find((row) => row && typeof row === 'object' && (row as { name?: string }).name === name) as
    | { percent?: unknown }
    | undefined
  const p = num(match?.percent)
  return p
}

export function parseEvaluation(raw: Record<string, unknown>): EvaluationReviewItem {
  const sourceType = String(raw.source_type ?? '').toLowerCase() === 'event' ? 'event' : 'practice'
  const displayRaw = raw.quality_display
  const display =
    displayRaw && typeof displayRaw === 'object' && !Array.isArray(displayRaw)
      ? (displayRaw as Record<string, unknown>)
      : null
  const available = display ? display.available !== false : raw.overall_score != null
  const criteria = parseCriteriaJsonBlob(raw.criteria_json)
  return {
    id: Number(raw.id ?? 0),
    mediaId: Number(raw.media_id ?? 0),
    fileName: String(raw.file_name ?? raw.media_name ?? ''),
    fileUrl: String(raw.file_url ?? ''),
    memberName: String(raw.member_name ?? raw.uploader_name ?? 'Unknown'),
    sourceType,
    sourceLabel: String(raw.source_label ?? (sourceType === 'practice' ? 'Practice evaluation' : 'Event coverage')),
    eventTitle: (raw.event_title as string | null) ?? null,
    requestId: raw.request_id != null ? Number(raw.request_id) : null,
    overallScore: available
      ? display?.overall_percent != null
        ? num(display.overall_percent)
        : raw.overall_score != null
          ? scoreToPercent(Number(raw.overall_score))
          : null
      : null,
    qualityAvailable: Boolean(available),
    qualityLevel: available ? ((raw.quality_level as string | null) ?? null) : null,
    recommendation: (raw.recommendation as string | null) ?? null,
    feedback: (raw.feedback as string | null) ?? null,
    adminRemarks: (raw.admin_remarks as string | null) ?? null,
    aiProbability: num(raw.ai_probability),
    aiResult: (raw.ai_result as string | null) ?? (raw.detection_result as string | null) ?? null,
    evaluatedAt: parseDate(raw.evaluated_at ?? raw.created_at),
    sharpnessScore: available
      ? (criterionPercent(display, 'Sharpness') ??
        (num(raw.sharpness_score) != null ? scoreToPercent(num(raw.sharpness_score)!) : null))
      : null,
    brightnessScore: available
      ? (criterionPercent(display, 'Brightness') ??
        (num(raw.brightness_score) != null ? scoreToPercent(num(raw.brightness_score)!) : null))
      : null,
    contrastScore: available
      ? (criterionPercent(display, 'Contrast') ??
        (num(raw.contrast_score) != null ? scoreToPercent(num(raw.contrast_score)!) : null))
      : null,
    blurScore: available
      ? (criterionPercent(display, 'Blur') ??
        (num(raw.blur_score) != null ? scoreToPercent(num(raw.blur_score)!) : null))
      : null,
    noiseScore: available
      ? (criterionPercent(display, 'Noise') ??
        (num(raw.noise_score) != null ? noiseColumnToQualityPercent(num(raw.noise_score)!) : null))
      : null,
    mediaType: (() => {
      const direct = raw.media_type != null ? String(raw.media_type) : null
      if (direct) return direct
      const mt = criteria?.media_type
      return mt != null ? String(mt) : null
    })(),
    qualityEngine: display?.quality_engine != null ? String(display.quality_engine) : null,
    opencvFallback: Boolean(display?.opencv_fallback),
  }
}

export function isEvaluationFlagged(item: EvaluationReviewItem): boolean {
  const r = (item.aiResult ?? '').toLowerCase()
  return r === 'ai_generated' || r === 'suspicious'
}

/** Practice photo/video rows carry an AI authenticity score; event documentation does not. */
export function practicePhotoOrVideoEvaluation(item: EvaluationReviewItem): boolean {
  if (item.sourceType !== 'practice') return false
  const mt = (item.mediaType ?? '').trim().toLowerCase()
  if (mt === 'photo' || mt === 'video') return true
  const name = item.fileName.toLowerCase()
  return /\.(jpe?g|png|webp|heic|heif|mp4|mov|m4v|webm)(\?|$)/i.test(name)
}

export function formatEvaluationAiScore(probability: number | null): string | null {
  if (probability == null || Number.isNaN(probability)) return null
  return `${Math.round(Math.min(1, Math.max(0, probability)) * 100)}%`
}

export function formatEvalDate(d: Date | null): string {
  if (!d) return 'N/A'
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

export function scoreTone(score: number | null): string {
  if (score == null) return 'text-[var(--color-text-muted)]'
  if (score >= 75) return 'text-emerald-400'
  if (score >= 50) return 'text-amber-400'
  return 'text-red-400'
}

export function matchesEvaluationFilter(
  item: EvaluationReviewItem,
  filter: EvaluationSourceFilter,
): boolean {
  if (filter === 'all') return true
  if (filter === 'practice') return item.sourceType === 'practice'
  if (filter === 'event') return item.sourceType === 'event'
  return isEvaluationFlagged(item)
}
