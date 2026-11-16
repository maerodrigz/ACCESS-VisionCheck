"""SQLite persistence for Phase 6B human ratings."""

from __future__ import annotations

import json
import sqlite3
import threading
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

from app.criteria import CRITERION_IDS, IMAGE_IDS

_lock = threading.Lock()


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def connect(db_path: str) -> sqlite3.Connection:
    path = Path(db_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    return conn


def init_db(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS evaluators (
            evaluator_id TEXT PRIMARY KEY,
            invite_token_hash TEXT NOT NULL UNIQUE,
            display_label TEXT NOT NULL,
            created_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS sessions (
            session_token_hash TEXT PRIMARY KEY,
            evaluator_id TEXT NOT NULL REFERENCES evaluators(evaluator_id),
            created_at TEXT NOT NULL,
            last_seen_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS image_ratings (
            evaluator_id TEXT NOT NULL,
            media_id TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'in_progress',
            ratings_json TEXT NOT NULL DEFAULT '{}',
            notes TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL,
            submitted_at TEXT,
            PRIMARY KEY (evaluator_id, media_id),
            FOREIGN KEY (evaluator_id) REFERENCES evaluators(evaluator_id)
        );

        CREATE TABLE IF NOT EXISTS rating_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            evaluator_id TEXT NOT NULL,
            media_id TEXT NOT NULL,
            criterion TEXT,
            rating INTEGER,
            event_type TEXT NOT NULL,
            created_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS final_submissions (
            evaluator_id TEXT PRIMARY KEY,
            submitted_at TEXT NOT NULL,
            summary_json TEXT NOT NULL,
            FOREIGN KEY (evaluator_id) REFERENCES evaluators(evaluator_id)
        );
        """
    )
    conn.commit()


@contextmanager
def locked(conn: sqlite3.Connection) -> Iterator[sqlite3.Connection]:
    with _lock:
        yield conn


def upsert_evaluator(
    conn: sqlite3.Connection,
    *,
    evaluator_id: str,
    invite_token_hash: str,
    display_label: str,
) -> None:
    with locked(conn):
        conn.execute(
            """
            INSERT INTO evaluators (evaluator_id, invite_token_hash, display_label, created_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(evaluator_id) DO UPDATE SET
              invite_token_hash=excluded.invite_token_hash,
              display_label=excluded.display_label
            """,
            (evaluator_id, invite_token_hash, display_label, _utc_now()),
        )
        conn.commit()


def find_evaluator_by_invite_hash(
    conn: sqlite3.Connection, token_hash: str
) -> sqlite3.Row | None:
    cur = conn.execute(
        "SELECT * FROM evaluators WHERE invite_token_hash = ?",
        (token_hash,),
    )
    return cur.fetchone()


def create_session(
    conn: sqlite3.Connection, *, session_token_hash: str, evaluator_id: str
) -> None:
    now = _utc_now()
    with locked(conn):
        conn.execute(
            """
            INSERT INTO sessions (session_token_hash, evaluator_id, created_at, last_seen_at)
            VALUES (?, ?, ?, ?)
            """,
            (session_token_hash, evaluator_id, now, now),
        )
        conn.commit()


def touch_session(conn: sqlite3.Connection, session_token_hash: str) -> sqlite3.Row | None:
    with locked(conn):
        conn.execute(
            "UPDATE sessions SET last_seen_at = ? WHERE session_token_hash = ?",
            (_utc_now(), session_token_hash),
        )
        conn.commit()
    cur = conn.execute(
        """
        SELECT s.*, e.display_label
        FROM sessions s
        JOIN evaluators e ON e.evaluator_id = s.evaluator_id
        WHERE s.session_token_hash = ?
        """,
        (session_token_hash,),
    )
    return cur.fetchone()


def get_final_submission(conn: sqlite3.Connection, evaluator_id: str) -> sqlite3.Row | None:
    cur = conn.execute(
        "SELECT * FROM final_submissions WHERE evaluator_id = ?",
        (evaluator_id,),
    )
    return cur.fetchone()


def get_image_rating(
    conn: sqlite3.Connection, evaluator_id: str, media_id: str
) -> dict[str, Any]:
    cur = conn.execute(
        "SELECT * FROM image_ratings WHERE evaluator_id = ? AND media_id = ?",
        (evaluator_id, media_id),
    )
    row = cur.fetchone()
    if row is None:
        return {
            "media_id": media_id,
            "status": "empty",
            "ratings": {},
            "notes": "",
            "updated_at": None,
            "submitted_at": None,
        }
    return {
        "media_id": row["media_id"],
        "status": row["status"],
        "ratings": json.loads(row["ratings_json"] or "{}"),
        "notes": row["notes"] or "",
        "updated_at": row["updated_at"],
        "submitted_at": row["submitted_at"],
    }


def list_progress(conn: sqlite3.Connection, evaluator_id: str) -> dict[str, Any]:
    cur = conn.execute(
        "SELECT media_id, status, ratings_json FROM image_ratings WHERE evaluator_id = ?",
        (evaluator_id,),
    )
    by_id = {row["media_id"]: row for row in cur.fetchall()}
    complete = 0
    partial = 0
    items: list[dict[str, Any]] = []
    for mid in IMAGE_IDS:
        row = by_id.get(mid)
        ratings = json.loads(row["ratings_json"]) if row else {}
        filled = sum(
            1
            for c in CRITERION_IDS
            if ratings.get(c) in (1, 2, 3, 4, 5) or ratings.get(c) == "N/A"
        )
        status = "empty"
        if row:
            status = row["status"]
        if filled == len(CRITERION_IDS):
            status = "complete" if status != "locked" else status
            complete += 1
        elif filled > 0:
            status = "partial"
            partial += 1
        items.append(
            {
                "media_id": mid,
                "status": status,
                "filled_criteria": filled,
                "total_criteria": len(CRITERION_IDS),
            }
        )
    final = get_final_submission(conn, evaluator_id)
    return {
        "n_images": len(IMAGE_IDS),
        "n_complete": complete,
        "n_partial": partial,
        "n_empty": len(IMAGE_IDS) - complete - partial,
        "final_submitted": final is not None,
        "final_submitted_at": final["submitted_at"] if final else None,
        "images": items,
    }


def save_image_ratings(
    conn: sqlite3.Connection,
    *,
    evaluator_id: str,
    media_id: str,
    ratings: dict[str, Any],
    notes: str,
    mark_complete: bool,
) -> dict[str, Any]:
    if media_id not in IMAGE_IDS:
        raise ValueError("unknown_media_id")
    final = get_final_submission(conn, evaluator_id)
    if final is not None:
        raise PermissionError("final_submission_locked")

    existing = get_image_rating(conn, evaluator_id, media_id)
    merged = dict(existing["ratings"])
    for key, val in ratings.items():
        if key not in CRITERION_IDS:
            raise ValueError(f"unknown_criterion:{key}")
        if val is None or val == "":
            merged.pop(key, None)
            continue
        if val == "N/A":
            merged[key] = "N/A"
            continue
        iv = int(val)
        if iv not in (1, 2, 3, 4, 5):
            raise ValueError("rating_out_of_range")
        merged[key] = iv

    filled = sum(
        1
        for c in CRITERION_IDS
        if merged.get(c) in (1, 2, 3, 4, 5) or merged.get(c) == "N/A"
    )
    status = "complete" if (mark_complete and filled == len(CRITERION_IDS)) or filled == len(
        CRITERION_IDS
    ) else ("partial" if filled else "empty")
    now = _utc_now()
    with locked(conn):
        conn.execute(
            """
            INSERT INTO image_ratings
              (evaluator_id, media_id, status, ratings_json, notes, updated_at, submitted_at)
            VALUES (?, ?, ?, ?, ?, ?, NULL)
            ON CONFLICT(evaluator_id, media_id) DO UPDATE SET
              status=excluded.status,
              ratings_json=excluded.ratings_json,
              notes=excluded.notes,
              updated_at=excluded.updated_at
            """,
            (
                evaluator_id,
                media_id,
                status,
                json.dumps(merged, separators=(",", ":")),
                notes or "",
                now,
            ),
        )
        for key, val in ratings.items():
            if key not in CRITERION_IDS:
                continue
            conn.execute(
                """
                INSERT INTO rating_events
                  (evaluator_id, media_id, criterion, rating, event_type, created_at)
                VALUES (?, ?, ?, ?, 'autosave', ?)
                """,
                (
                    evaluator_id,
                    media_id,
                    key,
                    None if val in (None, "", "N/A") else int(val) if val != "N/A" else None,
                    now,
                ),
            )
        conn.commit()
    return get_image_rating(conn, evaluator_id, media_id)


def finalize_submission(conn: sqlite3.Connection, evaluator_id: str) -> dict[str, Any]:
    progress = list_progress(conn, evaluator_id)
    if progress["final_submitted"]:
        raise PermissionError("already_submitted")
    if progress["n_complete"] < progress["n_images"]:
        raise ValueError("incomplete_ratings")
    now = _utc_now()
    summary = {
        "n_images": progress["n_images"],
        "n_complete": progress["n_complete"],
        "submitted_at": now,
    }
    with locked(conn):
        conn.execute(
            """
            INSERT INTO final_submissions (evaluator_id, submitted_at, summary_json)
            VALUES (?, ?, ?)
            """,
            (evaluator_id, now, json.dumps(summary)),
        )
        conn.execute(
            """
            UPDATE image_ratings SET status = 'locked', submitted_at = ?
            WHERE evaluator_id = ?
            """,
            (now, evaluator_id),
        )
        conn.execute(
            """
            INSERT INTO rating_events
              (evaluator_id, media_id, criterion, rating, event_type, created_at)
            VALUES (?, '', NULL, NULL, 'final_submit', ?)
            """,
            (evaluator_id, now),
        )
        conn.commit()
    return summary


def export_wide_rows(conn: sqlite3.Connection, evaluator_id: str | None = None) -> list[dict[str, Any]]:
    """Export Phase 6A-compatible wide rows (one row per media_id × evaluator)."""
    if evaluator_id:
        evals = [evaluator_id]
    else:
        cur = conn.execute("SELECT evaluator_id FROM evaluators ORDER BY evaluator_id")
        evals = [r["evaluator_id"] for r in cur.fetchall()]

    rows: list[dict[str, Any]] = []
    for eid in evals:
        for mid in IMAGE_IDS:
            rec = get_image_rating(conn, eid, mid)
            ratings = rec["ratings"]
            row = {
                "media_id": mid,
                "rater_id": eid,
                "media_type": "photo",
                "sharpness": ratings.get("sharpness", ""),
                "blur": ratings.get("blur", ""),
                "noise": ratings.get("noise", ""),
                "brightness": ratings.get("brightness", ""),
                "contrast": ratings.get("contrast", ""),
                "blocking_artifacts": ratings.get("blocking_artifacts", ""),
                "ringing_artifacts": ratings.get("ringing_artifacts", ""),
                "flickering": "N/A",
                "motion_stability": "N/A",
                "overall_visual_quality": ratings.get("overall_visual_quality", ""),
                "notes": rec.get("notes") or "",
                "updated_at": rec.get("updated_at") or "",
                "image_status": rec.get("status") or "",
            }
            rows.append(row)
    return rows
