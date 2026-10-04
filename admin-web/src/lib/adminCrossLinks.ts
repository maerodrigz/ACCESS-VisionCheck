/** Deep-link builders for admin workflow navigation. */

/** Competency portfolio drawer for a member (deep link after data load). */
export function memberCompetencyProfileUrl(userId: number): string {
  return `/competency?member=${userId}`
}

/** Member management search when user id is unknown. */
export function memberManagementUrl(memberName: string): string {
  return `/members?q=${encodeURIComponent(memberName.trim())}`
}

export function memberPortfolioUrl(opts: { userId?: number | null; memberName?: string }): string {
  const id = opts.userId != null && opts.userId > 0 ? opts.userId : 0
  if (id) return memberCompetencyProfileUrl(id)
  const name = (opts.memberName ?? '').trim()
  if (name) return memberManagementUrl(name)
  return '/competency'
}

export function memberUploadUrl(opts?: {
  mediaId?: number
  q?: string
  format?: 'photos' | 'videos'
}): string {
  const params = new URLSearchParams()
  if (opts?.mediaId) params.set('media', String(opts.mediaId))
  if (opts?.q?.trim()) params.set('q', opts.q.trim())
  if (opts?.format) params.set('format', opts.format)
  const qs = params.toString()
  return qs ? `/media?${qs}` : '/media'
}

/** Evaluation Review page removed — deep links open Event Media instead. */
export function evaluationReviewUrl(opts?: { evaluationId?: number; mediaId?: number }): string {
  void opts?.evaluationId
  return memberUploadUrl({ mediaId: opts?.mediaId })
}

export function mediaIntegrityUrl(mediaId: number): string {
  return `/media-integrity?media=${mediaId}`
}

export function documentationRequestUrl(requestId: number): string {
  return `/documentation-requests?request=${requestId}`
}

export function eventCalendarUrl(opts?: { eventId?: number; requestId?: number }): string {
  const params = new URLSearchParams()
  if (opts?.eventId) params.set('event', String(opts.eventId))
  else if (opts?.requestId) params.set('request', String(opts.requestId))
  const qs = params.toString()
  return qs ? `/event-calendar?${qs}` : '/event-calendar'
}
