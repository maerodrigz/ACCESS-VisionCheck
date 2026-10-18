import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { ClipboardCheck, Loader2, RefreshCw, Search, UserPlus, Users } from 'lucide-react'
import {
  createUser,
  fetchUserProfile,
  fetchUsers,
  permanentlyDeleteMemberAccount,
  resetUserPassword,
  setUserStatus,
  updateUser,
  updateUserRole,
} from '../api/admin'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { AccountActionModal, type AccountActionState } from '../components/account-management/AccountActionModal'
import { DeactivateMemberDialog } from '../components/DeactivateMemberDialog'
import { DeleteMemberAccountDialog } from '../components/DeleteMemberAccountDialog'
import { AccountFormModal } from '../components/account-management/AccountFormModal'
import { AccountProfileModal } from '../components/account-management/AccountProfileModal'
import { AccountsTableSection } from '../components/account-management/AccountsTableSection'
import { RegistrationApprovalsPanel } from '../components/account-management/RegistrationApprovalsPanel'
import type { RegistrationApprovalTab } from '../lib/registrations'
import { useToast } from '../context/ToastContext'
import {
  ACCOUNT_ROLES,
  accountRoleLabel,
  accountStatusKey,
  accountSummaryText,
  canChangePrivilegedFields,
  defaultAccountForm,
  filterAccounts,
  formFromUser,
  isRequestorRole,
  mapStatusToApi,
  parseAdminAccountUser,
  type AccountFormValues,
  type AdminAccountUser,
  type ProfileActivity,
} from '../lib/accountManagement'
import '../../components/account-management.css'

function parseRegistrationTab(raw: string | null): RegistrationApprovalTab {
  if (raw === 'members' || raw === 'faculty_instructors' || raw === 'organizations') return raw
  return 'all'
}

