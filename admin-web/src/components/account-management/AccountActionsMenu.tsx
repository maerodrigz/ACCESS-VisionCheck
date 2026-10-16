import { useEffect, useId, useLayoutEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
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
  Trash2,
} from 'lucide-react'
import {
  accountStatusKey,
  canChangePrivilegedFields,
  type AdminAccountUser,
} from '../../lib/accountManagement'

function accountMgmtPortalRoot(): HTMLElement {
  return document.body
}

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
  onDeleteMember?: () => void
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
  onDeleteMember,
}: Props) {
  const sk = accountStatusKey(user)
  const protectedAdmin = !canChangePrivilegedFields(user, allUsers)
  const activateLabel = sk === 'active' ? 'Deactivate Account' : 'Activate Account'
  const menuId = useId()
  const menuRef = useRef<HTMLDivElement>(null)
  const triggerRef = useRef<HTMLButtonElement>(null)
  const [menuPos, setMenuPos] = useState<{ top: number; left: number } | null>(null)

  useLayoutEffect(() => {
    if (!open || !triggerRef.current) {
      setMenuPos(null)
      return
    }

    function placeMenu() {
      const trigger = triggerRef.current
      const menu = menuRef.current
      if (!trigger) return
      const rect = trigger.getBoundingClientRect()
      const menuWidth = 216
      const gap = 6
      const left = Math.max(8, Math.min(rect.right - menuWidth, window.innerWidth - menuWidth - 8))
      const menuHeight = menu?.offsetHeight ?? 260
      let top = rect.bottom + gap
      if (top + menuHeight > window.innerHeight - 8) {
        top = Math.max(8, rect.top - menuHeight - gap)
      }
      setMenuPos({ top, left })
    }

    placeMenu()
    requestAnimationFrame(placeMenu)
    window.addEventListener('resize', placeMenu)
    window.addEventListener('scroll', placeMenu, true)
    return () => {
      window.removeEventListener('resize', placeMenu)
      window.removeEventListener('scroll', placeMenu, true)
    }
  }, [open])

  useEffect(() => {
    if (!open) return
    const first = menuRef.current?.querySelector<HTMLElement>('[role="menuitem"]:not([disabled])')
    first?.focus()
  }, [open, menuPos])

  const menuPanel = open ? (
    <div
      ref={menuRef}
      id={menuId}
      className="account-mgmt__menu account-mgmt__menu--portal"
      role="menu"
      aria-label="Account actions"
      style={
        menuPos
          ? { top: `${menuPos.top}px`, left: `${menuPos.left}px`, visibility: 'visible' }
          : { top: '-9999px', left: '-9999px', visibility: 'hidden' as const }
      }
    >
      <MenuItem icon={User} label="View Profile" onClick={onViewProfile} />
      <MenuItem icon={UserCog} label="Edit Account" onClick={onEdit} />
      <MenuItem
        icon={Shield}
        label="Change Role"
        onClick={onChangeRole}
        disabled={protectedAdmin}
        title={protectedAdmin ? 'Cannot change role for the last active administrator.' : undefined}
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
      {user.role === 'Member' && onDeleteMember ? (
        <>
          <hr className="account-mgmt__menu-divider" />
          <MenuItem
            icon={Trash2}
            label="Delete account permanently"
            onClick={onDeleteMember}
            danger
          />
        </>
      ) : null}
    </div>
  ) : null

  return (
    <div className="account-mgmt__menu-wrap">
      <button
        ref={triggerRef}
        type="button"
        className={`account-mgmt__menu-trigger${open ? ' account-mgmt__menu-trigger--open' : ''}`}
        onClick={(e) => {
          e.stopPropagation()
          onToggle()
        }}
        aria-label={`Actions for ${user.name}`}
        aria-expanded={open}
        aria-haspopup="menu"
        aria-controls={menuId}
      >
        <MoreVertical size={16} aria-hidden />
      </button>
      {menuPanel ? createPortal(menuPanel, accountMgmtPortalRoot()) : null}
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