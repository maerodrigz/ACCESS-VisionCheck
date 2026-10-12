const STORAGE_KEY = 'access_admin_token'

/** Use Vite proxy in dev (`/api`) or set VITE_API_BASE_URL in .env */
export const API_BASE =
  import.meta.env.VITE_API_BASE_URL?.replace(/\/$/, '') || '/api'

export class ApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

let unauthorizedHandler: (() => void) | null = null

/** Clears session when any API call returns 401 (expired or invalid JWT). */
export function setUnauthorizedHandler(handler: (() => void) | null) {
  unauthorizedHandler = handler
}

function isAuthFailure(status: number, message: string): boolean {
  if (status !== 401) return false
  const lower = message.toLowerCase()
  return (
    lower.includes('invalid token') ||
    lower.includes('no token') ||
    lower.includes('user not found')
  )
}

export function getStoredToken(): string | null {
  return localStorage.getItem(STORAGE_KEY)
}

export function setStoredToken(token: string | null) {
  if (token) localStorage.setItem(STORAGE_KEY, token)
  else localStorage.removeItem(STORAGE_KEY)
}

async function parseJson(res: Response): Promise<unknown> {
  const text = await res.text()
  if (!text) return null
  try {
    return JSON.parse(text)
  } catch {
    return text
  }
}

/** Turn FastAPI error payloads into a readable string. */
export function formatApiError(data: unknown, status: number): string {
  if (typeof data === 'string' && data.trim()) return data.trim()
  if (typeof data === 'object' && data !== null && 'detail' in data) {
    const detail = (data as { detail: unknown }).detail
    if (typeof detail === 'string' && detail.trim()) return detail.trim()
    if (Array.isArray(detail)) {
      return detail
        .map((item) => {
          if (typeof item === 'string') return item
          if (typeof item === 'object' && item !== null && 'msg' in item) {
            return String((item as { msg: unknown }).msg)
          }
          return JSON.stringify(item)
        })
        .join('; ')
    }
    if (typeof detail === 'object' && detail !== null) {
      if ('message' in detail) return String((detail as { message: unknown }).message)
      if ('msg' in detail) return String((detail as { msg: unknown }).msg)
      try {
        return JSON.stringify(detail)
      } catch {
        return `Request failed (${status})`
      }
    }
  }
  if (typeof data === 'object' && data !== null && 'message' in data) {
    return String((data as { message: unknown }).message)
  }
  return `Request failed (${status})`
}

export async function apiRequest<T>(
  path: string,
  options: RequestInit = {},
  token?: string | null,
): Promise<T> {
  const auth = token ?? getStoredToken()
  const headers = new Headers(options.headers)
  if (!headers.has('Content-Type') && options.body) {
    headers.set('Content-Type', 'application/json')
  }
  if (auth) headers.set('Authorization', `Bearer ${auth}`)

  const res = await fetch(`${API_BASE}${path}`, { ...options, headers })
  const data = await parseJson(res)

  if (!res.ok) {
    const msg = formatApiError(data, res.status)
    if (isAuthFailure(res.status, msg)) {
      setStoredToken(null)
      unauthorizedHandler?.()
    }
    throw new ApiError(msg, res.status)
  }

  return data as T
}

/** Multipart upload (e.g. POST /media/upload). Do not set Content-Type — browser sets boundary. */
export async function apiUpload<T>(
  path: string,
  file: File,
  fields: Record<string, string> = {},
): Promise<T> {
  const auth = getStoredToken()
  const form = new FormData()
  form.append('file', file)
  for (const [key, value] of Object.entries(fields)) {
    form.append(key, value)
  }
  const headers = new Headers()
  if (auth) headers.set('Authorization', `Bearer ${auth}`)

  const res = await fetch(`${API_BASE}${path}`, { method: 'POST', headers, body: form })
  const data = await parseJson(res)

  if (!res.ok) {
    const msg = formatApiError(data, res.status) || `Upload failed (${res.status})`
    if (isAuthFailure(res.status, msg)) {
      setStoredToken(null)
      unauthorizedHandler?.()
    }
    throw new ApiError(msg, res.status)
  }

  return data as T
}

export async function checkBackendHealth(timeoutMs = 5000): Promise<boolean> {
  try {
    const res = await fetch(`${API_BASE}/health`, {
      method: 'GET',
      signal: AbortSignal.timeout(timeoutMs),
    })
    return res.ok
  } catch {
    return false
  }
}
