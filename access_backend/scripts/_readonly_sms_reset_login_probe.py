"""Readonly probe: verified phone formats + bcrypt round-trip (no account mutations)."""

from __future__ import annotations

from sqlalchemy import text

from app.core.security import hash_password, verify_password
from app.database import SessionLocal


def main() -> None:
    # Round-trip sanity (in-memory only)
    sample = "TempResetCheck9!"
    hashed = hash_password(sample)
    assert verify_password(sample, hashed), "bcrypt round-trip failed"
    assert not verify_password("wrong", hashed)
    print("bcrypt_round_trip=ok")
    print(f"hash_prefix={hashed[:4]} hash_len={len(hashed)}")

    db = SessionLocal()
    try:
        rows = db.execute(
            text(
                """
                SELECT id, email, contact_number,
                       (phone_verified_at IS NOT NULL) AS verified,
                       left(password, 4) AS pw_prefix,
                       length(password) AS pw_len,
                       status, is_active
                FROM users
                WHERE phone_verified_at IS NOT NULL
                ORDER BY id
                LIMIT 20
                """
            )
        ).mappings().all()
        print(f"verified_users={len(rows)}")
        for r in rows:
            print(dict(r))
    finally:
        db.close()


if __name__ == "__main__":
    main()
