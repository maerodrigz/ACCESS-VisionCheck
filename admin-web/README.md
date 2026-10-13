# ACCESS VisionCheck — Web Admin (React)

Standard web admin portal built with **HTML, CSS, JavaScript/TypeScript, React, and Tailwind CSS**.

Connects to the existing FastAPI backend (`access_backend`).

## Quick start

```powershell
# Terminal 1 — API
cd access_backend
python manage.py runserver

# Terminal 2 — Admin web
cd admin-web
npm install
npm run dev
```

Open http://localhost:5173 and sign in with an **Admin** account.

## Configuration

Copy `.env.example` to `.env` and adjust if needed:

```env
VITE_API_BASE_URL=/api
```

By default Vite proxies `/api` → `http://127.0.0.1:3001` (see `vite.config.ts`).

For LAN testing without the proxy:

```env
VITE_API_BASE_URL=http://10.96.22.169:3001/api
```

## Stack

| Layer | Technology |
|-------|------------|
| UI | React 19 + TypeScript |
| Styling | Tailwind CSS v4 + design tokens from Flutter `AdminTheme` |
| Cards | `AdminCard` — all surfaces include the cyan top accent by default |
| Routing | React Router |
| Icons | Lucide React |
| API | Fetch → FastAPI `/api/*` |

## Migration status

- [x] Login + auth (JWT)
- [x] Admin shell (sidebar + top bar)
- [x] Dashboard + `/admin/stats`
- [x] **Media Integrity / AI Detection** — list, filters, review modal, archive
- [x] **Documentation Requests** — list, filters, approve/reject/assign panel
- [x] Documentation Team (`/members`) — team grid, filters, profile drawer, registration approvals
- [x] Requester Feedback (`/feedback`) — reviews, respond, archive, export
- [x] Analytics (`/analytics`) — overview, participation, rankings, feedback & media tabs
- [x] Competency Management (`/competency`) — levels, assessment, notes, export

Web admin is React only (`admin-web/`). Flutter is for the mobile app (`lib/mobile_app/`).

## Production build

```powershell
npm run build
npm run preview
```

Serve the `dist/` folder behind nginx or similar; point `VITE_API_BASE_URL` at your production API.
