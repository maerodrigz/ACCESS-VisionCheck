import { useCallback, useEffect, useMemo, useState } from 'react'

import { Loader2, Search } from 'lucide-react'

import { useSearchParams, useNavigate } from 'react-router-dom'

import { fetchServiceRequests, fetchTasks } from '../api/admin'

import { DocumentationRequestsTable } from '../components/documentation-requests/DocumentationRequestsTable'

import { RequestReviewPanel } from '../components/documentation-requests/RequestReviewPanel'

import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { PageToolbarRefreshButton } from '../components/PageToolbar'

import { useToast } from '../context/ToastContext'

import { AdminSelect } from '../components/AdminSelect'

import {

  filterAndSortRequests,

  parseDocumentationRequest,

  type DocumentationRequestItem,

  type RequestFilterTab,

  type RequestPriority,

  type RequestSortOption,

} from '../lib/documentationRequests'



const FILTER_TABS: { id: RequestFilterTab; label: string }[] = [

  { id: 'all', label: 'All' },

  { id: 'pending', label: 'Pending' },

  { id: 'approved', label: 'Approved' },

  { id: 'rejected', label: 'Rejected' },

  { id: 'completed', label: 'Completed' },

]



const SORT_OPTIONS: { id: RequestSortOption; label: string }[] = [

  { id: 'newest', label: 'Newest first' },

  { id: 'oldest', label: 'Oldest first' },

  { id: 'eventDateAsc', label: 'Event date (soonest)' },

  { id: 'eventDateDesc', label: 'Event date (latest)' },

  { id: 'priority', label: 'Priority' },

]



