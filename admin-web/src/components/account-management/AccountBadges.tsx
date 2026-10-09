import { useState } from 'react'
import { mediaUrl } from '../../api/media'
import {
  accountRoleLabel,
  initialsFromName,
  statusLabel,
  type AccountRole,
  type AccountStatusKey,
  type AdminAccountUser,
} from '../../lib/accountManagement'

/** Table/profile avatar: show uploaded photo when available, else initials tile. */
export function AccountUserAvatar({ user }: { user: AdminAccountUser }) {
  const [imgFailed, setImgFailed] = useState(false)
  const avatarUrl = mediaUrl(user.profile_image)
  const initials = initialsFromName(user.name)

  if (avatarUrl && !imgFailed) {
    return (
      <img
        src={avatarUrl}
        alt=""
        className="account-mgmt__avatar account-mgmt__avatar--img"
        onError={() => setImgFailed(true)}
      />
    )
  }

  return (
    <span className="account-mgmt__avatar" aria-hidden>
      {initials || '?'}
    </span>
  )
}

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
  return (
    <span className={`account-mgmt__badge account-mgmt__status-badge ${cls}`}>{statusLabel(statusKey)}</span>
  )
}
