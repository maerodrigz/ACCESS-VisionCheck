import {
  Activity,
  KeyRound,
  LogIn,
  MoreVertical,
  Shield,
  User,
  UserCheck,
  UserCog,
  UserX,
} from 'lucide-react'
import {
  accountStatusKey,
  canChangePrivilegedFields,
  type AdminAccountUser,
} from '../../lib/accountManagement'

interface Props {
  user: AdminAccountUser
  allUsers: AdminAccountUser[]
  open: boolean
  onToggle: () => void
  onViewProfile: () => void
  onEdit: () => void
  onChangeRole: () => void
  onResetPassword: () => void
  onToggleActive: () => void
}

function MenuItem({
  icon: Icon,
  label,
  onClick,
  danger,
  disabled,
  title,
}: {
  icon: typeof User
  label: string
  onClick: () => void
  danger?: boolean
  disabled?: boolean
  title?: string
}) {
  return (
    <button
      type="button"
      role="menuitem"
      className={`account-mgmt__menu-item${danger ? ' account-mgmt__menu-item--danger' : ''}`}
      onClick={disabled ? undefined : onClick}
      disabled={disabled}
      title={title}
    >
      <Icon size={16} className="account-mgmt__menu-icon" aria-hidden />
      <span>{label}</span>
    </button>
  )
}

export function AccountActionsMenu({
  user,
  allUsers,
  open,
  onToggle,
  onViewProfile,
  onEdit,
  onChangeRole,
  onResetPassword,
  onToggleActive,
}: Props) {
  const sk = accountStatusKey(user)
  const protectedAdmin = !canChangePrivilegedFields(user, allUsers)
  const activateLabel = sk === 'active' ? 'Deactivate Account' : 'Activate Account'

  return (
    <div className="account-mgmt__menu-wrap">
      <button
        type="button"
        className={`account-mgmt__menu-trigger${open ? ' account-mgmt__menu-trigger--open' : ''}`}
        onClick={(e) => {
          e.stopPropagation()
          onToggle()
        }}
        aria-label={`Actions for ${user.name}`}
        aria-expanded={open}
        aria-haspopup="menu"
      >
        <MoreVertical size={18} aria-hidden />
      </button>
      {open ? (
        <div className="account-mgmt__menu" role="menu" aria-label="Account actions">
          <MenuItem icon={User} label="View Profile" onClick={onViewProfile} />
          <MenuItem icon={UserCog} label="Edit Account" onClick={onEdit} />
          <MenuItem
            icon={Shield}
            label="Change Role"
            onClick={onChangeRole}
            disabled={protectedAdmin}
            title={
              protectedAdmin ? 'Cannot change role for the last active administrator.' : undefined
            }
          />
          <MenuItem icon={KeyRound} label="Reset Password" onClick={onResetPassword} />
          <hr className="account-mgmt__menu-divider" />
          <MenuItem
            icon={sk === 'active' ? UserX : UserCheck}
            label={activateLabel}
            onClick={onToggleActive}
            danger={sk === 'active'}
            disabled={protectedAdmin && sk === 'active'}
            title={
              protectedAdmin && sk === 'active'
                ? 'Cannot deactivate the last active administrator.'
                : undefined
            }
          />
        </div>
      ) : null}
    </div>
  )
}

export function ActivityIcon({ kind }: { kind: string }) {
  const Icon = kind === 'login' ? LogIn : Activity
  return (
    <span className="account-mgmt__activity-icon" aria-hidden>
      <Icon size={16} aria-hidden />
    </span>
  )
}
