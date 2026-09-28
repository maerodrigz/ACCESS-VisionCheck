import { parseDocumentationRequest } from './documentationRequests'

export type FeedbackReviewStatus = 'pending' | 'reviewed' | 'archived'

export type FeedbackFilterChip =
  | 'all'
  | 'pending'
  | 'needsAttention'
  | 'star5'
  | 'star4'
  | 'star3'
  | 'star2'
  | 'star1'

export interface FeedbackOverviewStats {
  averageRating: number
  totalReceived: number
  positiveReviews: number
  needsAttention: number
  pendingReview: number
}

export interface RequesterFeedbackItem {
  id: number
  requestId: number
  eventName: string
  organization: string
  requesterName: string
  eventDate: Date | null
  submittedAt: Date | null
  completionDate: Date | null
  rating: number
  comment: string
  reviewStatus: FeedbackReviewStatus
  eventSummary: EventServiceSummary
  adminResponse: string | null
  needsAttention: boolean
  attentionReason: string | null
}

export interface FeaturedTestimonial {
  quote: string
  organization: string
  rating: number
  eventName: string
}

export interface RequesterFeedbackDashboardData {
  feedback: RequesterFeedbackItem[]
  stats: FeedbackOverviewStats
  featured: FeaturedTestimonial | null
}

export const DEFAULT_ADMIN_RESPONSE =
  'Thank you for your valuable feedback. We appreciate your suggestions and will continue improving our documentation services.'

const REVIEW_STATUS_KEY = 'requester_feedback_review_status'
const ADMIN_RESPONSE_KEY = 'requester_feedback_admin_response'
const PUBLISHED_KEY = 'media_library_published_ids'

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

export const FILTER_CHIPS: { id: FeedbackFilterChip; label: string }[] = [
  { id: 'pending', label: 'Pending review' },
  { id: 'needsAttention', label: 'Needs attention' },
  { id: 'all', label: 'All reviews' },
  { id: 'star5', label: '5 stars' },
  { id: 'star4', label: '4 stars' },
  { id: 'star3', label: '3 stars' },
  { id: 'star2', label: '2 stars' },
  { id: 'star1', label: '1 star' },
]

export function formatFeedbackDate(d: Date | null): string {
  if (!d) return '—'
  return `${MONTHS[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`
}

export function organizationInitials(organization: string): string {
  const parts = organization.trim().split(/\s+/)
  if (parts.length >= 2) return `${parts[0][0]}${parts[1][0]}`.toUpperCase()
  return organization.length > 0 ? organization[0].toUpperCase() : '?'
}

export function commentPreview(comment: string): string {
  const text = comment.trim()
  if (!text) return 'No written comment provided.'
  return text.length <= 120 ? text : `${text.slice(0, 117)}…`
}

function parseDate(raw: unknown): Date | null {
  if (raw == null) return null
  const d = new Date(String(raw))
  return Number.isNaN(d.getTime()) ? null : d
}

function loadMap(key: string): Record<string, string> {
  try {
    const raw = localStorage.getItem(key)
    if (!raw) return {}
    const decoded = JSON.parse(raw) as Record<string, string>
    return decoded ?? {}
  } catch {
    return {}
  }
}

export function clearLegacyFeedbackLocalStorage() {
  localStorage.removeItem(REVIEW_STATUS_KEY)
  localStorage.removeItem(ADMIN_RESPONSE_KEY)
  localStorage.removeItem(PUBLISHED_KEY)
}

/** One-time push of browser-only feedback admin data to the server. */
export async function migrateLegacyFeedbackLocalStorage(
  feedbackRows: Record<string, unknown>[],
  updateFn: (
    feedbackId: number,
    body: { admin_response?: string | null; review_status?: FeedbackReviewStatus },
  ) => Promise<unknown>,
): Promise<boolean> {
  const statusMap = loadMap(REVIEW_STATUS_KEY)
  const responseMap = loadMap(ADMIN_RESPONSE_KEY)
  if (Object.keys(statusMap).length === 0 && Object.keys(responseMap).length === 0) {
    return false
  }
  let migrated = false
  for (const row of feedbackRows) {
    const id = Number(row.id ?? 0)
    if (!id) continue
    const localStatus = statusMap[String(id)]
    const localResponse = responseMap[String(id)]
    const apiStatus = String(row.review_status ?? 'pending')
    const apiResponse = (row.admin_response as string | null | undefined)?.trim() ?? ''
    const patch: { admin_response?: string | null; review_status?: FeedbackReviewStatus } = {}
    if (localResponse && !apiResponse) patch.admin_response = localResponse
    if (localStatus && localStatus !== 'pending' && apiStatus === 'pending') {
      patch.review_status = parseReviewStatus(localStatus)
    }
    if (Object.keys(patch).length === 0) continue
    await updateFn(id, patch)
    migrated = true
  }
  if (migrated) clearLegacyFeedbackLocalStorage()
  return migrated
}

function parseReviewStatus(raw: string | undefined): FeedbackReviewStatus {
  if (raw === 'reviewed' || raw === 'archived') return raw
  return 'pending'
}

