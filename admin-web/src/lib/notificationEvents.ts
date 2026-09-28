/** Broadcast when notification read state changes so the top bar badge stays in sync. */
export const NOTIFICATIONS_CHANGED = 'access-notifications-changed'

export function emitNotificationsChanged() {
  window.dispatchEvent(new CustomEvent(NOTIFICATIONS_CHANGED))
}
