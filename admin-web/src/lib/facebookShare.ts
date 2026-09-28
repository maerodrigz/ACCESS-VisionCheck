import { mediaUrl } from '../api/media'
import { logFacebookShareOpened } from '../api/facebook'

/** ACCESS Page — must match access_backend/.env FACEBOOK_PAGE_ID and Flutter FacebookConfig.defaultPageId. */
export const FACEBOOK_PAGE_ID = '1202339146306816'

export const FACEBOOK_PAGE_URL = `https://www.facebook.com/profile.php?id=${FACEBOOK_PAGE_ID}`

/** Open a published Graph API post on Facebook (post id format: {pageId}_{storyId}). */
export function facebookPostUrl(postId: string | null | undefined): string | null {
  if (!postId?.trim()) return null
  const trimmed = postId.trim()
  if (trimmed.includes('_')) {
    const [pageId, storyId] = trimmed.split('_', 2)
    if (pageId && storyId) return `https://www.facebook.com/${pageId}/posts/${storyId}`
  }
  return FACEBOOK_PAGE_URL
}

export function buildFacebookSharerUrl(linkUrl: string, quote?: string): string {
  const params = new URLSearchParams({ u: linkUrl })
  if (quote?.trim()) params.set('quote', quote.trim())
  return `https://www.facebook.com/sharer/sharer.php?${params.toString()}`
}

/** Turn API media paths into an absolute URL Facebook can open. */
export function absoluteMediaUrl(url: string): string {
  const resolved = mediaUrl(url)
  if (!resolved) return ''
  if (resolved.startsWith('http://') || resolved.startsWith('https://')) return resolved
  const normalized = resolved.startsWith('/') ? resolved : `/${resolved}`
  return `${window.location.origin}${normalized}`
}

export function openFacebookSharer(linkUrl: string, quote?: string): boolean {
  const absolute = absoluteMediaUrl(linkUrl)
  if (!absolute) return false
  const sharer = buildFacebookSharerUrl(absolute, quote)
  const win = window.open(sharer, '_blank', 'noopener,noreferrer')
  return win != null
}

export function openFacebookPage(): void {
  window.open(FACEBOOK_PAGE_URL, '_blank', 'noopener,noreferrer')
}

export interface PublishFacebookResult {
  opened: boolean
  message: string
}

/** Opens Facebook sharer and logs the share attempt to the backend. */
export async function publishMediaToFacebook(item: {
  id: number
  fileName: string
  thumbnailUrl: string
}): Promise<PublishFacebookResult> {
  const shareUrl = absoluteMediaUrl(item.thumbnailUrl)
  if (!shareUrl) {
    return { opened: false, message: 'No media URL to share.' }
  }

  const opened = openFacebookSharer(shareUrl, item.fileName)

  try {
    const resp = await logFacebookShareOpened({
      media_id: item.id,
      message: item.fileName,
      share_url: shareUrl,
    })
    if (!opened && resp.facebook_sharer_url) {
      window.open(resp.facebook_sharer_url, '_blank', 'noopener,noreferrer')
      return {
        opened: true,
        message:
          'Facebook opened — finish your post there. Allow pop-ups if the tab did not appear.',
      }
    }
  } catch {
    // Facebook may still have opened; logging is best-effort.
  }

  if (opened) {
    return {
      opened: true,
      message: 'Facebook opened — finish your post there. Org page: ACCESS',
    }
  }

  return {
    opened: false,
    message: 'Could not open Facebook. Allow pop-ups for this site and try again.',
  }
}

/** Browser share for one item (no Page token). Returns false if pop-up blocked. */
export async function publishOneToFacebookBrowser(item: {
  id: number
  fileName: string
  thumbnailUrl: string
  captionPrefix?: string
}): Promise<PublishFacebookResult> {
  const caption = item.captionPrefix?.trim() || item.fileName
  return publishMediaToFacebook({
    id: item.id,
    fileName: caption,
    thumbnailUrl: item.thumbnailUrl,
  })
}
