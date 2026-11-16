"""Load environment files before Settings and SQLAlchemy engine initialization.

Uvicorn reload workers import ``main:app`` directly (not ``manage.py``). Set
``ACCESS_ENV_FILE`` in the parent process so workers reload the same file.
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

BACKEND_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ENV_FILE = BACKEND_ROOT / ".env"
ACCESS_ENV_FILE_VAR = "ACCESS_ENV_FILE"


def bootstrap_environment(explicit_env_file: Path | str | None = None) -> Path | None:
    """Apply dotenv files to ``os.environ``. Returns the active env file path."""
    if explicit_env_file is not None:
        path = Path(explicit_env_file).expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError(f"Env file not found: {path}")
        load_dotenv(path, override=True)
        os.environ[ACCESS_ENV_FILE_VAR] = str(path)
        return path

    marker = (os.environ.get(ACCESS_ENV_FILE_VAR) or "").strip()
    if marker:
        path = Path(marker)
        if path.is_file():
            load_dotenv(path, override=True)
            return path

    if DEFAULT_ENV_FILE.is_file():
        load_dotenv(DEFAULT_ENV_FILE, override=False)
    os.environ.pop(ACCESS_ENV_FILE_VAR, None)
    return None


def active_env_file_path() -> Path | None:
    marker = (os.environ.get(ACCESS_ENV_FILE_VAR) or "").strip()
    if not marker:
        return None
    path = Path(marker)
    return path if path.is_file() else None
