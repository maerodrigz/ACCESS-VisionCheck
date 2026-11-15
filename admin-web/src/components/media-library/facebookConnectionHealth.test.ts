import { describe, expect, it } from 'vitest'
import type { FacebookConfigStatus } from '../../api/eventMedia'

/** Pure helpers mirrored from UI rules — keep frontend free of credential fields. */
function expiryLabel(config: FacebookConfigStatus): string {
  const health = config.health
  if (health?.expiry_label) return health.expiry_label
  if (health?.expiry_visibility === 'never') return 'Never (confirmed by Meta)'
  return 'Expiration not confirmed'
}

function connectionLabel(status: string | undefined): string {
  switch ((status || 'unknown').toLowerCase()) {
    case 'connected':
      return 'Connected'
    case 'needs_attention':
      return 'Needs Attention'
    case 'disconnected':
      return 'Disconnected'
    default:
      return 'Unknown'
  }
}

describe('Facebook connection health display', () => {
  it('shows Expiration not confirmed when Meta expiry is unknown', () => {
    const config: FacebookConfigStatus = {
      configured: true,
      browser_share_available: true,
      page_id_set: true,
      access_token_set: true,
      page_token_valid: true,
      missing: [],
      reminder: 'ok',
      health: {
        connection_status: 'connected',
        page_id: '1202339146306816',
        page_name: 'ACCESS',
        last_verified_at: '2026-11-15T02:00:00Z',
        last_ok: true,
        last_error: null,
        expiry_visibility: 'unknown',
        expiry_label: 'Expiration not confirmed',
      },
    }
    expect(expiryLabel(config)).toBe('Expiration not confirmed')
    expect(connectionLabel(config.health?.connection_status)).toBe('Connected')
    expect(JSON.stringify(config)).not.toMatch(/EAA/)
    expect(JSON.stringify(config)).not.toMatch(/access_token["']?\s*:/)
  })

  it('maps needs_attention for invalid token health', () => {
    expect(connectionLabel('needs_attention')).toBe('Needs Attention')
    expect(connectionLabel('disconnected')).toBe('Disconnected')
    expect(connectionLabel(undefined)).toBe('Unknown')
  })
})
