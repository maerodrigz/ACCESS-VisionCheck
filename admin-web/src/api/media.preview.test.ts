import { describe, expect, it, vi, beforeEach } from 'vitest'
import { adminIntegrityPreviewUrl, adminMediaStreamUrl, mediaUrl } from './media'

describe('admin media preview URLs', () => {
  beforeEach(() => {
    vi.stubGlobal('localStorage', {
      getItem: () => 'test-jwt-token',
      setItem: () => {},
      removeItem: () => {},
    })
  })

  it('uses authenticated stream for local disk paths when mediaId is set', () => {
    const url = adminIntegrityPreviewUrl({
      mediaId: 517,
      mediaUrl: '/uploads/images/abc.jpg',
      fileName: 'abc.jpg',
    })
    expect(url).toContain('/admin/media/517/stream')
    expect(url).toContain('access_token=test-jwt-token')
  })

  it('uses HTTPS cloud URL directly when not under /uploads/', () => {
    const cloud = 'https://example.supabase.co/storage/v1/object/public/x/y.jpg'
    const url = adminIntegrityPreviewUrl({
      mediaId: 1,
      mediaUrl: cloud,
    })
    expect(url).toBe(cloud)
  })

  it('rewrites LAN absolute /uploads/ URLs to stream when mediaId present', () => {
    const url = adminIntegrityPreviewUrl({
      mediaId: 99,
      mediaUrl: 'http://192.168.1.5:3003/uploads/images/x.jpg',
    })
    expect(url).toContain('/admin/media/99/stream')
  })

  it('mediaUrl maps relative uploads to same-origin proxy path', () => {
    expect(mediaUrl('/uploads/images/a.jpg')).toBe('/uploads/images/a.jpg')
  })

  it('adminMediaStreamUrl includes token query when stored', () => {
    expect(adminMediaStreamUrl(12)).toContain('access_token=test-jwt-token')
  })
})
