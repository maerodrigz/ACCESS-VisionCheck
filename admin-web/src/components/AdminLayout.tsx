import { Suspense, useEffect, useState } from 'react'

import { Outlet } from 'react-router-dom'

import { checkBackendHealth } from '../api/client'

import { useAuth } from '../context/AuthContext'
import { runAdminLegacyMigration } from '../lib/adminLegacyMigration'
import { ToastProvider } from '../context/ToastContext'

import { PageLoader } from './PageLoader'
import { Sidebar, SidebarBrand, SidebarNav } from './Sidebar'
import { TopBar } from './TopBar'

export function AdminLayout() {
  const { user } = useAuth()

  const [offline, setOffline] = useState(false)
  const [sidebarOpen, setSidebarOpen] = useState(false)

  useEffect(() => {
    if (user?.role === 'Admin') {
      void runAdminLegacyMigration()
    }
  }, [user?.role])

  useEffect(() => {
    let cancelled = false

    const ping = async () => {
      const ok = await checkBackendHealth()

      if (!cancelled) setOffline(!ok)
    }

    ping()

    const id = setInterval(ping, 30000)

    return () => {
      cancelled = true

      clearInterval(id)
    }
  }, [])

  useEffect(() => {
    if (!sidebarOpen) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setSidebarOpen(false)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [sidebarOpen])

  if (!user) return null

  return (
    <ToastProvider>
      <div className="flex h-full min-h-0 w-full flex-col overflow-hidden bg-[var(--color-content-bg)]">
        {offline && (
          <div className="shrink-0 bg-amber-600 px-4 py-2 text-center text-sm font-semibold text-white">
            Backend offline — start the API with{' '}
            <code className="rounded bg-black/20 px-1">python manage.py runserver</code> in access_backend
          </div>
        )}

        {/* Desktop shell */}
        <div
          className="hidden min-h-0 flex-1 overflow-hidden lg:grid"
          style={{
            gridTemplateColumns: 'var(--sidebar-width) minmax(0, 1fr)',
            gridTemplateRows: 'var(--topbar-height) minmax(0, 1fr)',
          }}
        >
          <div className="admin-sidebar border-b border-[var(--color-sidebar-border)]">
            <SidebarBrand />
          </div>

          <div className="border-b border-[var(--color-border)] bg-[var(--color-surface)]">
            <TopBar />
          </div>

          <div className="admin-sidebar flex min-h-0 flex-col overflow-hidden">
            <SidebarNav />
          </div>

          <main className="min-h-0 min-w-0 flex-1 overflow-x-hidden overflow-y-auto overscroll-y-contain px-3 py-4 md:px-4 md:py-5">
            <Suspense fallback={<PageLoader />}>
              <Outlet />
            </Suspense>
          </main>
        </div>

        {/* Mobile shell */}
        <div className="flex min-h-0 flex-1 flex-col overflow-hidden lg:hidden">
          <TopBar onMenuClick={() => setSidebarOpen(true)} mobile />
          <main className="min-h-0 min-w-0 flex-1 overflow-x-hidden overflow-y-auto p-4">
            <Suspense fallback={<PageLoader />}>
              <Outlet />
            </Suspense>
          </main>
        </div>

        {sidebarOpen ? (
          <>
            <button
              type="button"
              aria-label="Close navigation"
              className="fixed inset-0 z-40 bg-black/50 lg:hidden"
              onClick={() => setSidebarOpen(false)}
            />
            <div className="fixed inset-y-0 left-0 z-50 lg:hidden">
              <Sidebar onNavigate={() => setSidebarOpen(false)} />
            </div>
          </>
        ) : null}
      </div>
    </ToastProvider>
  )
}
