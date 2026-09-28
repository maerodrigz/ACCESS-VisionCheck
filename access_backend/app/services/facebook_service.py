"""Post to a Facebook Page via Graph API (credentials from .env)."""

from __future__ import annotations

import json
import mimetypes
import os
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from app.config import facebook_credentials, settings

GRAPH_VERSION = "v21.0"
GRAPH_BASE = f"https://graph.facebook.com/{GRAPH_VERSION}"


class FacebookServiceError(Exception):
    """Raised when Graph API or configuration fails."""

    def __init__(self, code: str, message: str, *, graph_code: int | None = None):
        self.code = code
        self.graph_code = graph_code
        super().__init__(message)


def is_capability_error(exc: FacebookServiceError) -> bool:
    """True when Meta blocks this API for the app (OAuth error #3)."""
    if exc.graph_code == 3:
        return True
    msg = str(exc).lower()
    return "does not have the capability" in msg or "(#3)" in msg


def _page_id() -> str:
    pid, _ = facebook_credentials()
    if not pid:
        raise FacebookServiceError(
            "invalid_page_id",
            "FACEBOOK_PAGE_ID is not set in .env.",
        )
    return pid


def _access_token() -> str:
    _, token = facebook_credentials()
    if not token:
        raise FacebookServiceError(
            "missing_token",
            "FACEBOOK_PAGE_ACCESS_TOKEN is not set in .env.",
        )
    return token


def _request_json(method: str, url: str, data: dict | None = None, files: dict | None = None) -> dict:
    if files:
        from io import BytesIO

        boundary = "----AccessVisionCheckBoundary"
        body = BytesIO()
        for key, (filename, file_bytes, content_type) in files.items():
            body.write(f"--{boundary}\r\n".encode())
            body.write(
                f'Content-Disposition: form-data; name="{key}"; filename="{filename}"\r\n'.encode()
            )
            body.write(f"Content-Type: {content_type}\r\n\r\n".encode())
            body.write(file_bytes)
            body.write(b"\r\n")
        if data:
            for key, value in data.items():
                body.write(f"--{boundary}\r\n".encode())
                body.write(f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode())
                body.write(f"{value}\r\n".encode())
        body.write(f"--{boundary}--\r\n".encode())
        req = urllib.request.Request(
            url,
            data=body.getvalue(),
            method=method,
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        )
    elif data:
        encoded = urllib.parse.urlencode(data).encode()
        req = urllib.request.Request(url, data=encoded, method=method)
    else:
        req = urllib.request.Request(url, method=method)

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        try:
            payload = json.loads(exc.read().decode())
            err = payload.get("error", {})
            msg = err.get("message", str(exc))
            code = err.get("code", exc.code)
            if "publish_actions" in msg.lower():
                msg = (
                    f"{msg} Use a Page access token from Graph API Explorer "
                    "(me/accounts → access_token for your Page), not your personal user token."
                )
            graph_code = int(code) if isinstance(code, int) else None
            raise FacebookServiceError(
                "graph_api_error",
                f"Facebook API error ({code}): {msg}",
                graph_code=graph_code,
            ) from exc
        except (json.JSONDecodeError, UnicodeDecodeError):
            raise FacebookServiceError("graph_api_error", f"Facebook API HTTP {exc.code}") from exc
    except urllib.error.URLError as exc:
        raise FacebookServiceError("network_error", f"Could not reach Facebook: {exc.reason}") from exc


