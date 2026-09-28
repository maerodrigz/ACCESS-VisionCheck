export function mediaQualityPercent(averageQualityScore: number): number {
  if (averageQualityScore <= 0) return 0
  if (averageQualityScore <= 1) return averageQualityScore * 100
  return Math.min(100, Math.max(0, averageQualityScore))
}

function pct(num: number, den: number, defaultValue = 0): number {
  if (den <= 0) return defaultValue
  return Math.min(100, Math.max(0, (num / den) * 100))
}

export function approvedUploadsPercent(approved: number, total: number): number {
  return pct(approved, total)
}

export function taskParticipationPercent(completed: number, assigned: number): number {
  return pct(completed, assigned)
}

/** Skill level uses evaluation quality + media integrity only (mirrors backend). */
export function computeSkillScore(input: {
  mediaQualityScore: number
  aiAuthenticityScore: number
}): number {
  return input.mediaQualityScore * 0.7 + input.aiAuthenticityScore * 0.3
}
