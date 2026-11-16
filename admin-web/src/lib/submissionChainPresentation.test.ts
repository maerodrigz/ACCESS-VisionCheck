import { describe, expect, it } from 'vitest'
import { chainMediaRoleLabel, formatChainEventType } from './submissionChainPresentation'

describe('submissionChainPresentation', () => {
  it('labels root media', () => {
    expect(
      chainMediaRoleLabel({ media_id: 5, file_name: 'a.jpg' }, 5),
    ).toBe('Original submission')
  })

  it('labels active replacement', () => {
    expect(
      chainMediaRoleLabel(
        { media_id: 6, file_name: 'b.jpg', replaces_media_id: 5, replacement_lifecycle: 'active' },
        5,
      ),
    ).toBe('Active replacement')
  })

  it('formats event types', () => {
    expect(formatChainEventType('replacement_uploaded')).toBe('replacement uploaded')
  })
})
