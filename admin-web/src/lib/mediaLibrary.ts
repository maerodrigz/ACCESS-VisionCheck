import { mediaUrl, isVideoMediaPath } from '../api/media'
import type { ApprovalStatus, EventMediaRow, FacebookPublishStatus, MediaCategory } from '../api/eventMedia'

export interface MediaLibraryStats {
  totalPhotos: number
  totalVideos: number
  totalAlbums: number
  storageUsedLabel: string
}

export interface MediaAlbum {
  id: string
  name: string
  date: Date | null
  photoCount: number
  videoCount: number
  coverUrl: string
  requestId: number | null
  totalCount: number
}

export interface MediaAsset {
  id: number
  fileName: string
  fileType: string
  fileUrl: string
  eventName: string
  albumName: string
  uploaderName: string
  uploadedBy: number | null
  uploadedAt: Date | null
  requestId: number | null
  mediaCategory: MediaCategory
  approvalStatus: ApprovalStatus
  approvalRejectionReason: string | null
  facebookPublishStatus: FacebookPublishStatus
  facebookPostId: string | null
  facebookPublishedAt: Date | null
  eventDate: string | null
  eventDescription: string | null
  isBestShot: boolean
  isVideo: boolean
  isPhoto: boolean
  thumbnailUrl: string
  mediaTypeLabel: string
  uploaderRoleLabel: string
  publishedStatusLabel: string
  approvalStatusLabel: string
  formatLabel: string
  estimatedFileSize: string
  resolutionLabel: string
  uploadDateLabel: string | null
  /** @deprecated use facebookPublishStatus === 'published' */
  isPublished: boolean
}

const PUBLISHED_KEY = 'media_library_published_ids' // legacy — FB status now from API
const BEST_SHOTS_KEY = 'media_library_best_shot_ids'
const ARCHIVED_KEY = 'media_library_archived_ids' // legacy — archived on server after migration
const ALBUM_OVERRIDES_KEY = 'media_library_album_overrides'

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

export function albumKey(name: string, requestId: number | null): string {
  return requestId != null ? `req_${requestId}` : `evt_${name.toLowerCase()}`
}

export function formatMediaDate(d: Date): string {
  return `${MONTHS[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`
}

function parseDate(raw: unknown): Date | null {
  if (raw == null) return null
  const d = new Date(String(raw))
  return Number.isNaN(d.getTime()) ? null : d
}

function loadIdSet(key: string): Set<number> {
  try {
    const raw = localStorage.getItem(key)
    if (!raw) return new Set()
    const arr = JSON.parse(raw) as unknown[]
    return new Set(arr.map(Number).filter((n) => !Number.isNaN(n)))
  } catch {
    return new Set()
  }
}

function loadAlbumOverrides(): Map<number, string> {
  try {
    const raw = localStorage.getItem(ALBUM_OVERRIDES_KEY)
    if (!raw) return new Map()
    const entries = JSON.parse(raw) as string[]
    const map = new Map<number, string>()
    for (const entry of entries) {
      const sep = entry.indexOf(':')
      if (sep <= 0) continue
      const id = Number(entry.slice(0, sep))
      if (!Number.isNaN(id)) map.set(id, entry.slice(sep + 1))
    }
    return map
  } catch {
    return new Map()
  }
}

/** Legacy browser-only best picks (one-time migration to server). */
export function loadLegacyBestShotIds(): Set<number> {
  return loadIdSet(BEST_SHOTS_KEY)
}

/** Legacy browser-only album overrides (one-time migration to server). */
export function loadLegacyAlbumOverrides(): Map<number, string> {
  return loadAlbumOverrides()
}

/** Legacy browser-only archived ids (one-time migration to server). */
export function loadLegacyArchivedMediaIds(): Set<number> {
  return loadIdSet(ARCHIVED_KEY)
}