def inspect_page_token() -> dict:
    """
    Verify the configured token is a Page token for FACEBOOK_PAGE_ID.
    User tokens trigger deprecated publish_actions errors when posting to a Page.
    """
    page_id, token = facebook_credentials()
    if not token:
        return {"ok": False, "reason": "missing_token"}
    try:
        qs = urllib.parse.urlencode({"access_token": token, "fields": "id,name"})
        url = f"{GRAPH_BASE}/me?{qs}"
        with urllib.request.urlopen(url, timeout=20) as resp:
            payload = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        try:
            payload = json.loads(exc.read().decode())
            err = payload.get("error", {})
            return {"ok": False, "reason": err.get("message", f"HTTP {exc.code}")}
        except (json.JSONDecodeError, UnicodeDecodeError):
            return {"ok": False, "reason": f"HTTP {exc.code}"}
    except urllib.error.URLError as exc:
        return {"ok": False, "reason": str(exc.reason)}

    token_id = str(payload.get("id", ""))
    token_name = payload.get("name")
    if page_id and token_id == page_id:
        return {
            "ok": True,
            "token_subject_id": token_id,
            "token_subject_name": token_name,
        }
    if page_id and token_id != page_id:
        return {
            "ok": False,
            "reason": (
                f"Token is for {token_name or 'another account'} (id {token_id}), not your Page "
                f"(id {page_id}). In Graph API Explorer run me/accounts and copy the access_token "
                "inside your Page row."
            ),
            "token_subject_id": token_id,
            "token_subject_name": token_name,
        }
    return {
        "ok": True,
        "token_subject_id": token_id,
        "token_subject_name": token_name,
    }


def resolve_image_source(file_url: str, file_type: str) -> tuple[str | None, Path | None]:
    """Return (public_http_url, local_file_path) for image media."""
    if file_type == "video":
        return None, None
    if not file_url or not file_url.strip():
        return None, None

    url = file_url.strip()
    if url.startswith("http://") or url.startswith("https://"):
        return url, None

    rel = url.lstrip("/")
    if rel.startswith("uploads/"):
        rel = rel[len("uploads/") :]
    local = Path(settings.upload_dir) / rel
    if local.is_file():
        public = f"{settings.public_api_url.rstrip('/')}/{url.lstrip('/')}"
        return public, local

    public = f"{settings.public_api_url.rstrip('/')}/{url.lstrip('/')}"
    return public, None


def post_to_facebook(message: str, image_url: str | None = None, *, local_path: Path | None = None) -> str:
    """
    Publish to the configured Facebook Page.
    Returns the Graph API post/photo id.
    """
    page_id = _page_id()
    token = _access_token()
    text = (message or "").strip() or "Shared from ACCESS VisionCheck"

    if image_url or local_path:
        endpoint = f"{GRAPH_BASE}/{page_id}/photos"
        if local_path and local_path.is_file():
            content = local_path.read_bytes()
            ctype = mimetypes.guess_type(str(local_path))[0] or "application/octet-stream"
            data = {"message": text, "access_token": token}
            result = _request_json(
                "POST",
                endpoint,
                data=data,
                files={"source": (local_path.name, content, ctype)},
            )
        else:
            if not image_url:
                raise FacebookServiceError(
                    "image_unreachable",
                    "Image URL is missing or the file is not on disk.",
                )
            result = _request_json(
                "POST",
                endpoint,
                data={"url": image_url, "message": text, "access_token": token},
            )
    else:
        endpoint = f"{GRAPH_BASE}/{page_id}/feed"
        result = _request_json(
            "POST",
            endpoint,
            data={"message": text, "access_token": token},
        )

    post_id = result.get("post_id") or result.get("id")
    if not post_id:
        raise FacebookServiceError("graph_api_error", "Facebook did not return a post id.")
    return str(post_id)


def post_video_to_facebook(message: str, *, local_path: Path) -> str:
    """Upload a video file to the Facebook Page via Graph API."""
    page_id = _page_id()
    token = _access_token()
    if not local_path.is_file():
        raise FacebookServiceError("video_unreachable", "Video file is not on disk.")
    content = local_path.read_bytes()
    ctype = mimetypes.guess_type(str(local_path))[0] or "video/mp4"
    endpoint = f"{GRAPH_BASE}/{page_id}/videos"
    data = {"description": (message or "").strip() or "Shared from ACCESS VisionCheck", "access_token": token}
    result = _request_json(
        "POST",
        endpoint,
        data=data,
        files={"source": (local_path.name, content, ctype)},
    )
    post_id = result.get("id")
    if not post_id:
        raise FacebookServiceError("graph_api_error", "Facebook did not return a video id.")
    return str(post_id)


