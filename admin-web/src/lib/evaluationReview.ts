import { scoreToPercent } from './mediaEvaluationScores'
import { parseDate } from './teamMembers'

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
  overallScore: number
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

export function parseEvaluation(raw: Record<string, unknown>): EvaluationReviewItem {
  const sourceType = String(raw.source_type ?? '').toLowerCase() === 'event' ? 'event' : 'practice'
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
    overallScore: scoreToPercent(Number(raw.overall_score ?? 0)),
    qualityLevel: (raw.quality_level as string | null) ?? null,
    recommendation: (raw.recommendation as string | null) ?? null,
    feedback: (raw.feedback as string | null) ?? null,
    adminRemarks: (raw.admin_remarks as string | null) ?? null,
    aiProbability: num(raw.ai_probability),
    aiResult: (raw.ai_result as string | null) ?? (raw.detection_result as string | null) ?? null,
    evaluatedAt: parseDate(raw.evaluated_at ?? raw.created_at),
    sharpnessScore: num(raw.sharpness_score) != null ? scoreToPercent(num(raw.sharpness_score)!) : null,
    brightnessScore: num(raw.brightness_score) != null ? scoreToPercent(num(raw.brightness_score)!) : null,
    contrastScore: num(raw.contrast_score) != null ? scoreToPercent(num(raw.contrast_score)!) : null,
    blurScore: num(raw.blur_score) != null ? scoreToPercent(num(raw.blur_score)!) : null,
    noiseScore: num(raw.noise_score) != null ? scoreToPercent(num(raw.noise_score)!) : null,
  }
}

export function isEvaluationFlagged(item: EvaluationReviewItem): boolean {
  const r = (item.aiResult ?? '').toLowerCase()
  return r === 'ai_generated' || r === 'suspicious'
}

export function formatEvalDate(d: Date | null): string {
  if (!d) return 'N/A'
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

export function scoreTone(score: number): string {
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
