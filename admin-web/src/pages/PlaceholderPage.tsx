import { Link } from 'react-router-dom'
import { Construction } from 'lucide-react'
import { AdminCard } from '../components/AdminCard'
import { allNavItems } from '../config/navigation'

interface PlaceholderPageProps {
  title?: string
}

export function PlaceholderPage({ title }: PlaceholderPageProps) {
  const match = allNavItems.find((i) => i.label === title)

  return (
    <AdminCard className="mx-auto max-w-lg text-center" padding="lg">
      <div className="mx-auto mb-4 inline-flex rounded-2xl bg-slate-100 p-4 text-[var(--color-accent-blue)]">
        <Construction size={32} />
      </div>
      <h1 className="text-xl font-extrabold text-[var(--color-text-primary)]">
        {title ?? 'Coming soon'}
      </h1>
      <p className="mt-2 text-sm text-[var(--color-text-secondary)]">
        This module is being migrated from the Flutter admin to the new HTML/CSS web stack.
        The dashboard is live; other sections will follow.
      </p>
      {match && (
        <p className="mt-4 text-xs text-[var(--color-text-secondary)]">
          Route: <code className="rounded bg-slate-100 px-1">{match.path}</code>
        </p>
      )}
      <Link
        to="/"
        className="mt-6 inline-block rounded-xl bg-[var(--color-accent-blue)] px-5 py-2.5 text-sm font-bold text-white hover:opacity-90"
      >
        Back to Dashboard
      </Link>
    </AdminCard>
  )
}