/** Clear legacy local best-pick / album keys after server migration. */
export function clearLegacyMediaCurationLocalStorage() {
  localStorage.removeItem(BEST_SHOTS_KEY)
  localStorage.removeItem(ALBUM_OVERRIDES_KEY)
  localStorage.removeItem(PUBLISHED_KEY)
}

export function clearLegacyArchivedMediaIds() {
  localStorage.removeItem(ARCHIVED_KEY)
}

function fbStatusLabel(status: FacebookPublishStatus): string {
  switch (status) {
    case 'published':
      return 'Published'
    case 'publishing':
      return 'Publishing'
    case 'failed':
      return 'Publishing Failed'
    default:
      return 'Not Published'
  }
}

function approvalLabel(status: ApprovalStatus): string {
  switch (status) {
    case 'approved':
      return 'Approved'
    case 'rejected':
      return 'Rejected'
    case 'pending':
      return 'Pending Review'
    default:
      return 'N/A'
  }
}

function isVideoMedia(fileType: string, fileName: string, fileUrl: string): boolean {
  if (fileType.toLowerCase() === 'video') return true
  return isVideoMediaPath(fileName) || isVideoMediaPath(fileUrl)
}

function mapEventRow(row: EventMediaRow): MediaAsset | null {
  const id = row.id
  const eventTitle = row.event_title ?? 'Uncategorized Event'
  const requestId = row.request_id
  const albumName = row.album_name_override?.trim() || eventTitle
  const fileType = row.file_type
  const fileName = row.file_name
  const fileUrl = row.file_url
  const isVideo = isVideoMedia(fileType, fileName, fileUrl)
  const uploadedAt = parseDate(row.uploaded_at)
  const fbStatus = row.facebook_publish_status

  const parts = fileName.split('.')
  const formatLabel = parts.length > 1 ? parts[parts.length - 1].toUpperCase() : isVideo ? 'MP4' : 'JPEG'
  const seed = id % 7
  const estimatedFileSize = isVideo ? `${2 + seed}.${seed} MB` : `${800 + seed * 120} KB`
  const resolutionPresets = isVideo
    ? ['1920×1080', '1280×720', '3840×2160']
    : ['4032×3024', '6000×4000', '3264×2448']
  const resolutionLabel = resolutionPresets[id % resolutionPresets.length]

  return {
    id,
    fileName,
    fileType,
    fileUrl,
    eventName: eventTitle,
    albumName,
    uploaderName: row.uploader_name,
    uploadedBy: row.uploaded_by ?? null,
    uploadedAt,
    requestId,
    mediaCategory: row.media_category,
    approvalStatus: row.approval_status,
    approvalRejectionReason: row.approval_rejection_reason,
    facebookPublishStatus: fbStatus,
    facebookPostId: row.facebook_post_id,
    facebookPublishedAt: parseDate(row.facebook_published_at),
    eventDate: row.event_date,
    eventDescription: row.event_description,
    isPublished: fbStatus === 'published',
    isBestShot: Boolean(row.is_best_shot) && fbStatus !== 'published',
    isVideo,
    isPhoto: !isVideo,
    thumbnailUrl: mediaUrl(fileUrl),
    mediaTypeLabel: isVideo ? 'Video' : 'Photo',
    uploaderRoleLabel: isVideo ? 'Videographer' : 'Photographer',
    publishedStatusLabel: fbStatusLabel(fbStatus),
    approvalStatusLabel: approvalLabel(row.approval_status),
    formatLabel,
    estimatedFileSize,
    resolutionLabel,
    uploadDateLabel: uploadedAt ? formatMediaDate(uploadedAt) : null,
  }
}

