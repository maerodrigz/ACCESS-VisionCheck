import { fetchServiceRequests, fetchUsers } from '../api/admin'
import { fetchEventMedia } from '../api/eventMedia'
import { allNavItems } from '../config/navigation'
import {
  documentationRequestUrl,
  memberManagementUrl,
  memberUploadUrl,
} from './adminCrossLinks'

export type GlobalSearchResult = {
  path: string
  hint: string
}

function requestTitle(row: Record<string, unknown>): string {
  return String(row.title ?? row.event_name ?? row.eventName ?? '').trim()
}

/** Pick the best admin route for a dashboard search query. */
export async function resolveGlobalSearch(query: string): Promise<GlobalSearchResult> {
  const q = query.trim()
  if (!q) {
    return { path: '/', hint: 'Enter a search term' }
  }
  const lower = q.toLowerCase()

  for (const item of allNavItems) {
    if (item.label.toLowerCase().includes(lower)) {
      return { path: item.path, hint: `Open ${item.label}` }
    }
  }

  const [users, requestsRaw, mediaRows] = await Promise.all([
    fetchUsers().catch(() => []),
    fetchServiceRequests().catch(() => []),
    fetchEventMedia({ search: q }).catch(() => []),
  ])

  const member = users.find((u) => {
    const name = u.name.toLowerCase()
    const email = u.email.toLowerCase()
    const sid = (u.student_id ?? '').toLowerCase()
    return name.includes(lower) || email.includes(lower) || sid.includes(lower)
  })
  if (member) {
    return { path: memberManagementUrl(member.name), hint: `Member: ${member.name}` }
  }

  const request = requestsRaw.find((row) => {
    const title = requestTitle(row).toLowerCase()
    const venue = String(row.venue ?? '').toLowerCase()
    const desc = String(row.description ?? '').toLowerCase()
    return title.includes(lower) || venue.includes(lower) || desc.includes(lower)
  })
  if (request) {
    const id = Number(request.id ?? request.request_id ?? 0)
    if (id > 0) {
      return { path: documentationRequestUrl(id), hint: `Request: ${requestTitle(request)}` }
    }
  }

  if (mediaRows.length > 0) {
    const first = mediaRows[0]
    const name = String(first.file_name ?? 'Media')
    return {
      path: memberUploadUrl({ mediaId: first.id, q: q }),
      hint: `Media: ${name}`,
    }
  }

  return {
    path: `/documentation-requests?q=${encodeURIComponent(q)}`,
    hint: `Search documentation for "${q}"`,
  }
}
