"""Best-effort LAN IPv4 for dev runserver hints (default-route interface)."""

from __future__ import annotations

import socket


def detect_default_route_ipv4() -> str | None:
    """
    Return the IPv4 the OS would use for outbound traffic (hotspot/Wi-Fi LAN IP).
    Does not open a meaningful connection; no data is sent.
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("8.8.8.8", 80))
            addr = sock.getsockname()[0]
            if addr and not addr.startswith("127."):
                return addr
    except OSError:
        return None
    return None
