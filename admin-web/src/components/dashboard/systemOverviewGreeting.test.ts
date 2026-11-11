import { describe, expect, it } from 'vitest'
import { dayPartForHour, greetingForPart } from './SystemOverviewPanel'

describe('dashboard overview greeting', () => {
  it('uses time-of-day greetings with Admin name', () => {
    expect(greetingForPart(dayPartForHour(8))).toBe('Good morning, Admin!')
    expect(greetingForPart(dayPartForHour(14))).toBe('Good afternoon, Admin!')
    expect(greetingForPart(dayPartForHour(20))).toBe('Good evening, Admin!')
  })

  it('personalizes the greeting when a name is provided', () => {
    expect(greetingForPart('morning', 'Jordan')).toBe('Good morning, Jordan!')
  })
})
