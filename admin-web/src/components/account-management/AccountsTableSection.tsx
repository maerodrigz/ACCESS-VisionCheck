import {
  accountStatusKey,
  formatAccountDate,
  partitionAccounts,
  type AdminAccountUser,
} from '../../lib/accountManagement'
import { AccountUserAvatar, StatusBadge } from './AccountBadges'
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
  onDeleteMember: (user: AdminAccountUser) => void
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
  onDeleteMember,
}: Props) {
  return (
    <div className="account-mgmt__table-wrap">
      <table className="account-mgmt__table">
        <colgroup>
          <col className="account-mgmt__col-name" />
          <col className="account-mgmt__col-email" />
          <col className="account-mgmt__col-status" />
          <col className="account-mgmt__col-date" />
          <col className="account-mgmt__col-actions" />
        </colgroup>
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
                  <AccountUserAvatar user={u} />
                  <span className="account-mgmt__name">{u.name}</span>
                </div>
              </td>
              <td className="account-mgmt__email">{u.email}</td>
              <td className="account-mgmt__status-cell">
                <StatusBadge statusKey={accountStatusKey(u)} />
              </td>
              <td className="account-mgmt__date-cell">{formatAccountDate(u.created_at)}</td>
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
                  onDeleteMember={() => onDeleteMember(u)}
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
    sections.push({ title: 'Administrator', rows: administrators })
  }
  if (members.length) {
    sections.push({ title: 'ACCESS Members', rows: members })
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
            <h2 className="account-mgmt__section-title">
              {section.title}
              <span className="account-mgmt__section-count" aria-label={`${section.rows.length} users`}>
                ({section.rows.length})
              </span>
            </h2>
          </div>
          <AccountsTable {...props} rows={section.rows} />
        </section>
      ))}
    </div>
  )
}