function mapRow(row: Record<string, unknown>): MediaAsset | null {
  const id = Number(row.id ?? 0)
  if (!id) return null
  const eventTitle = String(row.event_title ?? row.source_label ?? 'Uncategorized')
  const requestId = row.request_id != null ? Number(row.request_id) : null
  const albumOverride = typeof row.album_name_override === 'string' ? row.album_name_override.trim() : ''
  const albumName = albumOverride || eventTitle
  const fileType = String(row.file_type ?? 'image')
  const fileName = String(row.file_name ?? `Media #${id}`)
  const fileUrl = String(row.file_url ?? '')
  const isVideo = isVideoMedia(fileType, fileName, fileUrl)
  const uploadedAt = parseDate(row.uploaded_at)

  const parts = fileName.split('.')
  const formatLabel = parts.length > 1 ? parts[parts.length - 1].toUpperCase() : isVideo ? 'MP4' : 'JPEG'
  const seed = id % 7
  const estimatedFileSize = isVideo ? `${2 + seed}.${seed} MB` : `${800 + seed * 120} KB`
  const resolutionPresets = isVideo
    ? ['1920×1080', '1280×720', '3840×2160']
    : ['4032×3024', '6000×4000', '3264×2448']
  const resolutionLabel = resolutionPresets[id % resolutionPresets.length]
  const mediaCategory = (row.media_category as MediaCategory) ?? (requestId ? 'event_documentation' : 'member_evaluation')
  const approvalStatus = (row.approval_status as ApprovalStatus) ?? 'not_applicable'
  const fbStatus = (row.facebook_publish_status as FacebookPublishStatus) ?? 'not_published'

  return {
    id,
    fileName,
    fileType,
    fileUrl,
    eventName: eventTitle,
    albumName,
    uploaderName: String(row.uploader_name ?? 'Unknown'),
    uploadedBy: row.uploaded_by != null ? Number(row.uploaded_by) : null,
    uploadedAt,
    requestId,
    mediaCategory,
    approvalStatus,
    approvalRejectionReason: (row.approval_rejection_reason as string | null) ?? null,
    facebookPublishStatus: fbStatus,
    facebookPostId: (row.facebook_post_id as string | null) ?? null,
    facebookPublishedAt: parseDate(row.facebook_published_at),
    eventDate: (row.event_date as string | null) ?? null,
    eventDescription: (row.event_description as string | null) ?? null,
    isPublished: fbStatus === 'published',
    isBestShot: Boolean(row.is_best_shot) && fbStatus !== 'published',
    isVideo,
    isPhoto: !isVideo,
    thumbnailUrl: mediaUrl(fileUrl),
    mediaTypeLabel: isVideo ? 'Video' : 'Photo',
    uploaderRoleLabel: isVideo ? 'Videographer' : 'Photographer',
    publishedStatusLabel: fbStatusLabel(fbStatus),
    approvalStatusLabel: approvalLabel(approvalStatus),
    formatLabel,
    estimatedFileSize,
    resolutionLabel,
    uploadDateLabel: uploadedAt ? formatMediaDate(uploadedAt) : null,
  }
}

export function parseEventMediaRows(rows: EventMediaRow[]): MediaAsset[] {
  return rows
    .map((row) => mapEventRow(row))
    .filter((a): a is MediaAsset => a != null)
    .sort((a, b) => (b.uploadedAt?.getTime() ?? 0) - (a.uploadedAt?.getTime() ?? 0))
}

export function parseMediaRows(rows: Record<string, unknown>[]): MediaAsset[] {
  return rows
    .map((row) => mapRow(row))
    .filter((a): a is MediaAsset => a != null)
    .sort((a, b) => (b.uploadedAt?.getTime() ?? 0) - (a.uploadedAt?.getTime() ?? 0))
}

