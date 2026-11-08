import { describe, expect, it } from 'vitest'
import { parseEvaluation } from './evaluationReview'
import { noiseColumnToQualityPercent, scoreToPercent } from './mediaEvaluationScores'

describe('admin quality score display', () => {
  it('shows Noise as higher-is-better matching member 1-5 scores', () => {
    const parsed = parseEvaluation({
      id: 1,
      media_id: 2,
      overall_score: 0.8,
      sharpness_score: 0.8,
      brightness_score: 0.8,
      contrast_score: 0.8,
      blur_score: 0.8,
      noise_score: 0.2,
      quality_display: {
        available: true,
        overall_percent: 80,
        opencv_fallback: false,
        quality_engine: 'efficientnet-b0',
        criteria: [
          { name: 'Noise', score: 4, percent: 80, higher_is_better: true },
          { name: 'Blur', score: 4, percent: 80, higher_is_better: true },
        ],
      },
    })
    expect(parsed.noiseScore).toBe(80)
    expect(parsed.blurScore).toBe(80)
    expect(parsed.overallScore).toBe(80)
    expect(noiseColumnToQualityPercent(0.2)).toBe(scoreToPercent(0.8))
  })

  it('does not treat failed evaluations as 50 percent', () => {
    const parsed = parseEvaluation({
      id: 3,
      media_id: 4,
      overall_score: null,
      quality_display: { available: false, status: 'failed', criteria: [], overall_percent: null },
      criteria_json: JSON.stringify({ evaluation_status: 'failed', evaluation_available: false }),
    })
    expect(parsed.qualityAvailable).toBe(false)
    expect(parsed.overallScore).toBeNull()
    expect(parsed.noiseScore).toBeNull()
  })

  it('inverts stored noise_score when quality_display is absent', () => {
    const parsed = parseEvaluation({
      id: 5,
      media_id: 6,
      overall_score: 0.8,
      noise_score: 0.2,
      sharpness_score: 0.8,
    })
    expect(parsed.noiseScore).toBe(80)
    expect(parsed.sharpnessScore).toBe(80)
  })
})
