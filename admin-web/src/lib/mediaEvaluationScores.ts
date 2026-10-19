/**
 * Media evaluation scores are stored in PostgreSQL as 0–1 (legacy column scale).
 * Criteria JSON uses 1–5 per criterion and overall_score on the same 1–5 scale.
 */

export function scoreToPercent(raw: number): number {
  if (!Number.isFinite(raw) || raw <= 0) return 0
  if (raw <= 1) return Math.round(raw * 1000) / 10
  if (raw <= 5) return Math.round((raw / 5) * 1000) / 10
  return Math.min(100, Math.round(raw))
}

export function formatScorePercent(raw: number): string {
  return `${Math.round(scoreToPercent(raw))}%`
}

/** Good quality band (matches dashboard 75% on legacy 0–1 scale). */
export function isGoodQualityScore(raw: number, minPercent = 75): boolean {
  return scoreToPercent(raw) >= minPercent
}
