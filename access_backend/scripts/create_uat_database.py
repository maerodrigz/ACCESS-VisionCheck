"""Create PostgreSQL database access_uat if it does not exist."""

from __future__ import annotations

import os
import sys

import psycopg
from dotenv import load_dotenv
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
load_dotenv(BACKEND / os.environ.get("ACCESS_ENV_FILE", ".env.uat.local"))

DB_NAME = "access_uat"


def main() -> None:
    url = os.environ.get("DATABASE_URL", "")
    if DB_NAME not in url:
        print(f"ERROR: DATABASE_URL must target {DB_NAME}")
        sys.exit(1)
    # Connect to maintenance DB
    plain = url.replace("postgresql+psycopg://", "postgresql://", 1)
    admin_url = plain.rsplit("/", 1)[0] + "/postgres"
    with psycopg.connect(admin_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (DB_NAME,))
            if cur.fetchone():
                print(f"Database {DB_NAME} already exists.")
                return
            cur.execute(f'CREATE DATABASE "{DB_NAME}"')
            print(f"Created database {DB_NAME}.")


if __name__ == "__main__":
    main()
