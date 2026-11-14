"""Phase 6B online human rating portal API + static UI.

Independent of MUSIQ worker / production FastAPI quality scoring.
"""

from __future__ import annotations

import csv
import hashlib
import html
import io
import secrets
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

import sqlite3

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from app import __version__
from app import db as store
from app.config import Settings, get_settings
from app.criteria import CRITERIA, IMAGE_IDS, NA_LABEL, SCALE_LABELS

STATIC_DIR = Path(__file__).resolve().parents[1] / "static"


def _sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _parse_invites(raw: str) -> dict[str, str]:
    """Parse R1:token,R2:token,R3:token into {evaluator_id: plaintext_token}."""
    out: dict[str, str] = {}
    for part in (raw or "").split(","):
        part = part.strip()
        if not part:
            continue
        if ":" not in part:
            raise ValueError(f"bad invite segment: {part!r}")
        eid, tok = part.split(":", 1)
        eid = eid.strip().upper()
        tok = tok.strip()
        if eid not in ("R1", "R2", "R3") or not tok:
            raise ValueError(f"invalid invite for {eid}")
        out[eid] = tok
    return out


def _bootstrap_evaluators(conn: Any, settings: Settings) -> None:
    invites = _parse_invites(settings.evaluator_invites)
    if not invites:
        if settings.allow_bootstrap_without_secrets:
            # Dev-only convenience; never enable in production.
            generated = {
                "R1": secrets.token_urlsafe(24),
                "R2": secrets.token_urlsafe(24),
                "R3": secrets.token_urlsafe(24),
            }
            settings.evaluator_invites = ",".join(
                f"{k}:{v}" for k, v in generated.items()
            )
            invites = generated
            print(
                "WARNING: generated ephemeral evaluator invites "
                "(ALLOW_BOOTSTRAP_WITHOUT_SECRETS=true). Check /api/health bootstrap note."
            )
        else:
            raise RuntimeError(
                "EVALUATOR_INVITES is required (format R1:token,R2:token,R3:token)"
            )
    for eid, token in invites.items():
        store.upsert_evaluator(
            conn,
            evaluator_id=eid,
            invite_token_hash=_sha256(token),
            display_label=eid,
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    conn = store.connect(settings.database_path)
    store.init_db(conn)
    _bootstrap_evaluators(conn, settings)
    app.state.db = conn
    app.state.settings = settings
    yield
    conn.close()


app = FastAPI(
    title="ACCESS Phase 6B Rating Portal",
    version=__version__,
    lifespan=lifespan,
)

settings_early = get_settings()
origins = [o.strip() for o in settings_early.cors_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins if origins != ["*"] else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class InviteExchange(BaseModel):
    invite_token: str = Field(min_length=8)


class SaveRatings(BaseModel):
    media_id: str
    ratings: dict[str, Any] = Field(default_factory=dict)
    notes: str = ""
    mark_complete: bool = False


def get_conn() -> sqlite3.Connection:
    return app.state.db


def get_cfg() -> Settings:
    return app.state.settings


def require_evaluator_session(
    authorization: str | None = Header(default=None),
    x_session_token: str | None = Header(default=None, alias="X-Session-Token"),
    conn: sqlite3.Connection = Depends(get_conn),
) -> sqlite3.Row:
    token = None
    if x_session_token:
        token = x_session_token.strip()
    elif authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:].strip()
    if not token:
        raise HTTPException(status_code=401, detail="missing_session")
    row = store.touch_session(conn, _sha256(token))
    if row is None:
        raise HTTPException(status_code=401, detail="invalid_session")
    return row


def require_facilitator(
    authorization: str | None = Header(default=None),
    x_facilitator_token: str | None = Header(default=None, alias="X-Facilitator-Token"),
    settings: Settings = Depends(get_cfg),
) -> None:
    token = None
    if x_facilitator_token:
        token = x_facilitator_token.strip()
    elif authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:].strip()
    expected = (settings.facilitator_token or "").strip()
    if not expected:
        raise HTTPException(status_code=503, detail="facilitator_token_not_configured")
    if not token or not secrets.compare_digest(token, expected):
        raise HTTPException(status_code=403, detail="facilitator_forbidden")


@app.get("/api/health")
def health(settings: Settings = Depends(get_cfg)) -> dict[str, Any]:
    images = Path(settings.images_dir)
    n_img = len(list(images.glob("INDVAL-*.jpg"))) if images.is_dir() else 0
    return {
        "status": "ok",
        "service": "phase6b-rating-portal",
        "version": __version__,
        "n_images_on_disk": n_img,
        "musiq_worker_required": False,
        "production_quality_engine_untouched": True,
    }


@app.get("/api/meta")
def meta() -> dict[str, Any]:
    return {
        "criteria": CRITERIA,
        "scale_labels": SCALE_LABELS,
        "na_label": NA_LABEL,
        "n_images": len(IMAGE_IDS),
        "image_ids": list(IMAGE_IDS),
        "notes": [
            "Higher always means better quality, including blur/noise/blocking/ringing.",
            "Score 2: obvious defect; a retake would normally be required (locked rubric).",
            "Score 3: subject identifiable but defect clearly visible; below a strong submission.",
            "Overall is independent of the mean of the seven technical scores.",
            "N/A is allowed when a criterion cannot be judged. Never use 3 for unknown.",
            "Machine scores and source identities are not available in this portal.",
        ],
    }


