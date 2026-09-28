"""Bulk publish approved event documentation media to Facebook via Graph API."""

from __future__ import annotations

from pathlib import Path

from sqlalchemy.orm import Session

from app.crud import audit_log as audit_crud
from app.crud import facebook_post as fb_crud
from app.crud import media as media_crud
from app.models.media_constants import (
    FB_FAILED,
    FB_PUBLISHED,
    FB_PUBLISHING,
    MEDIA_CATEGORY_EVENT,
)
from app.models.media_file import MediaFile
from app.models.user import User
from app.services import facebook_service
from app.services.facebook_service import FacebookServiceError, is_capability_error, resolve_media_source


def _caption_for_media(media: MediaFile, base_message: str | None) -> str:
    """Build Facebook caption: admin text if provided, else event title."""
    req = media.request
    event_name = (req.title if req else "ACCESS Event").strip()
    custom = (base_message or "").strip()
    text = custom or event_name or "Shared from ACCESS VisionCheck"
    return text[:5000]


def _album_name_for_media(media: MediaFile) -> str:
    req = media.request
    title = (req.title if req else "ACCESS Event").strip()
    return title[:255] or "ACCESS Event"


def _photo_source(media: MediaFile) -> tuple[str | None, Path | None]:
    public_url, local_path = resolve_media_source(media.file_url, media.file_type)
    return public_url, local_path


def publish_single_event_media(
    db: Session,
    *,
    media_id: int,
    message: str | None,
    actor: User,
) -> dict:
    media = media_crud.get(db, media_id)
    if not media:
        return {"media_id": media_id, "status": "failed", "error": "Media not found"}

    if media.media_category != MEDIA_CATEGORY_EVENT:
        return {
            "media_id": media_id,
            "status": "failed",
            "error": "Only event documentation media can be published to Facebook.",
        }

    if not media_crud.is_event_documentation_publishable(media):
        if media.approval_status == "rejected":
            return {"media_id": media_id, "status": "failed", "error": "Rejected media cannot be published."}
        if media.facebook_publish_status == "published":
            return {"media_id": media_id, "status": "skipped", "error": "Already published."}
        if not media.is_best_shot:
            return {
                "media_id": media_id,
                "status": "failed",
                "error": "Mark this media as a best pick before publishing to Facebook.",
            }
        return {"media_id": media_id, "status": "failed", "error": "Media cannot be published in its current state."}

    caption = _caption_for_media(media, message)
    fb_row = fb_crud.create_attempt(db, media_id=media_id, message=caption)
    media_crud.set_facebook_publish_status(db, media, status=FB_PUBLISHING)

    try:
        fb_id = facebook_service.post_media_to_facebook(
            caption,
            file_url=media.file_url,
            file_type=media.file_type,
        )
        fb_crud.mark_success(db, fb_row, fb_id)
        media_crud.set_facebook_publish_status(
            db, media, status=FB_PUBLISHED, facebook_post_id=fb_id
        )
        audit_crud.create(
            db,
            user_id=actor.id,
            action="facebook_event_publish",
            description=f"Published event media {media_id} to Facebook as {fb_id}",
        )
        return {
            "media_id": media_id,
            "status": "published",
            "facebook_post_id": fb_id,
            "facebook_published_at": media.facebook_published_at.isoformat()
            if media.facebook_published_at
            else None,
        }
    except FacebookServiceError as exc:
        fb_crud.mark_failed(db, fb_row, str(exc))
        media_crud.set_facebook_publish_status(db, media, status=FB_FAILED, error=str(exc))
        return {"media_id": media_id, "status": "failed", "error": str(exc)}
    except Exception as exc:  # noqa: BLE001
        fb_crud.mark_failed(db, fb_row, str(exc))
        media_crud.set_facebook_publish_status(db, media, status=FB_FAILED, error=str(exc))
        return {"media_id": media_id, "status": "failed", "error": "Unexpected error during Facebook publish."}