def resolve_media_source(file_url: str, file_type: str) -> tuple[str | None, Path | None]:
    """Return (public_http_url, local_file_path) for photo or video media."""
    if not file_url or not file_url.strip():
        return None, None

    url = file_url.strip()
    if url.startswith("http://") or url.startswith("https://"):
        return url, None

    rel = url.lstrip("/")
    if rel.startswith("uploads/"):
        rel = rel[len("uploads/") :]
    local = Path(settings.upload_dir) / rel
    if local.is_file():
        public = f"{settings.public_api_url.rstrip('/')}/{url.lstrip('/')}"
        return public, local

    public = f"{settings.public_api_url.rstrip('/')}/{url.lstrip('/')}"
    return public, None


def post_media_to_facebook(message: str, *, file_url: str, file_type: str) -> str:
    """Publish photo or video event documentation to the configured Facebook Page."""
    if file_type == "video":
        _, local_path = resolve_media_source(file_url, file_type)
        if local_path and local_path.is_file():
            return post_video_to_facebook(message, local_path=local_path)
        public_url, _ = resolve_media_source(file_url, file_type)
        if public_url:
            from app.services.media_file_bytes import read_media_file_bytes
            import tempfile

            content = read_media_file_bytes(public_url, timeout=120.0)
            if content:
                suffix = Path(file_url.split("?")[0]).suffix or ".mp4"
                with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
                    tmp.write(content)
                    temp_path = Path(tmp.name)
                try:
                    return post_video_to_facebook(message, local_path=temp_path)
                finally:
                    temp_path.unlink(missing_ok=True)
        raise FacebookServiceError(
            "video_unreachable",
            "Video must be reachable (local disk or Firebase HTTPS URL) for Graph API upload.",
        )
    public_url, local_path = resolve_image_source(file_url, file_type)
    return post_to_facebook(message, image_url=public_url, local_path=local_path)


def _upload_page_photo(
    *,
    image_url: str | None = None,
    local_path: Path | None = None,
    published: bool = True,
    no_story: bool = False,
    album_id: str | None = None,
    message: str | None = None,
) -> str:
    """Upload one photo to the Page or to a Page album."""
    page_id = _page_id()
    token = _access_token()
    target_id = album_id or page_id
    endpoint = f"{GRAPH_BASE}/{target_id}/photos"
    data: dict[str, str] = {"access_token": token}
    if not published:
        data["published"] = "false"
    if no_story:
        data["no_story"] = "true"
    if message:
        data["message"] = message[:5000]

    if local_path and local_path.is_file():
        content = local_path.read_bytes()
        ctype = mimetypes.guess_type(str(local_path))[0] or "application/octet-stream"
        result = _request_json(
            "POST",
            endpoint,
            data=data,
            files={"source": (local_path.name, content, ctype)},
        )
    else:
        if not image_url:
            raise FacebookServiceError(
                "image_unreachable",
                "Image URL is missing or the file is not on disk.",
            )
        data["url"] = image_url
        result = _request_json("POST", endpoint, data=data)

    photo_id = result.get("id")
    if not photo_id:
        raise FacebookServiceError("graph_api_error", "Facebook did not return a photo id.")
    return str(photo_id)


def list_page_albums() -> list[dict]:
    """Return albums on the configured Facebook Page."""
    page_id = _page_id()
    token = _access_token()
    qs = urllib.parse.urlencode({"access_token": token, "fields": "id,name,count"})
    url = f"{GRAPH_BASE}/{page_id}/albums?{qs}"
    try:
        with urllib.request.urlopen(url, timeout=20) as resp:
            payload = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        try:
            body = json.loads(exc.read().decode())
            err = body.get("error", {})
            code = err.get("code")
            graph_code = int(code) if isinstance(code, int) else None
            raise FacebookServiceError(
                "graph_api_error",
                f"Facebook API error ({code}): {err.get('message', exc.code)}",
                graph_code=graph_code,
            ) from exc
        except (json.JSONDecodeError, UnicodeDecodeError):
            raise FacebookServiceError("graph_api_error", f"Facebook API HTTP {exc.code}") from exc
    except urllib.error.URLError as exc:
        raise FacebookServiceError("network_error", f"Could not reach Facebook: {exc.reason}") from exc
    return payload.get("data") or []