export function DocumentationRequestsPage() {

  const navigate = useNavigate()

  const [searchParams, setSearchParams] = useSearchParams()

  const [all, setAll] = useState<DocumentationRequestItem[]>([])

  const [loading, setLoading] = useState(true)

  const [error, setError] = useState<string | null>(null)

  const [search, setSearch] = useState('')

  const [filterTab, setFilterTab] = useState<RequestFilterTab>('all')

  const [sort, setSort] = useState<RequestSortOption>('newest')

  const [priorityFilter, setPriorityFilter] = useState<RequestPriority | ''>('')

  const [reviewItem, setReviewItem] = useState<DocumentationRequestItem | null>(null)

  const [assignmentToRequest, setAssignmentToRequest] = useState<Map<number, number>>(new Map())

  const { showToast } = useToast()



  const load = useCallback(async () => {

    setLoading(true)

    setError(null)

    try {

      const [requests, tasks] = await Promise.all([fetchServiceRequests(), fetchTasks()])

      const tasksByRequest = new Map<number, Record<string, unknown>[]>()

      const assignmentIndex = new Map<number, number>()

      for (const t of tasks) {

        const rid = Number(t.request_id)

        const aid = Number(t.id)

        if (aid && rid) assignmentIndex.set(aid, rid)

        if (!rid) continue

        if (!tasksByRequest.has(rid)) tasksByRequest.set(rid, [])

        tasksByRequest.get(rid)!.push(t)

      }

      setAssignmentToRequest(assignmentIndex)

      const items = requests.map((r) => {

        const id = Number(r.request_id ?? r.id ?? 0)

        return parseDocumentationRequest(r, tasksByRequest.get(id) ?? [])

      })

      setAll(items)

      setReviewItem((prev) => {

        if (!prev) return null

        return items.find((i) => i.id === prev.id) ?? prev

      })

    } catch (e) {

      setError(e instanceof Error ? e.message : 'Failed to load requests')

      setAll([])

    } finally {

      setLoading(false)

    }

  }, [])



  useEffect(() => {

    load()

  }, [load])



  useEffect(() => {
    const q = searchParams.get('q')
    if (q) setSearch(q)
  }, [searchParams])

  useEffect(() => {

    const requestId = Number(searchParams.get('request') || 0)

    const assignmentId = Number(searchParams.get('assignment') || 0)

    if (all.length === 0) return



    let targetId = requestId

    if (!targetId && assignmentId) {

      targetId = assignmentToRequest.get(assignmentId) ?? 0

      if (!targetId) {

        const next = new URLSearchParams(searchParams)

        next.delete('assignment')

        setSearchParams(next, { replace: true })

        showToast('Could not find that assignment. Check Documentation Requests or Team.', 'info')

        return

      }

    }

    if (!targetId) return



    const item = all.find((i) => i.id === targetId)

    if (!item) return

    setReviewItem(item)

    const next = new URLSearchParams(searchParams)

    next.delete('request')

    next.delete('assignment')

    setSearchParams(next, { replace: true })

  }, [all, assignmentToRequest, navigate, searchParams, setSearchParams])



  const visible = useMemo(

    () =>

      filterAndSortRequests(all, {

        tab: filterTab,

        search,

        sort,

        priorityFilter: priorityFilter || null,

      }),

    [all, filterTab, search, sort, priorityFilter],

  )



  function tabCount(tab: RequestFilterTab): number {

    if (tab === 'all') return all.length

    return all.filter((i) => i.displayStatus === tab).length

  }



  return (

    <div className="mx-auto max-w-[1400px] space-y-3">
      <AdminPageHeader
        title="Documentation Requests"
        subtitle="Review, approve, and assign members to organization documentation requests."
        backTo="/"
        actions={<PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />}
      />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      <div className="flex flex-wrap gap-1.5">

        {FILTER_TABS.map((tab) => (

          <button

            key={tab.id}

            type="button"

            onClick={() => setFilterTab(tab.id)}

            className={[

              'rounded-full px-3 py-1 text-xs font-bold transition',

              filterTab === tab.id

                ? 'bg-[var(--color-accent-blue)] text-white'

                : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',

            ].join(' ')}

          >

            {tab.label} ({tabCount(tab.id)})

          </button>

        ))}

      </div>



      <div className="flex flex-col gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-2 shadow-[0_1px_2px_rgba(15,39,68,0.04)]">

        <div className="grid items-center gap-2 md:grid-cols-2 xl:grid-cols-[minmax(0,1fr)_auto_auto]">

          <div className="relative min-w-0">

            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />

            <input

              value={search}

              onChange={(e) => setSearch(e.target.value)}

              placeholder="Search event, requestor, venue, REQ-…"

              className="admin-input w-full rounded-lg py-1.5 pl-9 pr-3 text-sm"

            />

          </div>

          <AdminSelect
            className="xl:w-52"
            buttonClassName="rounded-lg py-1.5"
            value={sort}
            onChange={(v) => setSort(v as RequestSortOption)}
            aria-label="Sort requests"
            options={SORT_OPTIONS.map((o) => ({ value: o.id, label: `Sort: ${o.label}` }))}
          />

          <AdminSelect
            className="xl:w-44"
            buttonClassName="rounded-lg py-1.5"
            value={priorityFilter}
            onChange={(v) => setPriorityFilter(v as RequestPriority | '')}
            aria-label="Filter by priority"
            options={[
              { value: '', label: 'All priorities' },
              { value: 'urgent', label: 'Urgent' },
              { value: 'high', label: 'High' },
              { value: 'normal', label: 'Normal' },
              { value: 'low', label: 'Low' },
            ]}
          />

        </div>

        <p className="px-1 text-[11px] text-[var(--color-text-secondary)]">

          {visible.length} request{visible.length === 1 ? '' : 's'} shown

          {loading ? ' · Updating…' : ''}

        </p>

      </div>



      {loading && all.length === 0 ? (

        <div className="flex justify-center py-16">

          <Loader2 className="animate-spin text-[var(--color-text-muted)]" size={28} />

        </div>

      ) : (

        <DocumentationRequestsTable items={visible} onReview={setReviewItem} />

      )}



      {reviewItem && (

        <RequestReviewPanel item={reviewItem} onClose={() => setReviewItem(null)} onUpdated={load} />

      )}

    </div>

  )

}


