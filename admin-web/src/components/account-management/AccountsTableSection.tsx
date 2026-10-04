import {
  accountStatusKey,
  formatAccountDate,
  initialsFromName,
  partitionAccounts,
  type AdminAccountUser,
} from '../../lib/accountManagement'
import { StatusBadge } from './AccountBadges'
import { AccountActionsMenu } from './AccountActionsMenu'

interface Props {
  rows: AdminAccountUser[]
  allUsers: AdminAccountUser[]
  openMenuId: number | null
  onToggleMenu: (userId: number) => void
  onViewProfile: (user: AdminAccountUser) => void
  onEdit: (user: AdminAccountUser) => void
  onChangeRole: (user: AdminAccountUser) => void
  onResetPassword: (user: AdminAccountUser) => void
  onToggleActive: (user: AdminAccountUser) => void
}

function AccountsTable({
  rows,
  allUsers,
  openMenuId,
  onToggleMenu,
  onViewProfile,
  onEdit,
  onChangeRole,
  onResetPassword,
  onToggleActive,
}: Props) {
  return (
    <div className="account-mgmt__table-wrap">
      <table className="account-mgmt__table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Email</th>
            <th>Status</th>
            <th>Date Joined</th>
            <th className="account-mgmt__th-actions">Actions</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((u) => (
            <tr key={u.user_id} data-user-id={u.user_id}>
              <td>
                <div className="account-mgmt__name-cell">
                  <span className="account-mgmt__avatar" aria-hidden>
                    {initialsFromName(u.name) || '?'}
                  </span>
                  <span className="account-mgmt__name">{u.name}</span>
                </div>
              </td>
              <td className="account-mgmt__email">{u.email}</td>
              <td>
                <StatusBadge statusKey={accountStatusKey(u)} />
              </td>
              <td>{formatAccountDate(u.created_at)}</td>
              <td className="account-mgmt__actions-cell">
                <AccountActionsMenu
                  user={u}
                  allUsers={allUsers}
                  open={openMenuId === u.user_id}
                  onToggle={() => onToggleMenu(u.user_id)}
                  onViewProfile={() => onViewProfile(u)}
                  onEdit={() => onEdit(u)}
                  onChangeRole={() => onChangeRole(u)}
                  onResetPassword={() => onResetPassword(u)}
                  onToggleActive={() => onToggleActive(u)}
                />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export function AccountsTableSection(props: Props) {
  const { rows } = props
  const { members, requestors, administrators } = partitionAccounts(rows)
  const sections: { title: string; rows: AdminAccountUser[] }[] = []

  if (administrators.length) {
    sections.push({ title: 'Administrators', rows: administrators })
  }
  if (members.length) {
    sections.push({ title: 'Documentation Members', rows: members })
  }
  if (requestors.length) {
    sections.push({ title: 'Requestors', rows: requestors })
  }

  if (!sections.length) return null

  return (
    <div className="account-mgmt__groups">
      {sections.map((section) => (
        <section key={section.title} className="account-mgmt__card account-mgmt__section">
          <div className="account-mgmt__section-head">
            <h2 className="account-mgmt__section-title">{section.title}</h2>
            <span className="account-mgmt__section-count">{section.rows.length}</span>
          </div>
          <AccountsTable {...props} rows={section.rows} />
        </section>
      ))}
    </div>
  )
}
