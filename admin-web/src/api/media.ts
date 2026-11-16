import { API_BASE, getStoredToken } from './client'

export type AiResultLabel = 'human' | 'ai_generated' | 'suspicious' | 'pending'

export type ReviewStatus =
  | 'pending_review'
  | 'verified_human'
  | 'verified_ai_generated'
  | 'confirmed_ai_generated'
  | 'needs_further_review'
  | 'accepted_with_warning'
  | 'reupload_requested'
  | 'rejected'
  | 'automated_low_ai_risk'

export type ConfidenceLevel = 'high' | 'medium' | 'low'

export interface AiDetectionSummary {
  total_scanned: number
  human_count: number
  ai_generated_count: number
  suspicious_count: number
  pending_review_count: number
}

export interface AiDetectionRow {
  id: number
  media_id: number
  media_name: string
  file_type?: string
  media_url: string
  member_name: string
  member_id?: number
  ai_result: string
  ai_probability: number
  confidence_score: number
  confidence_level: ConfidenceLevel
  review_status: ReviewStatus
  admin_remarks?: string
  detection_remarks?: string
  exif_metadata?: ExifMetadata
  reviewed_by_admin: boolean
  scanned_at?: string
  ai_label: AiResultLabel
  confidence_text: string
}

export interface AiReviewHistoryEntry {
  id: number
  previous_status?: string
  new_status: string
  admin_remarks?: string
  reviewed_by_name?: string
  reviewed_at?: string
}

export interface ExifMetadataFlag {
  code: string
  label: string
  severity: 'info' | 'warning' | 'danger'
}

export interface ExifMetadataField {
  key: string
  label: string
  value: string
}

export interface ExifMetadata {
  has_exif: boolean
  is_video?: boolean
  format?: string | null
  field_count: number
  fields: ExifMetadataField[]
  flags: ExifMetadataFlag[]
  summary?: string
  camera_provenance_strength?: string
  camera_provenance_reasons?: string[]
  visual_risk_level?: string
  provenance_policy_outcome?: string
  visual_ai_probability?: number
  /** Persisted automated detector id (e.g. probe, waverep_g4). */
  detector_backend?: string
  admin_review_triggers?: string[]
  primary_review_driver?: string
}

/** API host origin without `/api` suffix (empty when using same-origin `/api` proxy). */
function apiMediaOrigin(): string {
  const base = API_BASE.replace(/\/$/, '')
  if (base.startsWith('http://') || base.startsWith('https://')) {
    return base.replace(/\/api\/?$/, '')
  }
  return ''
}

/** Legacy Supabase signed URLs missing `/storage/v1` (404 in browser). */
export function normalizeSupabaseStorageUrl(path: string): string {
  if (!path.includes('supabase.co/object/') || path.includes('/storage/v1/object/')) {
    return path
  }
  return path.replace('.supabase.co/object/', '.supabase.co/storage/v1/object/')
}

/** Strip any host from stored `/uploads/...` paths so Vite dev proxy can serve them. */
function uploadsRelativePath(path: string): string | null {
  const trimmed = path.trim()
  if (!trimmed) return null

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    try {
      const u = new URL(trimmed)
      if (u.pathname.startsWith('/uploads/')) {
        return `${u.pathname}${u.search}`
      }
      return null
    } catch {
      return null
    }
  }

  const normalized = trimmed.startsWith('/') ? trimmed : `/${trimmed}`
  if (normalized.startsWith('/uploads/')) return normalized
  return null
}

/**
 * Resolve media paths for `<img>` / `<video>` tags.
 * Stored absolute LAN URLs are rewritten to `/uploads/...` when using the Vite proxy.
 */
/** Admin-authenticated stream URL for img/video tags (supports Range for video playback). */
export function adminMediaStreamUrl(mediaId: number): string {
  if (!mediaId) return ''
  const token = getStoredToken()
  const base = `${API_BASE.replace(/\/$/, '')}/admin/media/${mediaId}/stream`
  if (!token) return base
  return `${base}?access_token=${encodeURIComponent(token)}`
}

/**
 * Media Integrity previews: prefer Supabase/cloud HTTPS URLs (Range + img/video friendly).
 * Fall back to authenticated stream for local `/uploads/...` only.
 */
export function adminIntegrityPreviewUrl(input: {
  mediaId?: number
  mediaUrl?: string | null
  fileName?: string | null
  fileType?: string | null
}): string {
  const raw = (input.mediaUrl ?? '').trim()
  const uploadsRel = uploadsRelativePath(raw)
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    if (!uploadsRel) {
      return normalizeSupabaseStorageUrl(raw)
    }
  }
  // Disk-backed and local QA uploads: always authenticated stream (never public /uploads mount).
  if (uploadsRel && input.mediaId) {
    return adminMediaStreamUrl(input.mediaId)
  }
  if (input.mediaId && (raw.startsWith('/uploads/') || raw.startsWith('uploads/'))) {
    return adminMediaStreamUrl(input.mediaId)
  }
  return mediaUrl(input.mediaUrl)
}

export function mediaUrl(path?: string | null): string {
  if (!path) return ''
  if (path.trim().startsWith('supabase-ref:')) return ''

  path = normalizeSupabaseStorageUrl(path)

  const uploadsPath = uploadsRelativePath(path)
  if (uploadsPath) {
    const origin = apiMediaOrigin()
    return origin ? `${origin}${uploadsPath}` : uploadsPath
  }

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path
  }

  const normalized = path.startsWith('/') ? path : `/${path}`
  const origin = apiMediaOrigin()
  return origin ? `${origin}${normalized}` : normalized
}

const VIDEO_EXTENSIONS = /\.(mp4|webm|mov|avi|mkv|m4v|wmv)$/i
const IMAGE_EXTENSIONS = /\.(jpe?g|png|gif|webp|bmp|heic|heif|avif)$/i

function mediaPathOnly(path?: string | null): string {
  if (!path) return ''
  return path.split('?')[0]?.split('#')[0] ?? ''
}

/** True when the stored upload path is under `/uploads/images/`. */
export function isPhotoStoragePath(path?: string | null): boolean {
  const clean = mediaPathOnly(path)
  return /\/images(\/|$)/i.test(clean)
}

/** Infer video from filename or URL path (extension or `/uploads/videos/`). */
export function isVideoMediaPath(path?: string | null): boolean {
  const clean = mediaPathOnly(path)
  if (!clean) return false
  if (isPhotoStoragePath(clean)) return false
  if (/\/videos(\/|$)/i.test(clean)) return true
  return VIDEO_EXTENSIONS.test(clean)
}

export function isPhotoMediaPath(path?: string | null): boolean {
  const clean = mediaPathOnly(path)
  if (!clean) return false
  if (isPhotoStoragePath(clean)) return true
  return IMAGE_EXTENSIONS.test(clean)
}

export function isVideoMedia(
  fileType?: string | null,
  fileName?: string | null,
  fileUrl?: string | null,
): boolean {
  const type = (fileType ?? '').trim().toLowerCase()
  if (type === 'photo' || type === 'image' || type.startsWith('image/')) return false
  if (fileUrl && isPhotoStoragePath(fileUrl)) return false
  if (type.includes('video')) return true
  if (fileUrl && /\/videos(\/|$)/i.test(mediaPathOnly(fileUrl))) return true
  return isVideoMediaPath(fileName) || isVideoMediaPath(fileUrl)
}