export function buildAlbums(assets: MediaAsset[]): MediaAlbum[] {
  const map = new Map<string, MediaAsset[]>()
  for (const a of assets) {
    const key = albumKey(a.albumName, a.requestId)
    if (!map.has(key)) map.set(key, [])
    map.get(key)!.push(a)
  }

  const albums: MediaAlbum[] = []
  for (const [id, items] of map) {
    const photos = items.filter((i) => i.isPhoto).length
    const videos = items.filter((i) => i.isVideo).length
    const cover =
      items.find((i) => i.isPhoto && i.thumbnailUrl) ??
      items[0]
    const dates = items.map((i) => i.uploadedAt).filter(Boolean) as Date[]
    dates.sort((a, b) => b.getTime() - a.getTime())
    albums.push({
      id,
      name: items[0].albumName,
      date: dates[0] ?? null,
      photoCount: photos,
      videoCount: videos,
      coverUrl: cover.thumbnailUrl,
      requestId: items[0].requestId,
      totalCount: photos + videos,
    })
  }
  albums.sort((a, b) => b.totalCount - a.totalCount)
  return albums
}

export function computeMediaStats(assets: MediaAsset[], albums: MediaAlbum[]): MediaLibraryStats {
  const photos = assets.filter((a) => a.isPhoto).length
  const videos = assets.filter((a) => a.isVideo).length
  const mb = assets.reduce((sum, a) => sum + (a.isVideo ? 2.5 : 1.1), 0)
  const storageUsedLabel = mb >= 1024 ? `${(mb / 1024).toFixed(1)} GB` : `${mb.toFixed(1)} MB`
  return { totalPhotos: photos, totalVideos: videos, totalAlbums: albums.length, storageUsedLabel }
}

export function filterMedia(
  items: MediaAsset[],
  search: string,
  albumId: string | null,
  opts?: {
    mediaCategory?: MediaCategory | 'all'
    approvalStatus?: ApprovalStatus | 'all'
    facebookPublishStatus?: FacebookPublishStatus | 'all'
  },
): MediaAsset[] {
  const q = search.trim().toLowerCase()
  return items.filter((a) => {
    if (albumId && albumId !== albumKey(a.albumName, a.requestId)) return false
    if (opts?.mediaCategory && opts.mediaCategory !== 'all' && a.mediaCategory !== opts.mediaCategory) return false
    if (opts?.approvalStatus && opts.approvalStatus !== 'all' && a.approvalStatus !== opts.approvalStatus)
      return false
    if (
      opts?.facebookPublishStatus &&
      opts.facebookPublishStatus !== 'all' &&
      a.facebookPublishStatus !== opts.facebookPublishStatus
    )
      return false
    if (!q) return true
    const hit = (s: string | null | undefined) => s != null && s.toLowerCase().includes(q)
    return (
      hit(a.fileName) ||
      hit(a.eventName) ||
      hit(a.albumName) ||
      hit(a.uploaderName) ||
      hit(a.mediaTypeLabel) ||
      (a.uploadedAt != null && formatMediaDate(a.uploadedAt).toLowerCase().includes(q))
    )
  })
}

export function filterByMediaFormat(
  items: MediaAsset[],
  format: 'all' | 'photos' | 'videos',
): MediaAsset[] {
  if (format === 'photos') return items.filter((a) => a.isPhoto)
  if (format === 'videos') return items.filter((a) => a.isVideo)
  return items
}

export function canPublishToFacebook(item: MediaAsset): boolean {
  return (
    item.mediaCategory === 'event_documentation' &&
    item.isBestShot &&
    (item.facebookPublishStatus === 'not_published' || item.facebookPublishStatus === 'failed')
  )
}

export function recentUploads(items: MediaAsset[], limit = 24): MediaAsset[] {
  return items.slice(0, limit)
}

export function bestShots(items: MediaAsset[]): MediaAsset[] {
  return items.filter((a) => a.isBestShot)
}

/** Starred items still waiting to go (or retry) on Facebook. */
export function pendingBestShots(items: MediaAsset[]): MediaAsset[] {
  return items.filter(
    (a) => a.isBestShot && a.facebookPublishStatus !== 'published',
  )
}

export function refreshAssetFlags(asset: MediaAsset): MediaAsset {
  return asset
}