def _prepare_publishable_media(db: Session, media_id: int) -> tuple[MediaFile | None, dict | None]:
    media = media_crud.get(db, media_id)
    if not media:
        return None, {"media_id": media_id, "status": "failed", "error": "Media not found"}
    if media.media_category != MEDIA_CATEGORY_EVENT:
        return None, {
            "media_id": media_id,
            "status": "failed",
            "error": "Only event documentation media can be published to Facebook.",
        }
    if not media_crud.is_event_documentation_publishable(media):
        if media.approval_status == "rejected":
            return None, {"media_id": media_id, "status": "failed", "error": "Rejected media cannot be published."}
        if media.facebook_publish_status == "published":
            return None, {"media_id": media_id, "status": "skipped", "error": "Already published."}
        if not media.is_best_shot:
            return None, {
                "media_id": media_id,
                "status": "failed",
                "error": "Mark this media as a best pick before publishing to Facebook.",
            }
        return None, {
            "media_id": media_id,
            "status": "failed",
            "error": "Media cannot be published in its current state.",
        }
    return media, None


def _publish_photo_group_sequential(
    db: Session,
    *,
    photos: list[MediaFile],
    message: str | None,
    actor: User,
    fb_rows: list,
    caption: str,
) -> list[dict]:
    """Fallback: one Facebook post per photo when grouped album publish is unavailable."""
    results: list[dict] = []
    for media, fb_row in zip(photos, fb_rows, strict=True):
        try:
            fb_id = facebook_service.post_media_to_facebook(
                caption,
                file_url=media.file_url,
                file_type=media.file_type,
            )
            fb_crud.mark_success(db, fb_row, fb_id)
            media_crud.set_facebook_publish_status(
                db, media, status=FB_PUBLISHED, facebook_post_id=fb_id
            )
            results.append(
                {
                    "media_id": media.id,
                    "status": "published",
                    "facebook_post_id": fb_id,
                    "facebook_published_at": media.facebook_published_at.isoformat()
                    if media.facebook_published_at
                    else None,
                    "publish_mode": "sequential_fallback",
                }
            )
        except FacebookServiceError as exc:
            error = str(exc)
            fb_crud.mark_failed(db, fb_row, error)
            media_crud.set_facebook_publish_status(db, media, status=FB_FAILED, error=error)
            results.append({"media_id": media.id, "status": "failed", "error": error})
        except Exception as exc:  # noqa: BLE001
            error = "Unexpected error during Facebook publish."
            fb_crud.mark_failed(db, fb_row, f"{error} ({exc})")
            media_crud.set_facebook_publish_status(db, media, status=FB_FAILED, error=error)
            results.append({"media_id": media.id, "status": "failed", "error": error})

    audit_crud.create(
        db,
        user_id=actor.id,
        action="facebook_event_publish",
        description=(
            f"Published {sum(1 for r in results if r.get('status') == 'published')} "
            f"event photos to Facebook individually (grouped album API unavailable)"
        ),
    )
    return results


