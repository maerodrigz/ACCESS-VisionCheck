import { AlertCircle, Loader2, UserCog, X } from 'lucide-react'
import { mediaUrl } from '../../api/media'
import {
  accountStatusKey,
  formatAccountDate,
  formatAccountDateTime,
  initialsFromName,
  isRequestorRole,
  type AdminAccountUser,
  type ProfileActivity,
} from '../../lib/accountManagement'
import { RoleBadge, StatusBadge } from './AccountBadges'
import { ActivityIcon } from './AccountActionsMenu'

interface Props {
  userId: number | null
  loading: boolean
  error: string | null
  user: AdminAccountUser | null
  activity: ProfileActivity[]
  onClose: () => void
  onRetry: () => void
  onEdit: () => void
}

export function AccountProfileModal({
  userId,
  loading,
  error,
  user,
  activity,
  onClose,
  onRetry,
  onEdit,
}: Props) {
  if (userId == null) return null

  return (
    <div className="account-mgmt__modal-backdrop" onClick={onClose}>
      <div
        className="account-mgmt__modal account-mgmt__modal--profile"
        role="dialog"
        aria-labelledby="profile-title"
        aria-modal="true"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="account-mgmt__modal-header">
          <h2 id="profile-title">User Profile</h2>
          <button type="button" className="account-mgmt__modal-close" onClick={onClose} aria-label="Close">
            <X size={18} aria-hidden />
          </button>
        </div>

        <div className="account-mgmt__modal-body account-mgmt__profile-body">
          {loading ? (
            <div className="account-mgmt__profile-loading">
              <Loader2 size={28} className="account-mgmt__spin account-mgmt__state-icon" aria-hidden />
              <p>Loading profile…</p>
            </div>
          ) : error ? (
            <div className="account-mgmt__profile-error">
              <AlertCircle size={28} className="account-mgmt__state-icon" aria-hidden />
              <p className="account-mgmt__state-title">Could not load profile</p>
              <p className="account-mgmt__state-desc">{error}</p>
              <button type="button" className="account-mgmt__btn account-mgmt__btn--ghost" onClick={onRetry}>
                Try again
              </button>
            </div>
          ) : user ? (
            <ProfileContent user={user} activity={activity} />
          ) : null}
        </div>

        <div className="account-mgmt__modal-footer">
          <button type="button" className="account-mgmt__btn account-mgmt__btn--ghost" onClick={onClose}>
            Close
          </button>
          {user && !loading ? (
            <button type="button" className="account-mgmt__btn account-mgmt__btn--primary" onClick={onEdit}>
              <UserCog size={16} aria-hidden />
              Edit Account
            </button>
          ) : null}
        </div>
      </div>
    </div>
  )
}

function ProfileContent({
  user,
  activity,
}: {
  user: AdminAccountUser
  activity: ProfileActivity[]
}) {
  const avatarUrl = mediaUrl(user.profile_image)
  const initials = initialsFromName(user.name)

  return (
    <div className="account-mgmt__profile-card">
      <div className="account-mgmt__profile-hero">
        {avatarUrl ? (
          <img
            src={avatarUrl}
            alt=""
            className="account-mgmt__profile-avatar account-mgmt__profile-avatar--img"
          />
        ) : (
          <div className="account-mgmt__profile-avatar" aria-hidden>
            {initials || '?'}
          </div>
        )}
        <div className="account-mgmt__profile-hero-text">
          <h3 className="account-mgmt__profile-name">{user.name}</h3>
          <p className="account-mgmt__profile-email">{user.email}</p>
          <div className="account-mgmt__profile-badges">
            <RoleBadge role={user.role} />
            <StatusBadge statusKey={accountStatusKey(user)} />
          </div>
        </div>
      </div>

      <div className="account-mgmt__profile-grid">
        {!isRequestorRole(user.role) ? (
          <div className="account-mgmt__profile-stat">
            <span className="account-mgmt__profile-stat-label">Skill Level</span>
            <span className="account-mgmt__profile-stat-value">{user.skill_level || 'N/A'}</span>
          </div>
        ) : null}
        <div className="account-mgmt__profile-stat">
          <span className="account-mgmt__profile-stat-label">Date Joined</span>
          <span className="account-mgmt__profile-stat-value">{formatAccountDate(user.created_at)}</span>
        </div>
        <div className="account-mgmt__profile-stat">
          <span className="account-mgmt__profile-stat-label">Last Active</span>
          <span className="account-mgmt__profile-stat-value">{formatAccountDateTime(user.last_active)}</span>
        </div>
        <div className="account-mgmt__profile-stat">
          <span className="account-mgmt__profile-stat-label">Tasks Completed</span>
          <span className="account-mgmt__profile-stat-value">
            {user.completed_tasks ?? 0} / {user.assigned_tasks ?? 0}
          </span>
        </div>
      </div>

      {user.primary_task_role ? (
        <p className="account-mgmt__profile-meta">
          <strong>Primary role:</strong> {user.primary_task_role}
        </p>
      ) : null}
      {user.student_id ? (
        <p className="account-mgmt__profile-meta">
          <strong>Student ID:</strong> {user.student_id}
        </p>
      ) : null}
      {user.contact_number ? (
        <p className="account-mgmt__profile-meta">
          <strong>Contact:</strong> {user.contact_number}
        </p>
      ) : null}

      <div className="account-mgmt__profile-activity">
        <h4 className="account-mgmt__profile-activity-title">Recent activity</h4>
        {activity.length === 0 ? (
          <p className="account-mgmt__profile-activity-empty">
            No recent login or audit activity recorded.
          </p>
        ) : (
          <ul className="account-mgmt__activity-list">
            {activity.map((item, i) => (
              <li key={`${item.kind}-${item.occurred_at ?? i}`} className="account-mgmt__activity-item">
                <ActivityIcon kind={item.kind} />
                <div className="account-mgmt__activity-text">
                  <div className="account-mgmt__activity-label">{item.label}</div>
                  {item.detail ? (
                    <div className="account-mgmt__activity-detail">{item.detail}</div>
                  ) : null}
                  <div className="account-mgmt__activity-time">{formatAccountDateTime(item.occurred_at)}</div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}
