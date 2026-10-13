"""Branded HTML wrapper for transactional email."""

from __future__ import annotations

import html
from pathlib import Path

from app.config import settings

BACKEND_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_LOGO_PATH = BACKEND_ROOT.parent / "assets" / "images" / "access_logo.png"
LOGO_CID = "access_logo"


def product_name() -> str:
    return (settings.email_from_name or "ACCESS VisionCheck").strip() or "ACCESS VisionCheck"


def logo_path() -> Path | None:
    raw = (getattr(settings, "email_logo_path", None) or "").strip()
    path = Path(raw) if raw else DEFAULT_LOGO_PATH
    if path.is_file():
        return path
    fallback = BACKEND_ROOT.parent / "admin-web" / "public" / "access_logo.png"
    return fallback if fallback.is_file() else None


def branded_html(inner_body_html: str) -> str:
    """Wrap fragment in ACCESS header/footer. Use cid:access_logo when logo is embedded."""
    name = html.escape(product_name())
    body = inner_body_html.strip()
    path = logo_path()
    if path:
        logo_block = (
            f'<img src="cid:{LOGO_CID}" alt="{name}" '
            'width="56" height="56" style="border-radius:50%;display:block;margin:0 auto 12px;" />'
        )
    else:
        logo_block = (
            f'<div style="font-size:22px;font-weight:800;color:#0052D4;text-align:center;margin-bottom:12px;">'
            f"{name}</div>"
        )
    return f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8" /></head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:24px 16px;">
    <tr><td align="center">
      <table width="100%" style="max-width:520px;background:#ffffff;border-radius:16px;border:1px solid #e2e8f0;padding:28px 24px;">
        <tr><td>
          {logo_block}
          <div style="text-align:center;font-size:13px;font-weight:700;color:#64748b;letter-spacing:0.04em;margin-bottom:20px;">
            {name}
          </div>
          <div style="color:#1e293b;font-size:15px;line-height:1.55;">
            {body}
          </div>
          <hr style="border:none;border-top:1px solid #e2e8f0;margin:24px 0 16px;" />
          <p style="margin:0;font-size:12px;color:#64748b;text-align:center;line-height:1.45;">
            USTP Oroquieta Campus<br />
            Capture. Deliver. Elevate
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>"""


def esc(text: str) -> str:
    return html.escape((text or "").strip())
