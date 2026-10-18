import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react'
import { ChevronDown, ChevronRight, KeyRound, Settings, User } from 'lucide-react'
import { useLocation, useNavigate } from 'react-router-dom'
import type { AuthUser } from '../types/auth'
import { roleDisplayLabel } from '../lib/roles'
import { ChangePasswordDialog } from './ChangePasswordDialog'
import { MyProfileDialog } from './MyProfileDialog'
import { MemberAvatar } from './documentation-team/TeamMemberBadges'
import './profile-dropdown.css'

type MenuId = 'my-profile' | 'system-configuration'

const ADMIN_ROUTES: Record<string, MenuId> = {
  '/system-configuration': 'system-configuration',
}

interface ProfileDropdownProps {
  user: AuthUser
}

function userInitial(name: string) {
  const n = name.trim()
  return n ? n.charAt(0).toUpperCase() : 'A'
}

function ProfileAvatar({
  name,
  profileImage,
  size,
}: {
  name: string
  profileImage?: string | null
  size: 'sm' | 'lg'
}) {
  if (profileImage) {
    return (
      <MemberAvatar
        name={name}
        avatarUrl={profileImage}
        size={size === 'lg' ? 'lg' : 'sm'}
        className={size === 'sm' ? '!h-10 !w-10' : 'mx-auto block'}
        fallbackClassName="profile-dropdown__avatar"
      />
    )
  }
  return (
    <span
      className={[
        'profile-dropdown__avatar',
        size === 'lg' ? 'profile-dropdown__avatar--lg mx-auto' : '',
      ]
        .filter(Boolean)
        .join(' ')}
      aria-hidden="true"
    >
      {userInitial(name)}
    </span>
  )
}

export function ProfileDropdown({ user }: ProfileDropdownProps) {
  const rootRef = useRef<HTMLDivElement>(null)
  const navigate = useNavigate()
  const location = useLocation()
  const [open, setOpen] = useState(false)
  const [profileOpen, setProfileOpen] = useState(false)
  const [changePasswordOpen, setChangePasswordOpen] = useState(false)
  const role = roleDisplayLabel(user.role)
  const isAdmin = user.role === 'Admin'

  const activeItem = ADMIN_ROUTES[location.pathname] ?? null

  const closeDropdown = useCallback(() => setOpen(false), [])

  useEffect(() => {
    if (!open) return
    function onOutside(e: MouseEvent) {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) {
        closeDropdown()
      }
    }
    document.addEventListener('mousedown', onOutside)
    return () => document.removeEventListener('mousedown', onOutside)
  }, [open, closeDropdown])

  useEffect(() => {
    function onEscape(e: KeyboardEvent) {
      if (e.key !== 'Escape') return
      if (changePasswordOpen) {
        setChangePasswordOpen(false)
        return
      }
      if (profileOpen) {
        setProfileOpen(false)
        return
      }
      if (open) {
        closeDropdown()
      }
    }
    document.addEventListener('keydown', onEscape)
    return () => document.removeEventListener('keydown', onEscape)
  }, [open, profileOpen, changePasswordOpen, closeDropdown])

  function toggleDropdown() {
    setOpen((v) => !v)
  }

  function handleMenu(id: MenuId) {
    closeDropdown()
    if (id === 'my-profile') {
      setProfileOpen(true)
      return
    }
    if (id === 'system-configuration') {
      navigate('/system-configuration')
    }
  }

  const menuBtn = (
    id: MenuId,
    label: string,
    icon: ReactNode,
    variant: 'account' | 'admin',
  ) => {
    const isActive = activeItem === id
    return (
    <li className="profile-dropdown__item" role="none">
      <button
        type="button"
        className={[
          'profile-dropdown__link',
          `profile-dropdown__link--${variant}`,
          isActive ? 'is-active' : '',
        ]
          .filter(Boolean)
          .join(' ')}
        role="menuitem"
        aria-current={isActive ? 'page' : undefined}
        onClick={() => handleMenu(id)}
      >
        <span className="profile-dropdown__icon" aria-hidden="true">
          {icon}
        </span>
        <span className="profile-dropdown__label">{label}</span>
        {variant === 'admin' && (
          <span className="profile-dropdown__item-chevron" aria-hidden="true">
            <ChevronRight size={16} strokeWidth={2} />
          </span>
        )}
      </button>
    </li>
  )
  }

  return (
    <>
      <div
        ref={rootRef}
        className={['profile-dropdown', open ? 'is-open' : ''].filter(Boolean).join(' ')}
      >
        <button
          type="button"
          className="profile-dropdown__trigger"
          aria-label="Open admin profile menu"
          aria-haspopup="true"
          aria-expanded={open}
          onClick={toggleDropdown}
        >
          <span className="profile-dropdown__trigger-text">
            <span className="profile-dropdown__trigger-name">{user.name}</span>
            <span className="profile-dropdown__trigger-role">{role}</span>
          </span>
          <ProfileAvatar name={user.name} profileImage={user.profileImage} size="sm" />
          <ChevronDown size={18} className="profile-dropdown__chevron" aria-hidden="true" />
        </button>

        <div
          className="profile-dropdown__panel"
          role="menu"
          aria-label="Admin profile menu"
          aria-hidden={!open}
        >
          <section className="profile-dropdown__user" aria-label="User information">
            <div className="profile-dropdown__user-avatar">
              <ProfileAvatar name={user.name} profileImage={user.profileImage} size="lg" />
            </div>
            <h2 className="profile-dropdown__user-name">{user.name}</h2>
            <p className="profile-dropdown__user-email">{user.email}</p>
            <span className="profile-dropdown__badge">{role}</span>
          </section>

          <hr className="profile-dropdown__divider" />

          <section className="profile-dropdown__section" aria-label="Account">
            <ul className="profile-dropdown__menu" role="none">
              {menuBtn('my-profile', 'My Profile', <User size={18} strokeWidth={2} />, 'account')}
              <li className="profile-dropdown__item" role="none">
                <button
                  type="button"
                  className="profile-dropdown__link profile-dropdown__link--account"
                  role="menuitem"
                  onClick={() => {
                    closeDropdown()
                    setChangePasswordOpen(true)
                  }}
                >
                  <span className="profile-dropdown__icon" aria-hidden="true">
                    <KeyRound size={18} strokeWidth={2} />
                  </span>
                  <span className="profile-dropdown__label">Change password</span>
                </button>
              </li>
            </ul>
          </section>

          {isAdmin && (
            <>
              <hr className="profile-dropdown__divider" />
              <section className="profile-dropdown__section" aria-label="Administration">
                <h3 className="profile-dropdown__section-title">Administration</h3>
                <ul className="profile-dropdown__menu" role="none">
                  {menuBtn(
                    'system-configuration',
                    'System Configuration',
                    <Settings size={18} strokeWidth={2} />,
                    'admin',
                  )}
                </ul>
              </section>
            </>
          )}
        </div>
      </div>

      <MyProfileDialog open={profileOpen} user={user} onClose={() => setProfileOpen(false)} />

      <ChangePasswordDialog open={changePasswordOpen} onClose={() => setChangePasswordOpen(false)} />
    </>
  )
}
