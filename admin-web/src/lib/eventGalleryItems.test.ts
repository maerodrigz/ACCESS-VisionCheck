import { describe, expect, it } from 'vitest'
import type { MediaAsset } from './mediaLibrary'
import { albumKey, buildAlbums, eventGalleryItems } from './mediaLibrary'

function asset(partial: Partial<MediaAsset> & Pick<MediaAsset, 'id' | 'fileName' | 'isVideo'>): MediaAsset {
  const isVideo = partial.isVideo
  return {
    fileType: isVideo ? 'video' : 'image',
    fileUrl: `https://example.test/${partial.fileName}`,
    eventName: 'Campus Fair',
    albumName: 'Campus Fair',
    uploaderName: 'Admin',
    uploadedBy: 1,
    uploadedAt: new Date('2026-06-01T00:00:00Z'),
    requestId: 9,
    mediaCategory: 'event_documentation',
    approvalStatus: 'approved',
    approvalRejectionReason: null,
    facebookPublishStatus: 'not_published',
    facebookPostId: null,
    facebookPublishedAt: null,
    eventDate: '2026-06-01',
    eventDescription: null,
    isBestShot: false,
    isPhoto: !isVideo,
    thumbnailUrl: `https://example.test/${partial.fileName}`,
    mediaTypeLabel: isVideo ? 'Video' : 'Photo',
    uploaderRoleLabel: 'Admin',
    publishedStatusLabel: 'Not published',
    approvalStatusLabel: 'Approved',
    formatLabel: isVideo ? 'Video' : 'Photo',
    estimatedFileSize: '1 MB',
    resolutionLabel: 'N/A',
    uploadDateLabel: 'Jun 1, 2026',
    isPublished: partial.facebookPublishStatus === 'published',
    ...partial,
  }
}

const publishedPhoto = asset({
  id: 1,
  fileName: 'photo.jpg',
  isVideo: false,
  facebookPublishStatus: 'published',
  isPublished: true,
})
const publishedVideo = asset({
  id: 2,
  fileName: 'clip.mp4',
  isVideo: true,
  facebookPublishStatus: 'published',
  isPublished: true,
})
const draftPhoto = asset({
  id: 3,
  fileName: 'draft.jpg',
  isVideo: false,
  facebookPublishStatus: 'not_published',
})

describe('published album gallery', () => {
  const albumId = albumKey('Campus Fair', 9)

  it('keeps a published album in the listing with its photo and video counts', () => {
    const albums = buildAlbums([publishedPhoto, publishedVideo])
    expect(albums).toHaveLength(1)
    expect(albums[0].id).toBe(albumId)
    expect(albums[0].photoCount).toBe(1)
    expect(albums[0].videoCount).toBe(1)
  })

  it('shows published photos and videos when that album is opened', () => {
    const open = eventGalleryItems([publishedPhoto, publishedVideo], {
      search: '',
      albumId,
      facebookPublishStatus: 'all',
    })
    expect(open.map((item) => item.id).sort()).toEqual([1, 2])
    expect(open.some((item) => item.isPhoto)).toBe(true)
    expect(open.some((item) => item.isVideo)).toBe(true)
  })

  it('still hides published media from the unscoped gallery', () => {
    const closed = eventGalleryItems([publishedPhoto, publishedVideo, draftPhoto], {
      search: '',
      albumId: null,
      facebookPublishStatus: 'all',
    })
    expect(closed.map((item) => item.id)).toEqual([3])
  })

  it('shows a mixed album without dropping the published file', () => {
    const open = eventGalleryItems([publishedPhoto, draftPhoto], {
      search: '',
      albumId,
      facebookPublishStatus: 'all',
    })
    expect(open.map((item) => item.fileName).sort()).toEqual(['draft.jpg', 'photo.jpg'])
  })
})
