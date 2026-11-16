/**
 * Media evaluation scores are stored in PostgreSQL as 0–1 (legacy column scale).
 * Criteria JSON uses 1–5 per criterion and overall_score on the same 1–5 scale.
 * noise_score is inverted in the DB (high = more noise). Display higher-is-better like members.
 */

export function scoreToPercent(raw: number): number {
  if (!Number.isFinite(raw) || raw <= 0) return 0
  if (raw <= 1) return Math.round(raw * 1000) / 10
  if (raw <= 5) return Math.round((raw / 5) * 1000) / 10
  return Math.min(100, Math.round(raw))
}

/** Convert stored noise_score (high = noisier) to a quality percent (high = cleaner). */
export function noiseColumnToQualityPercent(noiseScore: number): number {
  if (!Number.isFinite(noiseScore)) return 0
  if (noiseScore <= 1) return scoreToPercent(1 - noiseScore)
  if (noiseScore <= 5) return scoreToPercent(noiseScore)
  return Math.min(100, Math.round(noiseScore))
}

export function formatScorePercent(raw: number): string {
  return `${Math.round(scoreToPercent(raw))}%`
}

/** Good quality band (matches dashboard 75% on legacy 0–1 scale). */
export function isGoodQualityScore(raw: number, minPercent = 75): boolean {
  return scoreToPercent(raw) >= minPercent
}
