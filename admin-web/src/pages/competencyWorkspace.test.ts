import { describe, expect, it } from 'vitest'
import { memberCompetencyProfileUrl, memberManagementUrl, memberPortfolioUrl } from '../lib/adminCrossLinks'

describe('competency workspace deep links', () => {
  it('routes member management search to Member Overview (tab=directory)', () => {
    expect(memberManagementUrl('Ada Lovelace')).toBe(
      '/competency?tab=directory&q=Ada%20Lovelace',
    )
  })

  it('opens competency profile on skills tab', () => {
    expect(memberCompetencyProfileUrl(42)).toBe('/competency?tab=skills&member=42')
  })

  it('portfolio prefers competency profile when id present', () => {
    expect(memberPortfolioUrl({ userId: 7, memberName: 'Ada' })).toBe(
      '/competency?tab=skills&member=7',
    )
  })
})
