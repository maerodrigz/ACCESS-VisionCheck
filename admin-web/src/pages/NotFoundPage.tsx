import { Link } from 'react-router-dom'
import { Home, SearchX } from 'lucide-react'

export function NotFoundPage() {
  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center px-4 text-center">
      <span className="flex h-16 w-16 items-center justify-center rounded-2xl bg-[var(--color-accent-blue)]/15 text-[var(--color-accent-blue)]">
        <SearchX size={32} />
      </span>
      <h1 className="mt-4 text-2xl font-extrabold text-[var(--color-text-primary)]">Page not found</h1>
      <p className="mt-2 max-w-md text-sm text-[var(--color-text-secondary)]">
        That admin route does not exist. Check the sidebar or return to the dashboard.
      </p>
      <Link
        to="/"
        className="mt-6 inline-flex items-center gap-2 rounded-xl bg-[var(--color-accent-blue)] px-4 py-2.5 text-sm font-bold text-white hover:opacity-95"
      >
        <Home size={16} />
        Back to Dashboard
      </Link>
    </div>
  )
}
