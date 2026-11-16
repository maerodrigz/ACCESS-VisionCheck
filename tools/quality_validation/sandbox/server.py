#!/usr/bin/env python3
"""Lightweight HTTP server for the Media Quality Evaluation Sandbox.

Uses only Python standard library (http.server, json, base64, email.parser)
plus the existing research venv (cv2, numpy, etc.).  No Flask, no FastAPI.

Endpoints:
  GET  /               → HTML page (index.html)
  GET  /health         → ok + EfficientNet availability (no inference)
  POST /evaluate       → JSON; body = multipart/form-data with:
                           file   : image bytes
                           noise_alts   : "1" to include Noise v3/v4
                           ringing_alts : "1" to include Ringing v3/v4

Start:
    python tools/quality_validation/sandbox/server.py
    python tools/quality_validation/sandbox/server.py --port 8765
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
import traceback
from email import message_from_bytes
from email.policy import EmailPolicy
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

SANDBOX = Path(__file__).resolve().parent
REPO = SANDBOX.parents[2]
BACKEND = REPO / "access_backend"
TOOLKIT = SANDBOX.parent
for _p in (str(REPO), str(BACKEND), str(TOOLKIT)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

TEMPLATE_PATH = SANDBOX / "index.html"
MAX_UPLOAD_BYTES = 20 * 1024 * 1024  # 20 MB
ALLOWED_EXT = frozenset({".jpg", ".jpeg", ".png", ".webp"})


class SandboxHandler(BaseHTTPRequestHandler):
    """Single-threaded request handler for the evaluation sandbox."""

    def log_message(self, fmt: str, *args: object) -> None:
        sys.stderr.write(f"[sandbox] {fmt % args}\n")

    def do_GET(self) -> None:
        path = self.path.split("?")[0]
        if path in ("/", "/index.html"):
            self._serve_index()
        elif path == "/health":
            self._handle_health()
        else:
            self._send_json({"error": "not found"}, status=404)

    def do_POST(self) -> None:
        path = self.path.split("?")[0]
        if path == "/evaluate":
            self._handle_evaluate()
        else:
            self._send_json({"error": "not found"}, status=404)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    # ── index page ────────────────────────────────────────────────────────────

    def _serve_index(self) -> None:
        if TEMPLATE_PATH.is_file():
            html = TEMPLATE_PATH.read_bytes()
        else:
            html = _fallback_html()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(html)))
        self.end_headers()
        self.wfile.write(html)

    def _handle_health(self) -> None:
        payload: dict = {"ok": True, "sandbox": True, "production_api": False}
        try:
            from tools.quality_validation.sandbox.evaluator import enet_status
            payload["efficientnet"] = enet_status()
        except Exception as exc:  # noqa: BLE001
            payload["efficientnet"] = {"engine_available": False, "error": str(exc)}
        self._send_json(payload)

    # ── evaluate ──────────────────────────────────────────────────────────────

    def _handle_evaluate(self) -> None:
        ct = self.headers.get("Content-Type", "")
        if "multipart/form-data" not in ct:
            self._send_json({"ok": False, "error": "Expected multipart/form-data"}, status=400)
            return

        length = int(self.headers.get("Content-Length", 0))
        if length > MAX_UPLOAD_BYTES:
            self._send_json(
                {"ok": False, "error": f"Upload too large (max {MAX_UPLOAD_BYTES // 1024} KB)"},
                status=413,
            )
            return

        raw_body = self.rfile.read(length)
        form = _parse_multipart(ct, raw_body)

        file_item = form.get("file")
        if file_item is None:
            self._send_json({"ok": False, "error": "No file field in request"}, status=400)
            return

        img_bytes: bytes = file_item["data"]
        fname: str = file_item.get("filename", "upload.jpg")

        if not img_bytes:
            self._send_json({"ok": False, "error": "Empty file"}, status=400)
            return

        ext = Path(fname).suffix.lower()
        if ext not in ALLOWED_EXT:
            self._send_json(
                {"ok": False, "error": f"Unsupported file type {ext!r}. Use JPEG or PNG."},
                status=400,
            )
            return

        if not _is_image_magic(img_bytes):
            self._send_json(
                {"ok": False, "error": "File does not look like a JPEG or PNG."},
                status=400,
            )
            return

        noise_alts = (
            form.get("noise_alts", {}).get("data", b"").decode("utf-8", errors="ignore") == "1"
        )
        ringing_alts = (
            form.get("ringing_alts", {}).get("data", b"").decode("utf-8", errors="ignore") == "1"
        )

        try:
            # Reload sandbox modules each request so a long-lived server picks up
            # evaluator/diagnostics edits without a manual restart (HTML already
            # reloads from disk on every GET).
            import importlib

            import tools.quality_validation.sandbox.diagnostics as diag_mod
            import tools.quality_validation.sandbox.evaluator as eval_mod

            importlib.reload(diag_mod)
            importlib.reload(eval_mod)
            result = eval_mod.evaluate(
                img_bytes,
                include_noise_alternates=noise_alts,
                include_ringing_alternates=ringing_alts,
                include_diagnostics=True,
            )
        except Exception as exc:  # noqa: BLE001
            tb = traceback.format_exc()
            self._send_json({"ok": False, "error": str(exc), "traceback": tb}, status=500)
            return

        # Guarantee UI timing fields even if an older evaluate() shape is loaded.
        if "diagnostics_elapsed_ms" not in result:
            result["diagnostics_elapsed_ms"] = None
        if "explanations" not in result:
            result["explanations"] = None
        if "diagnostics" not in result:
            result["diagnostics"] = None
        if result.get("include_diagnostics") is None:
            result["include_diagnostics"] = True

        result["thumbnail_datauri"] = _make_thumbnail(img_bytes, max_px=320)
        self._send_json(result)

    def _send_json(self, payload: dict, *, status: int = 200) -> None:
        body = json.dumps(payload, indent=2, default=str).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)


# ── multipart parser (stdlib, Python 3.13-compatible — no cgi) ────────────────

def _parse_multipart(content_type: str, body: bytes) -> dict[str, dict]:
    """Parse multipart/form-data using email.parser (no deprecated cgi module)."""
    if not content_type or "multipart/form-data" not in content_type.lower():
        return {}
    if b"boundary=" not in content_type.encode("ascii", "ignore") and "boundary=" not in content_type:
        return {}

    header = (
        b"MIME-Version: 1.0\r\n"
        + b"Content-Type: "
        + content_type.encode("ascii", errors="ignore")
        + b"\r\n\r\n"
    )
    try:
        msg = message_from_bytes(header + body, policy=EmailPolicy(utf8=True))
    except Exception:
        return {}

    result: dict[str, dict] = {}
    if not msg.is_multipart():
        return result

    for part in msg.iter_parts():
        name = part.get_param("name", header="content-disposition")
        if not name:
            continue
        filename = part.get_filename() or ""
        data = part.get_payload(decode=True)
        if data is None:
            payload = part.get_payload()
            if isinstance(payload, str):
                data = payload.encode("utf-8")
            elif isinstance(payload, bytes):
                data = payload
            else:
                data = b""
        result[str(name)] = {"data": data, "filename": filename}
    return result


def _is_image_magic(data: bytes) -> bool:
    if len(data) >= 3 and data[:3] == b"\xff\xd8\xff":
        return True
    if len(data) >= 8 and data[:8] == b"\x89PNG\r\n\x1a\n":
        return True
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return True
    return False


def _make_thumbnail(image_bytes: bytes, max_px: int = 320) -> str | None:
    try:
        import numpy as np
        import cv2
        arr = np.frombuffer(image_bytes, dtype=np.uint8)
        bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if bgr is None:
            return None
        h, w = bgr.shape[:2]
        scale = max_px / max(h, w)
        if scale < 1.0:
            nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
            bgr = cv2.resize(bgr, (nw, nh), interpolation=cv2.INTER_AREA)
        ok, buf = cv2.imencode(".jpg", bgr, [cv2.IMWRITE_JPEG_QUALITY, 80])
        if not ok:
            return None
        b64 = base64.b64encode(bytes(buf)).decode("ascii")
        return f"data:image/jpeg;base64,{b64}"
    except Exception:  # noqa: BLE001
        return None


def _fallback_html() -> bytes:
    return b"<html><body><p>index.html not found. Run from sandbox/ directory.</p></body></html>"


def main() -> None:
    ap = argparse.ArgumentParser(description="ACCESS VisionCheck Quality Sandbox")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8765)
    args = ap.parse_args()
    addr = (args.host, args.port)
    httpd = HTTPServer(addr, SandboxHandler)
    print(f"[sandbox] Listening on http://{args.host}:{args.port}/", flush=True)
    print("[sandbox] Press Ctrl+C to stop.", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[sandbox] Stopped.", flush=True)


if __name__ == "__main__":
    main()
