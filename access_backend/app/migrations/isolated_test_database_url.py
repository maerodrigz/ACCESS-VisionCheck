"""Build PostgreSQL URL for access_waverep_test without mangling credentials."""

from __future__ import annotations

from urllib.parse import quote_plus

from app.config import settings

ISOLATED_TEST_DB = "access_waverep_test"


def isolated_test_database_url() -> str:
    user = quote_plus(settings.db_username)
    password = quote_plus(settings.db_password)
    host = settings.db_host
    port = settings.db_port
    return f"postgresql+psycopg://{user}:{password}@{host}:{port}/{ISOLATED_TEST_DB}"
