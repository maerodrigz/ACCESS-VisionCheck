import { describe, expect, it } from 'vitest'
import {
  BellRing,
  CalendarDays,
  ChartNoAxesCombined,
  FileCheck2,
  GraduationCap,
  Images,
  LayoutDashboard,
  MessageSquareHeart,
  Settings,
  ShieldCheck,
  UsersRound,
} from 'lucide-react'
import { FEATURE_HEADERS } from '../lib/featureHeaders'
import { allNavItems } from '../config/navigation'

describe('Admin feature headers coverage', () => {
  it('defines copy for every sidebar nav destination', () => {
    const byPath: Record<string, keyof typeof FEATURE_HEADERS> = {
      '/': 'dashboard',
      '/documentation-requests': 'documentationRequests',
      '/event-calendar': 'eventCalendar',
      '/competency': 'competency',
      '/media': 'mediaGallery',
      '/media-integrity': 'mediaIntegrity',
      '/feedback': 'requesterFeedback',
      '/analytics': 'analytics',
      '/account-management': 'accounts',
    }
    for (const item of allNavItems) {
      const key = byPath[item.path]
      expect(key, `missing feature header for ${item.path}`).toBeTruthy()
      const copy = FEATURE_HEADERS[key]
      expect(copy.title).toBeTruthy()
      expect(copy.description.length).toBeGreaterThan(20)
      expect(copy.icon).toBeTruthy()
    }
  })

  it('keeps notification and system configuration headers', () => {
    expect(FEATURE_HEADERS.notifications.title).toBe('Notification Center')
    expect(FEATURE_HEADERS.systemConfiguration.title).toBe('System Configuration')
  })

  it('uses distinct Lucide icons for feature headers', () => {
    expect(FEATURE_HEADERS.dashboard.icon).toBe(LayoutDashboard)
    expect(FEATURE_HEADERS.documentationRequests.icon).toBe(FileCheck2)
    expect(FEATURE_HEADERS.eventCalendar.icon).toBe(CalendarDays)
    expect(FEATURE_HEADERS.competency.icon).toBe(GraduationCap)
    expect(FEATURE_HEADERS.mediaGallery.icon).toBe(Images)
    expect(FEATURE_HEADERS.mediaIntegrity.icon).toBe(ShieldCheck)
    expect(FEATURE_HEADERS.requesterFeedback.icon).toBe(MessageSquareHeart)
    expect(FEATURE_HEADERS.analytics.icon).toBe(ChartNoAxesCombined)
    expect(FEATURE_HEADERS.accounts.icon).toBe(UsersRound)
    expect(FEATURE_HEADERS.notifications.icon).toBe(BellRing)
    expect(FEATURE_HEADERS.systemConfiguration.icon).toBe(Settings)
  })
})