def resolve_page_album_id() -> str:
    """
    Pick an existing Page album for bulk uploads.
    Meta blocks POST /{page-id}/albums for most apps (OAuth error #3).
    """
    configured = (
        os.getenv("FACEBOOK_PAGE_ALBUM_ID") or settings.facebook_page_album_id or ""
    ).strip()
    if configured:
        return configured

    albums = list_page_albums()
    if not albums:
        raise FacebookServiceError(
            "no_album",
            "No Facebook Page album found. Create an album on your Page (for example "
            "'ACCESS Events'), then set FACEBOOK_PAGE_ALBUM_ID in access_backend/.env.",
        )

    skip_names = {"profile pictures", "cover photos", "covers", "profile pics"}
    preferred = ("access events", "access event", "timeline photos", "photos")

    for needle in preferred:
        for album in albums:
            name = (album.get("name") or "").strip().lower()
            if needle in name and name not in skip_names:
                return str(album["id"])

    for album in albums:
        name = (album.get("name") or "").strip().lower()
        if name and name not in skip_names:
            return str(album["id"])

    return str(albums[0]["id"])


def post_photos_to_page_album(
    album_name: str,
    message: str,
    *,
    photos: list[tuple[str | None, Path | None]],
) -> dict[str, str | list[str]]:
    """
    Fallback: add photos to an existing Page album.
    Photos may appear separately on the feed; prefer post_grouped_photos_to_feed().
    """
    del album_name  # album title comes from the existing Facebook album
    if not photos:
        raise FacebookServiceError("invalid_request", "At least one photo is required.")

    caption = (message or "").strip() or "Shared from ACCESS VisionCheck"
    album_id = resolve_page_album_id()
    photo_ids: list[str] = []
    for index, (image_url, local_path) in enumerate(photos):
        photo_ids.append(
            _upload_page_photo(
                album_id=album_id,
                image_url=image_url,
                local_path=local_path,
                no_story=index > 0,
                message=caption if index == 0 else None,
            )
        )
    return {"album_id": album_id, "photo_ids": photo_ids, "post_id": album_id}


MAX_FEED_PHOTOS_PER_POST = 10


def post_multi_photo_feed_post(message: str, *, photos: list[tuple[str | None, Path | None]]) -> str:
    """
    Publish up to 10 photos as one swipeable grid on the Page feed.
    Uploads unpublished photos, then attaches them in a single feed post.
    """
    if not photos:
        raise FacebookServiceError("invalid_request", "At least one photo is required.")
    if len(photos) > MAX_FEED_PHOTOS_PER_POST:
        raise FacebookServiceError(
            "invalid_request",
            f"Feed grid posts support at most {MAX_FEED_PHOTOS_PER_POST} images per post.",
        )

    text = (message or "").strip() or "Shared from ACCESS VisionCheck"
    media_fbids: list[str] = []
    for image_url, local_path in photos:
        media_fbids.append(
            _upload_page_photo(
                image_url=image_url,
                local_path=local_path,
                published=False,
            )
        )

    page_id = _page_id()
    token = _access_token()
    data: dict[str, str] = {"access_token": token, "message": text}
    for index, fbid in enumerate(media_fbids):
        data[f"attached_media[{index}]"] = json.dumps({"media_fbid": fbid})

    result = _request_json("POST", f"{GRAPH_BASE}/{page_id}/feed", data=data)
    post_id = result.get("id")
    if not post_id:
        raise FacebookServiceError("graph_api_error", "Facebook did not return a feed post id.")
    return str(post_id)


def post_grouped_photos_to_feed(
    message: str,
    *,
    photos: list[tuple[str | None, Path | None]],
) -> list[dict[str, str | int]]:
    """
    Publish photos as one or more swipeable feed grids (max 10 photos each).
    Returns [{post_id, count}, ...] in upload order.
    """
    if not photos:
        raise FacebookServiceError("invalid_request", "At least one photo is required.")

    chunks: list[list[tuple[str | None, Path | None]]] = []
    for start in range(0, len(photos), MAX_FEED_PHOTOS_PER_POST):
        chunks.append(photos[start : start + MAX_FEED_PHOTOS_PER_POST])

    posts: list[dict[str, str | int]] = []
    for index, chunk in enumerate(chunks):
        chunk_message = message if index == 0 else ""
        post_id = post_multi_photo_feed_post(chunk_message, photos=chunk)
        posts.append({"post_id": post_id, "count": len(chunk)})
    return posts
