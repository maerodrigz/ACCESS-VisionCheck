import { describe, expect, it } from 'vitest'
import {
  accountStatusKey,
  filterAccounts,
  isAccountOnline,
  parseAdminAccountUser,
  presenceSummary,
  statusLabel,
  type AdminAccountUser,
} from './accountManagement'

function user(partial: Partial<AdminAccountUser> & { email: string }): AdminAccountUser {
  return parseAdminAccountUser({
    user_id: partial.user_id ?? 1,
    name: partial.name ?? 'Test',
    email: partial.email,
    role: partial.role ?? 'Member',
    status: partial.status ?? 'approved',
    is_active: partial.is_active ?? true,
    is_online: partial.is_online ?? false,
    is_inactive: partial.is_inactive ?? false,
    presence: partial.presence ?? 'Offline',
    account_status: partial.account_status ?? 'Active',
    last_seen_at: partial.last_seen_at ?? null,
    last_login_at: partial.last_login_at ?? null,
  })
}

describe('account presence helpers', () => {
  it('summarizes online/offline/inactive/disabled from real flags', () => {
    const rows = [
      user({ email: 'a@x.com', is_online: true, presence: 'Online' }),
      user({ email: 'b@x.com', is_online: false, presence: 'Offline' }),
      user({ email: 'c@x.com', is_online: false, is_inactive: true }),
      user({ email: 'd@x.com', is_active: false, account_status: 'Disabled' }),
    ]
    const s = presenceSummary(rows)
    expect(s.online).toBe(1)
    expect(s.offline).toBe(2)
    expect(s.inactive).toBe(1)
    expect(s.disabled).toBe(1)
  })

  it('filters presence without inventing activity', () => {
    const rows = [
      user({ user_id: 1, email: 'on@x.com', is_online: true, presence: 'Online' }),
      user({ user_id: 2, email: 'off@x.com', is_online: false }),
      user({ user_id: 3, email: 'dead@x.com', is_active: false, account_status: 'Disabled' }),
    ]
    expect(filterAccounts(rows, '', 'all', 'all', 'online').map((u) => u.email)).toEqual(['on@x.com'])
    expect(filterAccounts(rows, '', 'all', 'all', 'disabled').map((u) => u.email)).toEqual(['dead@x.com'])
    expect(isAccountOnline(rows[2])).toBe(false)
  })

  it('maps account enablement to Active / Disabled separately from presence', () => {
    const activeOffline = user({
      email: 'active-off@x.com',
      is_active: true,
      account_status: 'Active',
      is_online: false,
      presence: 'Offline',
    })
    const disabled = user({
      email: 'off-acct@x.com',
      is_active: false,
      account_status: 'Disabled',
      is_online: false,
      presence: 'Offline',
    })
    expect(accountStatusKey(activeOffline)).toBe('active')
    expect(statusLabel(accountStatusKey(activeOffline))).toBe('Active')
    expect(isAccountOnline(activeOffline)).toBe(false)
    expect(accountStatusKey(disabled)).toBe('disabled')
    expect(statusLabel(accountStatusKey(disabled))).toBe('Disabled')
  })
})
