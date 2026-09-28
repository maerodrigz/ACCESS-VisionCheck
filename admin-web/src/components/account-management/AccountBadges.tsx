import {
  accountRoleLabel,
  statusLabel,
  type AccountRole,
  type AccountStatusKey,
} from '../../lib/accountManagement'

export function RoleBadge({ role }: { role: AccountRole | string }) {
  const cls =
    role === 'Admin'
      ? 'account-mgmt__badge--admin'
      : role === 'Organization'
        ? 'account-mgmt__badge--org'
        : 'account-mgmt__badge--member'
  return <span className={`account-mgmt__badge ${cls}`}>{accountRoleLabel(role)}</span>
}

export function StatusBadge({ statusKey }: { statusKey: AccountStatusKey }) {
  const cls =
    statusKey === 'active'
      ? 'account-mgmt__badge--active'
      : statusKey === 'suspended'
        ? 'account-mgmt__badge--suspended'
        : 'account-mgmt__badge--inactive'
  return <span className={`account-mgmt__badge ${cls}`}>{statusLabel(statusKey)}</span>
}
