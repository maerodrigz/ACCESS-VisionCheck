import { describe, expect, it } from 'vitest'
import { parseNotification } from '../../lib/notifications'

describe('dashboard unread alerts source', () => {
  it('counts only unread notifications from admin inbox payloads', () => {
    const rows = [
      { id: 1, title: 'A', message: 'x', is_read: false, category: 'ai_detection', priority: 'normal' },
      { id: 2, title: 'B', message: 'y', is_read: true, category: 'feedback', priority: 'normal' },
      { id: 3, title: 'C', message: 'z', is_read: false, category: 'documentation_request', priority: 'high' },
    ]
    const unread = rows.map(parseNotification).filter((n) => n.unread).length
    expect(unread).toBe(2)
  })

  it('keeps integrity deep-link route for review_media alerts', () => {
    const n = parseNotification({
      id: 9,
      title: 'Source Verification Required',
      message: 'Camera capture provenance could not be confirmed.',
      is_read: false,
      category: 'ai_detection',
      priority: 'normal',
      action_type: 'review_media',
      action_ref_id: 55,
    })
    expect(n.route).toBe('/media-integrity?media=55')
    expect(n.unread).toBe(true)
  })
})