export interface EventServiceSummary {
  eventName: string
  photographers: string[]
  videographers: string[]
  photoCount: number
  videoCount: number
  facebookPublished: boolean
  completionDate: Date | null
}

export function parseFeedbackComment(comment: string): { type: string; body: string } {
  const text = comment.trim()
  const match = /^([^:]+):\s*(.+)$/s.exec(text)
  if (match) {
    return { type: match[1].trim(), body: match[2].trim() }
  }
  return { type: 'General', body: text }
}

function lowRatingAttention(rating: number, comment: string): string | null {
  if (rating >= 3) return null
  const c = comment.toLowerCase()
  if (c.includes('late') || c.includes('delay') || c.includes('slow')) {
    return 'Documentation delivered late.'
  }
  if (c.includes('missed') || c.includes('not captured') || c.includes('not documented') || c.includes('important')) {
    return 'Some important moments were not captured.'
  }
  if (c.includes('communication') || c.includes('respond') || c.includes('contact')) {
    return 'Communication could be improved.'
  }
  const text = comment.trim()
  if (!text) return 'Low overall satisfaction rating requires follow-up.'
  const first = text.split(/[.!?]/)[0]?.trim() ?? text
  if (first.length <= 80) return first.endsWith('.') ? first : `${first}.`
  return `${first.slice(0, 77)}…`
}

function buildEventSummary(input: {
  eventName: string
  request: ReturnType<typeof parseDocumentationRequest> | null
  tasks: Record<string, unknown>[]
  mediaFiles: Record<string, unknown>[]
}): EventServiceSummary {
  const photographers: string[] = []
  const videographers: string[] = []
  for (const t of input.tasks) {
    const name = String(t.member_name ?? 'Member')
    const role = String(t.task_role ?? '').toLowerCase()
    if (role.includes('video')) videographers.push(name)
    else if (role.includes('photo')) photographers.push(name)
  }

  let photos = 0
  let videos = 0
  let published = false
  let latestUpload: Date | null = null
  for (const m of input.mediaFiles) {
    const type = String(m.file_type ?? '').toLowerCase()
    if (type.includes('video')) videos++
    else photos++
    if (String(m.facebook_publish_status ?? '') === 'published') published = true
    const d = parseDate(m.uploaded_at)
    if (d && (!latestUpload || d > latestUpload)) latestUpload = d
  }

  return {
    eventName: input.request?.eventTitle ?? input.eventName,
    photographers,
    videographers,
    photoCount: photos,
    videoCount: videos,
    facebookPublished: published,
    completionDate: latestUpload ?? input.request?.eventDate ?? null,
  }
}

function organizationNames(users: Record<string, unknown>[]): Map<number, string> {
  const out = new Map<number, string>()
  for (const u of users) {
    const id = Number(u.user_id ?? u.id)
    if (!id) continue
    const role = String(u.role ?? '').toLowerCase()
    const name = String(u.name ?? u.fullname ?? '')
    out.set(id, name || (role.includes('org') ? 'Organization' : 'User'))
  }
  return out
}

function computeStats(items: RequesterFeedbackItem[]): FeedbackOverviewStats {
  if (items.length === 0) {
    return { averageRating: 0, totalReceived: 0, positiveReviews: 0, needsAttention: 0, pendingReview: 0 }
  }
  const sum = items.reduce((a, i) => a + i.rating, 0)
  return {
    averageRating: sum / items.length,
    totalReceived: items.length,
    positiveReviews: items.filter((i) => i.rating >= 4).length,
    needsAttention: items.filter((i) => i.needsAttention).length,
    pendingReview: items.filter((i) => i.reviewStatus === 'pending').length,
  }
}

function pickFeatured(items: RequesterFeedbackItem[]): FeaturedTestimonial | null {
  let candidates = items.filter((i) => i.rating === 5 && i.comment.trim().length >= 40)
  if (candidates.length === 0) {
    candidates = items.filter((i) => i.rating >= 4 && i.comment.trim().length > 0)
    if (candidates.length === 0) return null
  }
  candidates.sort((a, b) => b.comment.length - a.comment.length)
  const best = candidates[0]
  return {
    quote: best.comment.trim(),
    organization: best.organization,
    rating: best.rating,
    eventName: best.eventName,
  }
}