def _publish_photo_group(
    db: Session,
    *,
    photos: list[MediaFile],
    message: str | None,
    actor: User,
) -> list[dict]:
    """Publish multiple photos as swipeable feed grid(s), with album/sequential fallbacks."""
    caption = _caption_for_media(photos[0], message)
    album_name = _album_name_for_media(photos[0])
    sources = [_photo_source(media) for media in photos]

    fb_rows: list = []
    for media in photos:
        fb_rows.append(fb_crud.create_attempt(db, media_id=media.id, message=caption))
        media_crud.set_facebook_publish_status(db, media, status=FB_PUBLISHING)

    def _results_from_post_chunks(
        chunks: list[dict[str, str | int]],
        publish_mode: str,
    ) -> list[dict]:
        out: list[dict] = []
        offset = 0
        for chunk in chunks:
            post_id = str(chunk["post_id"])
            count = int(chunk["count"])
            chunk_media = photos[offset : offset + count]
            chunk_rows = fb_rows[offset : offset + count]
            offset += count
            for media, fb_row in zip(chunk_media, chunk_rows, strict=True):
                fb_crud.mark_success(db, fb_row, post_id)
                media_crud.set_facebook_publish_status(
                    db, media, status=FB_PUBLISHED, facebook_post_id=post_id
                )
                out.append(
                    {
                        "media_id": media.id,
                        "status": "published",
                        "facebook_post_id": post_id,
                        "facebook_published_at": media.facebook_published_at.isoformat()
                        if media.facebook_published_at
                        else None,
                        "publish_mode": publish_mode,
                    }
                )
        return out

    try:
        feed_chunks = facebook_service.post_grouped_photos_to_feed(caption, photos=sources)
        results = _results_from_post_chunks(feed_chunks, "multi_photo_post")
        post_ids = ", ".join(str(c["post_id"]) for c in feed_chunks)
        audit_crud.create(
            db,
            user_id=actor.id,
            action="facebook_event_publish",
            description=(
                f"Published {len(photos)} event photos to Facebook as "
                f"{len(feed_chunks)} feed grid post(s) ({post_ids})"
            ),
        )
        return results
    except FacebookServiceError as feed_exc:
        try:
            album_result = facebook_service.post_photos_to_page_album(
                album_name,
                caption,
                photos=sources,
            )
            post_id = str(album_result["post_id"])
            results = _results_from_post_chunks(
                [{"post_id": post_id, "count": len(photos)}],
                "album",
            )
            audit_crud.create(
                db,
                user_id=actor.id,
                action="facebook_event_publish",
                description=(
                    f"Published {len(photos)} event photos to Facebook album {post_id} "
                    f"(feed grid unavailable: {feed_exc})"
                ),
            )
            return results
        except FacebookServiceError as album_exc:
            if is_capability_error(feed_exc) or is_capability_error(album_exc):
                return _publish_photo_group_sequential(
                    db,
                    photos=photos,
                    message=message,
                    actor=actor,
                    fb_rows=fb_rows,
                    caption=caption,
                )
            error = str(album_exc)
            results = []
            for media, fb_row in zip(photos, fb_rows, strict=True):
                fb_crud.mark_failed(db, fb_row, error)
                media_crud.set_facebook_publish_status(db, media, status=FB_FAILED, error=error)
                results.append({"media_id": media.id, "status": "failed", "error": error})
            return results
    except Exception as exc:  # noqa: BLE001
        error = "Unexpected error during Facebook publish."
        results = []
        for media, fb_row in zip(photos, fb_rows, strict=True):
            fb_crud.mark_failed(db, fb_row, f"{error} ({exc})")
            media_crud.set_facebook_publish_status(db, media, status=FB_FAILED, error=error)
            results.append({"media_id": media.id, "status": "failed", "error": error})
        return results


def bulk_publish_event_media(
    db: Session,
    *,
    media_ids: list[int],
    message: str | None,
    actor: User,
) -> dict:
    if len(media_ids) == 1:
        outcome = publish_single_event_media(db, media_id=media_ids[0], message=message, actor=actor)
        st = outcome.get("status")
        return {
            "results": [outcome],
            "succeeded": 1 if st == "published" else 0,
            "failed": 1 if st == "failed" else 0,
            "skipped": 1 if st == "skipped" else 0,
            "total": 1,
            "grouped": False,
        }

    photos: list[MediaFile] = []
    videos: list[MediaFile] = []
    results: list[dict] = []

    for mid in media_ids:
        media, error_outcome = _prepare_publishable_media(db, mid)
        if error_outcome:
            results.append(error_outcome)
            continue
        assert media is not None
        if media.file_type == "video":
            videos.append(media)
        else:
            photos.append(media)

    if len(photos) >= 2:
        results.extend(_publish_photo_group(db, photos=photos, message=message, actor=actor))
    elif len(photos) == 1:
        results.append(
            publish_single_event_media(db, media_id=photos[0].id, message=message, actor=actor)
        )

    for video in videos:
        results.append(
            publish_single_event_media(db, media_id=video.id, message=message, actor=actor)
        )

    succeeded = sum(1 for r in results if r.get("status") == "published")
    failed = sum(1 for r in results if r.get("status") == "failed")
    skipped = sum(1 for r in results if r.get("status") == "skipped")
    grouped = len(photos) >= 2 and any(
        r.get("publish_mode") in ("album", "multi_photo_post") for r in results
    )
    fallback_sequential = len(photos) >= 2 and any(
        r.get("publish_mode") == "sequential_fallback" for r in results
    )
    feed_grid = len(photos) >= 2 and any(
        r.get("publish_mode") == "multi_photo_post" for r in results
    )
    unique_post_ids = {
        r.get("facebook_post_id")
        for r in results
        if r.get("status") == "published" and r.get("facebook_post_id")
    }

    return {
        "results": results,
        "succeeded": succeeded,
        "failed": failed,
        "skipped": skipped,
        "total": len(media_ids),
        "grouped": grouped,
        "group_size": len(photos) if grouped else 0,
        "fallback_sequential": fallback_sequential,
        "feed_grid": feed_grid,
        "feed_post_count": len(unique_post_ids) if feed_grid else 0,
    }