@app.post("/api/auth/exchange")
def exchange_invite(
    body: InviteExchange,
    conn: sqlite3.Connection = Depends(get_conn),
) -> dict[str, Any]:
    row = store.find_evaluator_by_invite_hash(conn, _sha256(body.invite_token.strip()))
    if row is None:
        raise HTTPException(status_code=401, detail="invalid_invite")
    session = secrets.token_urlsafe(32)
    store.create_session(conn, session_token_hash=_sha256(session), evaluator_id=row["evaluator_id"])
    progress = store.list_progress(conn, row["evaluator_id"])
    return {
        "session_token": session,
        "evaluator_id": row["evaluator_id"],
        "display_label": row["display_label"],
        "final_submitted": progress["final_submitted"],
        "progress": {
            "n_complete": progress["n_complete"],
            "n_images": progress["n_images"],
        },
    }


@app.get("/api/me")
def me(
    session: sqlite3.Row = Depends(require_evaluator_session),
    conn: sqlite3.Connection = Depends(get_conn),
) -> dict[str, Any]:
    progress = store.list_progress(conn, session["evaluator_id"])
    return {
        "evaluator_id": session["evaluator_id"],
        "display_label": session["display_label"],
        "progress": progress,
    }


@app.get("/api/progress")
def progress(
    session: sqlite3.Row = Depends(require_evaluator_session),
    conn: sqlite3.Connection = Depends(get_conn),
) -> dict[str, Any]:
    return store.list_progress(conn, session["evaluator_id"])


@app.get("/api/ratings/{media_id}")
def get_ratings(
    media_id: str,
    session: sqlite3.Row = Depends(require_evaluator_session),
    conn: sqlite3.Connection = Depends(get_conn),
) -> dict[str, Any]:
    if media_id not in IMAGE_IDS:
        raise HTTPException(status_code=404, detail="unknown_media")
    return store.get_image_rating(conn, session["evaluator_id"], media_id)


@app.put("/api/ratings/{media_id}")
def put_ratings(
    media_id: str,
    body: SaveRatings,
    session: sqlite3.Row = Depends(require_evaluator_session),
    conn: sqlite3.Connection = Depends(get_conn),
) -> dict[str, Any]:
    if media_id != body.media_id:
        raise HTTPException(status_code=400, detail="media_id_mismatch")
    if media_id not in IMAGE_IDS:
        raise HTTPException(status_code=404, detail="unknown_media")
    try:
        saved = store.save_image_ratings(
            conn,
            evaluator_id=session["evaluator_id"],
            media_id=media_id,
            ratings=body.ratings,
            notes=body.notes,
            mark_complete=body.mark_complete,
        )
    except PermissionError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    progress = store.list_progress(conn, session["evaluator_id"])
    return {"saved": saved, "progress": progress}


@app.post("/api/submit")
def submit_final(
    session: sqlite3.Row = Depends(require_evaluator_session),
    conn: sqlite3.Connection = Depends(get_conn),
) -> dict[str, Any]:
    try:
        summary = store.finalize_submission(conn, session["evaluator_id"])
    except PermissionError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"ok": True, "summary": summary}


@app.get("/api/images/{media_id}.jpg")
def get_image(
    media_id: str,
    session: sqlite3.Row = Depends(require_evaluator_session),
    settings: Settings = Depends(get_cfg),
) -> FileResponse:
    # Session required: images are not world-readable.
    _ = session
    if media_id not in IMAGE_IDS:
        raise HTTPException(status_code=404, detail="unknown_media")
    path = Path(settings.images_dir) / f"{media_id}.jpg"
    if not path.is_file():
        raise HTTPException(status_code=404, detail="image_missing")
    return FileResponse(path, media_type="image/jpeg", filename=f"{media_id}.jpg")


@app.get("/api/facilitator/export.csv")
def export_csv(
    evaluator_id: str | None = None,
    _: None = Depends(require_facilitator),
    conn: sqlite3.Connection = Depends(get_conn),
) -> StreamingResponse:
    if evaluator_id and evaluator_id not in ("R1", "R2", "R3"):
        raise HTTPException(status_code=400, detail="bad_evaluator_id")
    rows = store.export_wide_rows(conn, evaluator_id)
    buf = io.StringIO()
    fields = [
        "media_id",
        "rater_id",
        "media_type",
        "sharpness",
        "blur",
        "noise",
        "brightness",
        "contrast",
        "blocking_artifacts",
        "ringing_artifacts",
        "flickering",
        "motion_stability",
        "overall_visual_quality",
        "notes",
        "updated_at",
        "image_status",
    ]
    w = csv.DictWriter(buf, fieldnames=fields)
    w.writeheader()
    for row in rows:
        w.writerow(row)
    data = buf.getvalue().encode("utf-8")
    name = f"ratings_{evaluator_id or 'ALL'}.csv"
    return StreamingResponse(
        io.BytesIO(data),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{name}"'},
    )


@app.get("/api/facilitator/status")
def facilitator_status(
    _: None = Depends(require_facilitator),
    conn: sqlite3.Connection = Depends(get_conn),
) -> dict[str, Any]:
    out = {}
    for eid in ("R1", "R2", "R3"):
        out[eid] = store.list_progress(conn, eid)
    return {"evaluators": out}


@app.get("/r/{invite_token}", response_class=HTMLResponse)
def invite_landing(invite_token: str) -> HTMLResponse:
    """Invite deep-link: loads SPA with token in hash (not logged server-side beyond exchange)."""
    index = STATIC_DIR / "index.html"
    html = index.read_text(encoding="utf-8")
    # Inject invite into a meta tag; SPA exchanges it then clears from history where possible.
    inject = f'<meta name="invite-token" content="{html.escape(invite_token, quote=True)}">'
    html = html.replace("</head>", f"{inject}\n</head>", 1)
    return HTMLResponse(html)


@app.get("/", response_class=HTMLResponse)
def root() -> HTMLResponse:
    return HTMLResponse((STATIC_DIR / "index.html").read_text(encoding="utf-8"))


if STATIC_DIR.is_dir():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