export function buildFeedbackDashboard(input: {
  feedbackRows: Record<string, unknown>[]
  requests: Record<string, unknown>[]
  tasks: Record<string, unknown>[]
  media: Record<string, unknown>[]
  users: Record<string, unknown>[]
}): RequesterFeedbackDashboardData {
  const statusMap = loadMap(REVIEW_STATUS_KEY)
  const responseMap = loadMap(ADMIN_RESPONSE_KEY)

  const tasksByRequest = new Map<number, Record<string, unknown>[]>()
  for (const t of input.tasks) {
    const rid = Number(t.request_id)
    if (!rid) continue
    if (!tasksByRequest.has(rid)) tasksByRequest.set(rid, [])
    tasksByRequest.get(rid)!.push(t)
  }

  const requestItems = input.requests.map((r) => {
    const id = Number(r.request_id ?? r.id ?? 0)
    return parseDocumentationRequest(r, tasksByRequest.get(id) ?? [])
  })
  const requestById = new Map(requestItems.map((r) => [r.id, r]))
  const orgByUserId = organizationNames(input.users)

  const mediaByRequest = new Map<number, Record<string, unknown>[]>()
  for (const m of input.media) {
    const rid = Number(m.request_id)
    if (!rid) continue
    if (!mediaByRequest.has(rid)) mediaByRequest.set(rid, [])
    mediaByRequest.get(rid)!.push(m)
  }

  const feedback: RequesterFeedbackItem[] = []
  for (const row of input.feedbackRows) {
    const id = Number(row.id ?? 0)
    const requestId = Number(row.request_id ?? 0)
    const req = requestById.get(requestId)
    const rating = Math.min(5, Math.max(1, Math.round(Number(row.rating ?? 1))))
    const comment = String(row.comment ?? row.feedback ?? row.message ?? '')
    const reviewStatus = parseReviewStatus(
      String(row.review_status ?? statusMap[String(id)] ?? 'pending'),
    )
    const adminResponse =
      (row.admin_response as string | null | undefined)?.trim() ||
      responseMap[String(id)]?.trim() ||
      null
    const submittedAt = parseDate(row.created_at)
    const eventName = String(row.event_title ?? row.event_name ?? req?.eventTitle ?? 'Event')

    const summary = buildEventSummary({
      eventName,
      request: req ?? null,
      tasks: tasksByRequest.get(requestId) ?? [],
      mediaFiles: mediaByRequest.get(requestId) ?? [],
    })

    const attention = lowRatingAttention(rating, comment)

    feedback.push({
      id,
      requestId,
      eventName: summary.eventName,
      organization: req ? (orgByUserId.get(req.requesterId) ?? req.requestor) : String(row.member_name ?? 'Organization'),
      requesterName: String(row.user_name ?? row.member_name ?? req?.requestor ?? 'Requester'),
      eventDate: req?.eventDate ?? null,
      submittedAt,
      completionDate: summary.completionDate,
      rating,
      comment,
      reviewStatus,
      eventSummary: summary,
      adminResponse,
      needsAttention: attention != null,
      attentionReason: attention,
    })
  }

  feedback.sort((a, b) => (b.submittedAt?.getTime() ?? 0) - (a.submittedAt?.getTime() ?? 0))

  const active = feedback.filter((f) => f.reviewStatus !== 'archived')
  return {
    feedback,
    stats: computeStats(active),
    featured: pickFeatured(active),
  }
}

export function matchesChip(item: RequesterFeedbackItem, chip: FeedbackFilterChip): boolean {
  if (item.reviewStatus === 'archived' && chip !== 'all') return false
  switch (chip) {
    case 'all':
      return item.reviewStatus !== 'archived'
    case 'pending':
      return item.reviewStatus === 'pending'
    case 'needsAttention':
      return item.needsAttention
    case 'star5':
      return item.rating === 5
    case 'star4':
      return item.rating === 4
    case 'star3':
      return item.rating === 3
    case 'star2':
      return item.rating === 2
    case 'star1':
      return item.rating === 1
    default:
      return true
  }
}

export function filterFeedback(
  items: RequesterFeedbackItem[],
  chip: FeedbackFilterChip,
  search: string,
): RequesterFeedbackItem[] {
  const q = search.trim().toLowerCase()
  return items.filter((item) => {
    if (!matchesChip(item, chip)) return false
    if (!q) return true
    return (
      item.eventName.toLowerCase().includes(q) ||
      item.organization.toLowerCase().includes(q) ||
      item.requesterName.toLowerCase().includes(q) ||
      String(item.rating).includes(q) ||
      (item.eventDate != null && formatFeedbackDate(item.eventDate).toLowerCase().includes(q))
    )
  })
}

export function buildExportReport(data: RequesterFeedbackDashboardData): string {
  const lines: string[] = [
    'ACCESS VisionCheck — Requester Feedback Report',
    `Generated: ${new Date().toLocaleString()}`,
    '',
    'Overview',
    `  Average satisfaction: ${data.stats.averageRating > 0 ? data.stats.averageRating.toFixed(1) : '—'} / 5`,
    `  Total feedback received: ${data.stats.totalReceived}`,
    `  Positive reviews (4–5★): ${data.stats.positiveReviews}`,
    `  Needs attention: ${data.stats.needsAttention}`,
    `  Pending admin review: ${data.stats.pendingReview}`,
    '',
  ]
  for (const f of data.feedback.filter((i) => i.reviewStatus !== 'archived')) {
    lines.push(`${f.eventName} — ${f.organization}`)
    lines.push(`  Rating: ${f.rating}/5 · Submitted ${formatFeedbackDate(f.submittedAt)}`)
    lines.push(`  Requester: ${f.requesterName}`)
    if (f.comment) lines.push(`  Comment: ${f.comment}`)
    if (f.adminResponse) lines.push(`  Admin response: ${f.adminResponse}`)
    lines.push('')
  }
  return lines.join('\n')
}
