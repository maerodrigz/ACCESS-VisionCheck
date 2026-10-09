import { Navigate, Outlet } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

export function ProtectedRoute() {
  const { user, initializing } = useAuth()

  if (initializing) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[var(--color-content-bg)]">
        <div className="text-sm font-medium text-[var(--color-text-secondary)]">
          Restoring session…
        </div>
      </div>
    )
  }

  if (!user) return <Navigate to="/login" replace />
  return (
    <div className="flex h-full min-h-0 flex-1 flex-col">
      <Outlet />
    </div>
  )
}