export function AccountManagementPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const [allUsers, setAllUsers] = useState<AdminAccountUser[]>([])
  const [showRegistrations, setShowRegistrations] = useState(
    () => searchParams.get('view') === 'registrations',
  )
  const [registrationTab, setRegistrationTab] = useState<RegistrationApprovalTab>(() =>
    parseRegistrationTab(searchParams.get('tab')),
  )
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState('all')
  const [statusFilter, setStatusFilter] = useState('all')
  const [openMenuId, setOpenMenuId] = useState<number | null>(null)

  const [profileUserId, setProfileUserId] = useState<number | null>(null)
  const [profileLoading, setProfileLoading] = useState(false)
  const [profileError, setProfileError] = useState<string | null>(null)
  const [profileUser, setProfileUser] = useState<AdminAccountUser | null>(null)
  const [profileActivity, setProfileActivity] = useState<ProfileActivity[]>([])

  const [showAddModal, setShowAddModal] = useState(false)
  const [addSaving, setAddSaving] = useState(false)
  const [addApiError, setAddApiError] = useState<string | null>(null)

  const [editUser, setEditUser] = useState<AdminAccountUser | null>(null)
  const [editSaving, setEditSaving] = useState(false)
  const [editApiError, setEditApiError] = useState<string | null>(null)

  const [actionModal, setActionModal] = useState<AccountActionState | null>(null)
  const [memberDeactivate, setMemberDeactivate] = useState<AdminAccountUser | null>(null)
  const [memberDeactivateLoading, setMemberDeactivateLoading] = useState(false)
  const [memberDelete, setMemberDelete] = useState<AdminAccountUser | null>(null)
  const [memberDeleteLoading, setMemberDeleteLoading] = useState(false)

  const { showToast } = useToast()

  const filtered = useMemo(
    () => filterAccounts(allUsers, search, roleFilter, statusFilter),
    [allUsers, search, roleFilter, statusFilter],
  )

  const loadUsers = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const users = await fetchUsers()
      setAllUsers(users)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load users')
      setAllUsers([])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadUsers()
  }, [loadUsers])

  useEffect(() => {
    if (searchParams.get('view') === 'registrations') {
      setShowRegistrations(true)
      setRegistrationTab(parseRegistrationTab(searchParams.get('tab')))
    }
  }, [searchParams])

  const pendingRegistrationCount = useMemo(
    () => allUsers.filter((u) => String(u.status || '').toLowerCase() === 'pending').length,
    [allUsers],
  )

  function openRegistrations(tab: RegistrationApprovalTab = 'all') {
    setShowRegistrations(true)
    setRegistrationTab(tab)
    setSearchParams({ view: 'registrations', tab })
  }

  function closeRegistrations() {
    setShowRegistrations(false)
    setSearchParams({})
  }

  function handleRegistrationTabChange(tab: RegistrationApprovalTab) {
    setRegistrationTab(tab)
    setSearchParams({ view: 'registrations', tab })
  }

  const loadProfile = useCallback(async (userId: number) => {
    setProfileUserId(userId)
    setProfileLoading(true)
    setProfileError(null)
    setProfileUser(null)
    setProfileActivity([])
    setOpenMenuId(null)
    try {
      const data = await fetchUserProfile(userId)
      setProfileUser(parseAdminAccountUser(data as unknown as Record<string, unknown>))
      setProfileActivity(Array.isArray(data.recent_activity) ? data.recent_activity : [])
    } catch (e) {
      setProfileError(e instanceof Error ? e.message : 'Failed to load profile')
    } finally {
      setProfileLoading(false)
    }
  }, [])

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key !== 'Escape') return
      setOpenMenuId(null)
      if (profileUserId != null) {
        setProfileUserId(null)
        return
      }
      if (actionModal?.loading) return
      if (actionModal) {
        setActionModal(null)
        return
      }
      if (showAddModal && !addSaving) {
        setShowAddModal(false)
        setAddApiError(null)
        return
      }
      if (editUser && !editSaving) {
        setEditUser(null)
        setEditApiError(null)
      }
    }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [profileUserId, actionModal, showAddModal, addSaving, editUser, editSaving])

  async function handleAddSubmit(values: AccountFormValues) {
    setAddSaving(true)
    setAddApiError(null)
    const body = {
      name: values.name.trim(),
      email: values.email.trim(),
      role: values.role,
      skill_level: isRequestorRole(values.role) ? null : values.skillLevel,
      status: mapStatusToApi(values.accountStatus),
    }
    try {
      await createUser(body)
      setShowAddModal(false)
      setAddApiError(null)
      showToast('Account created successfully')
      await loadUsers()
    } catch (e) {
      const message = e instanceof Error ? e.message : 'Failed to create account'
      if (/email already/i.test(message)) {
        setAddApiError('This email is already registered.')
      } else {
        setAddApiError(message)
      }
    } finally {
      setAddSaving(false)
    }
  }

  async function handleEditSubmit(values: AccountFormValues) {
    if (!editUser) return
    setEditSaving(true)
    setEditApiError(null)
    const body = {
      name: values.name.trim(),
      email: values.email.trim(),
      role: values.role,
      skill_level: isRequestorRole(values.role) ? null : values.skillLevel,
      status: mapStatusToApi(values.accountStatus),
    }
    try {
      await updateUser(editUser.user_id, body)
      const savedName = values.name.trim()
      setEditUser(null)
      showToast(`Account updated for ${savedName}`)
      await loadUsers()
    } catch (e) {
      const message = e instanceof Error ? e.message : 'Failed to update account'
      if (/email already/i.test(message)) {
        setEditApiError('This email is already registered.')
      } else {
        setEditApiError(message)
      }
    } finally {
      setEditSaving(false)
    }
  }

  async function executeAction() {
    if (!actionModal || actionModal.loading) return
    const modal = actionModal
    const u = modal.user
    setActionModal({ ...modal, loading: true, error: null })

    try {
      if (modal.kind === 'confirm-deactivate') {
        await setUserStatus(u.user_id, 'rejected', 'Deactivated by administrator')
        setActionModal(null)
        showToast(`Account deactivated for ${u.name}`)
        await loadUsers()
        return
      }

      if (modal.kind === 'confirm-activate') {
        await setUserStatus(u.user_id, 'approved')
        setActionModal(null)
        showToast(`Account activated for ${u.name}`)
        await loadUsers()
        return
      }

      if (modal.kind === 'confirm-reset-password') {
        const result = await resetUserPassword(u.user_id)
        setActionModal({
          kind: 'reset-success',
          user: u,
          temporaryPassword: String(result.temporary_password || ''),
        })
        return
      }

      if (modal.kind === 'change-role') {
        const role = modal.role || u.role
        if (!ACCOUNT_ROLES.includes(role as (typeof ACCOUNT_ROLES)[number])) {
          setActionModal({ ...modal, loading: false, error: 'Select a valid role.' })
          return
        }
        await updateUserRole(u.user_id, role)
        setActionModal(null)
        showToast(`Role updated to ${accountRoleLabel(role)}`)
        await loadUsers()
      }
    } catch (e) {
      const message = e instanceof Error ? e.message : 'Action failed'
      setActionModal({ ...modal, loading: false, error: message })
    }
  }

  function handleToggleActive(user: AdminAccountUser) {
    setOpenMenuId(null)
    const sk = accountStatusKey(user)
    if (sk === 'active' && !canChangePrivilegedFields(user, allUsers)) {
      showToast('Cannot deactivate the last active administrator.', true)
      return
    }
    if (sk === 'active' && user.role === 'Member') {
      setMemberDeactivate(user)
      return
    }
    setActionModal({
      kind: sk === 'active' ? 'confirm-deactivate' : 'confirm-activate',
      user,
    })
  }

  function handleDeleteMember(user: AdminAccountUser) {
    setOpenMenuId(null)
    if (user.role !== 'Member' && user.role !== 'Organization') return
    setMemberDelete(user)
  }

  async function confirmMemberDelete(deleteUploads: boolean, confirmationEmail: string) {
    if (!memberDelete || memberDeleteLoading) return
    setMemberDeleteLoading(true)
    try {
      const result = await permanentlyDeleteMemberAccount(
        memberDelete.user_id,
        confirmationEmail,
        deleteUploads,
      )
      showToast(result.message || `Deleted ${memberDelete.name}`)
      setMemberDelete(null)
      if (profileUserId === memberDelete.user_id) setProfileUserId(null)
      await loadUsers()
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'Delete failed', true)
    } finally {
      setMemberDeleteLoading(false)
    }
  }

  async function confirmMemberDeactivate(deleteUploads: boolean) {
    if (!memberDeactivate || memberDeactivateLoading) return
    setMemberDeactivateLoading(true)
    try {
      const result = await setUserStatus(
        memberDeactivate.user_id,
        'rejected',
        'Deactivated by administrator',
        { deleteUploads },
      )
      showToast(result.message || `Account deactivated for ${memberDeactivate.name}`)
      setMemberDeactivate(null)
      await loadUsers()
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'Deactivation failed', true)
    } finally {
      setMemberDeactivateLoading(false)
    }
  }

  const hasFilters = Boolean(search || roleFilter !== 'all' || statusFilter !== 'all')

  return (
    <div className="account-mgmt" data-account-management>
      <div className="account-mgmt__page">
        <AdminPageHeader
          title="Account Management"
          subtitle="Manage users, roles, and account access."
          backTo="/"
          actions={
            <>
              <button
                type="button"
                className="account-mgmt__btn account-mgmt__btn--ghost"
                onClick={() => openRegistrations('all')}
              >
                <ClipboardCheck size={16} aria-hidden />
                Review registrations
                {pendingRegistrationCount > 0 && (
                  <span className="account-mgmt__badge">{pendingRegistrationCount}</span>
                )}
              </button>
              <button
                type="button"
                className="account-mgmt__btn account-mgmt__btn--primary"
                onClick={() => {
                  setShowAddModal(true)
                  setAddApiError(null)
                }}
              >
                <UserPlus size={16} aria-hidden />
                Add Account
              </button>
            </>
          }
        />

        {showRegistrations ? (
          <RegistrationApprovalsPanel
            initialTab={registrationTab}
            onBack={closeRegistrations}
            onTabChange={handleRegistrationTabChange}
          />
        ) : (
          <>
        <div className="account-mgmt__toolbar">
          <div className="account-mgmt__search-wrap">
            <Search size={16} className="account-mgmt__search-icon" aria-hidden />
            <input
              type="search"
              className="account-mgmt__search"
              placeholder="Search name or email…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              aria-label="Search users"
            />
          </div>
          <div className="account-mgmt__filters">
            <label className="account-mgmt__filter">
              <span className="account-mgmt__filter-label">Role</span>
              <select
                className="account-mgmt__select"
                value={roleFilter}
                onChange={(e) => setRoleFilter(e.target.value)}
              >
                <option value="all">All roles</option>
                {ACCOUNT_ROLES.map((r) => (
                  <option key={r} value={r}>
                    {accountRoleLabel(r)}
                  </option>
                ))}
              </select>
            </label>
            <label className="account-mgmt__filter">
              <span className="account-mgmt__filter-label">Status</span>
              <select
                className="account-mgmt__select"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
              >
                <option value="all">All</option>
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
                <option value="suspended">Suspended</option>
              </select>
            </label>
            <button
              type="button"
              className="account-mgmt__btn account-mgmt__btn--ghost"
              onClick={loadUsers}
              disabled={loading}
            >
              <RefreshCw size={16} className={loading ? 'account-mgmt__spin' : ''} aria-hidden />
              Refresh
            </button>
          </div>
        </div>

        {error ? (
          <div className="account-mgmt__alert account-mgmt__alert--error" role="alert">
            {error}
          </div>
        ) : null}

        {loading && allUsers.length === 0 ? (
          <div className="account-mgmt__state account-mgmt__state--loading">
            <Loader2 size={28} className="account-mgmt__spin account-mgmt__state-icon" aria-hidden />
            <p>Loading accounts…</p>
          </div>
        ) : filtered.length === 0 ? (
          <div className="account-mgmt__state account-mgmt__state--empty">
            <Users size={28} className="account-mgmt__state-icon" aria-hidden />
            <p className="account-mgmt__state-title">No users found</p>
            <p className="account-mgmt__state-desc">
              {hasFilters
                ? 'Try adjusting your search or filters.'
                : 'Add the first account to get started.'}
            </p>
            <button
              type="button"
              className="account-mgmt__btn account-mgmt__btn--primary"
              onClick={() => setShowAddModal(true)}
            >
              + Add Account
            </button>
          </div>
        ) : (
          <AccountsTableSection
            rows={filtered}
            allUsers={allUsers}
            openMenuId={openMenuId}
            onToggleMenu={(id) => setOpenMenuId((prev) => (prev === id ? null : id))}
            onViewProfile={(u) => loadProfile(u.user_id)}
            onEdit={(u) => {
              setOpenMenuId(null)
              setEditUser(u)
              setEditApiError(null)
            }}
            onChangeRole={(u) => {
              if (!canChangePrivilegedFields(u, allUsers)) return
              setOpenMenuId(null)
              setActionModal({ kind: 'change-role', user: u, role: u.role })
            }}
            onResetPassword={(u) => {
              setOpenMenuId(null)
              setActionModal({ kind: 'confirm-reset-password', user: u })
            }}
            onToggleActive={handleToggleActive}
            onDeleteMember={handleDeleteMember}
          />
        )}

        {filtered.length > 0 ? (
          <footer className="account-mgmt__pagination">
            <span className="account-mgmt__page-info">{accountSummaryText(filtered)}</span>
          </footer>
        ) : null}

        {openMenuId != null ? (
          <button
            type="button"
            className="account-mgmt__menu-backdrop"
            aria-label="Close menu"
            onClick={() => setOpenMenuId(null)}
          />
        ) : null}
          </>
        )}

        <AccountProfileModal
          userId={profileUserId}
          loading={profileLoading}
          error={profileError}
          user={profileUser}
          activity={profileActivity}
          onClose={() => setProfileUserId(null)}
          onRetry={() => profileUserId != null && loadProfile(profileUserId)}
          onEdit={() => {
            if (!profileUser) return
            setProfileUserId(null)
            setEditUser(profileUser)
            setEditApiError(null)
          }}
        />

        <AccountFormModal
          mode="add"
          open={showAddModal}
          user={null}
          allUsers={allUsers}
          initialValues={defaultAccountForm()}
          saving={addSaving}
          apiError={addApiError}
          onClose={() => {
            if (addSaving) return
            setShowAddModal(false)
            setAddApiError(null)
          }}
          onSubmit={handleAddSubmit}
        />

        <AccountFormModal
          mode="edit"
          open={editUser != null}
          user={editUser}
          allUsers={allUsers}
          initialValues={editUser ? formFromUser(editUser) : defaultAccountForm()}
          saving={editSaving}
          apiError={editApiError}
          onClose={() => {
            if (editSaving) return
            setEditUser(null)
            setEditApiError(null)
          }}
          onSubmit={handleEditSubmit}
        />

        <AccountActionModal
          action={actionModal}
          onClose={() => {
            if (actionModal?.loading) return
            setActionModal(null)
          }}
          onConfirm={executeAction}
          onRoleChange={(role) => {
            setActionModal((prev) => (prev ? { ...prev, role } : prev))
          }}
        />

        {memberDeactivate ? (
          <DeactivateMemberDialog
            open
            memberName={memberDeactivate.name}
            userId={memberDeactivate.user_id}
            loading={memberDeactivateLoading}
            onConfirm={(deleteUploads) => void confirmMemberDeactivate(deleteUploads)}
            onCancel={() => {
              if (memberDeactivateLoading) return
              setMemberDeactivate(null)
            }}
          />
        ) : null}

        {memberDelete ? (
          <DeleteMemberAccountDialog
            open
            memberName={memberDelete.name}
            memberEmail={memberDelete.email}
            userId={memberDelete.user_id}
            accountRole={memberDelete.role}
            loading={memberDeleteLoading}
            onConfirm={(deleteUploads, email) => void confirmMemberDelete(deleteUploads, email)}
            onCancel={() => {
              if (memberDeleteLoading) return
              setMemberDelete(null)
            }}
          />
        ) : null}
      </div>
    </div>
  )
}
