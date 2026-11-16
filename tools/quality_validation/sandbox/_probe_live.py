"""Probe live sandbox /evaluate for diagnostics fields."""

from __future__ import annotations

import json
import urllib.request

import cv2
import numpy as np

img = np.full((96, 96, 3), 130, dtype=np.uint8)
ok, buf = cv2.imencode(".jpg", img)
assert ok
data = bytes(buf)

boundary = "----boundtest"
parts = [
    f"--{boundary}\r\n".encode(),
    b'Content-Disposition: form-data; name="file"; filename="t.jpg"\r\n',
    b"Content-Type: image/jpeg\r\n\r\n",
    data,
    b"\r\n",
    f"--{boundary}\r\n".encode(),
    b'Content-Disposition: form-data; name="noise_alts"\r\n\r\n',
    b"0\r\n",
    f"--{boundary}\r\n".encode(),
    b'Content-Disposition: form-data; name="ringing_alts"\r\n\r\n',
    b"0\r\n",
    f"--{boundary}--\r\n".encode(),
]
body = b"".join(parts)
req = urllib.request.Request(
    "http://127.0.0.1:8765/evaluate",
    data=body,
    headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    method="POST",
)
with urllib.request.urlopen(req, timeout=120) as resp:
    payload = json.loads(resp.read().decode())

print("ok", payload.get("ok"))
print("has_diagnostics_elapsed_ms", "diagnostics_elapsed_ms" in payload)
print("diagnostics_elapsed_ms", payload.get("diagnostics_elapsed_ms"))
print("include_diagnostics", payload.get("include_diagnostics"))
print(
    "explanations_len",
    None if payload.get("explanations") is None else len(payload["explanations"]),
)
print("diagnostics_available", (payload.get("diagnostics") or {}).get("available"))
print("diag_keys", [k for k in payload if "diag" in k or "expl" in k])
