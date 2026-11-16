"""
Load ACCESS sample rows into PostgreSQL (not hardcoded in the Flutter app).

Usage (from access_backend/):
  .\\venv\\Scripts\\Activate.ps1
  python seed_sample_data.py

Requires tables and default users from create_tables.py first.
Refused when APP_ENV is production.
"""

from dotenv import load_dotenv

load_dotenv()

from app.config import settings
from app.database import SessionLocal
from app.db_init_safety import ProductionDbInitError, assert_sample_seed_allowed
from app.seed.sample_data import seed_sample_dataset


def main() -> None:
    try:
        assert_sample_seed_allowed(is_production=settings.is_production)
    except ProductionDbInitError as exc:
        print(f"ERROR: {exc}")
        raise SystemExit(1) from exc

    print("ACCESS — seeding PostgreSQL sample data...")
    db = SessionLocal()
    try:
        seed_sample_dataset(db)
        print()
        print("Done. Refresh the admin dashboard and mobile app to see live API data.")
        print("Login: admin@access.edu / admin123")
    finally:
        db.close()


if __name__ == "__main__":
    main()
