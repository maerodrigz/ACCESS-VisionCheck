import { lazy } from 'react'
import { Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { AdminLayout } from './components/AdminLayout'
import { ProtectedRoute } from './components/ProtectedRoute'
import { LoginPage } from './pages/LoginPage'

const DashboardPage = lazy(() =>
  import('./pages/DashboardPage').then((m) => ({ default: m.DashboardPage })),
)
const DocumentationRequestsPage = lazy(() =>
  import('./pages/DocumentationRequestsPage').then((m) => ({ default: m.DocumentationRequestsPage })),
)
const EventCalendarPage = lazy(() =>
  import('./pages/EventCalendarPage').then((m) => ({ default: m.EventCalendarPage })),
)
const DocumentationTeamPage = lazy(() =>
  import('./pages/DocumentationTeamPage').then((m) => ({ default: m.DocumentationTeamPage })),
)
const MediaLibraryPage = lazy(() =>
  import('./pages/MediaLibraryPage').then((m) => ({ default: m.MediaLibraryPage })),
)
const MediaIntegrityPage = lazy(() =>
  import('./pages/MediaIntegrityPage').then((m) => ({ default: m.MediaIntegrityPage })),
)
const RequesterFeedbackPage = lazy(() =>
  import('./pages/RequesterFeedbackPage').then((m) => ({ default: m.RequesterFeedbackPage })),
)
const CompetencyManagementPage = lazy(() =>
  import('./pages/CompetencyManagementPage').then((m) => ({ default: m.CompetencyManagementPage })),
)
const AnalyticsPage = lazy(() =>
  import('./pages/AnalyticsPage').then((m) => ({ default: m.AnalyticsPage })),
)
const NotificationCenterPage = lazy(() =>
  import('./pages/NotificationCenterPage').then((m) => ({ default: m.NotificationCenterPage })),
)
const AccountManagementPage = lazy(() =>
  import('./pages/AccountManagementPage').then((m) => ({ default: m.AccountManagementPage })),
)
const SystemConfigurationPage = lazy(() =>
  import('./pages/SystemConfigurationPage').then((m) => ({ default: m.SystemConfigurationPage })),
)
const MemberMediaGalleryPage = lazy(() =>
  import('./pages/MemberMediaGalleryPage').then((m) => ({ default: m.MemberMediaGalleryPage })),
)
const NotFoundPage = lazy(() =>
  import('./pages/NotFoundPage').then((m) => ({ default: m.NotFoundPage })),
)

/** Old bookmarks to /evaluations?media=… land on Member Uploads. */
function EvaluationsRedirect() {
  const { search } = useLocation()
  const params = new URLSearchParams(search)
  const media = params.get('media')
  if (media) return <Navigate to={`/media/member-uploads?media=${media}`} replace />
  return <Navigate to="/media/member-uploads" replace />
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<ProtectedRoute />}>
        <Route element={<AdminLayout />}>
          <Route index element={<DashboardPage />} />
          <Route path="documentation-requests" element={<DocumentationRequestsPage />} />
          <Route path="event-calendar" element={<EventCalendarPage />} />
          <Route path="members" element={<DocumentationTeamPage />} />
          <Route path="media" element={<MediaLibraryPage />} />
          <Route path="media/member-uploads" element={<MemberMediaGalleryPage />} />
          <Route path="media-integrity" element={<MediaIntegrityPage />} />
          <Route path="feedback" element={<RequesterFeedbackPage />} />
          <Route path="evaluations" element={<EvaluationsRedirect />} />
          <Route path="competency" element={<CompetencyManagementPage />} />
          <Route path="analytics" element={<AnalyticsPage />} />
          <Route path="notifications" element={<NotificationCenterPage />} />
          <Route path="account-management" element={<AccountManagementPage />} />
          <Route path="system-configuration" element={<SystemConfigurationPage />} />
          <Route path="*" element={<NotFoundPage />} />
        </Route>
      </Route>
    </Routes>
  )
}
