"""Create registration_phone_otps table for SMS OTP signup."""

from sqlalchemy import text

from app.database import engine


def main() -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS registration_phone_otps (
                    id SERIAL PRIMARY KEY,
                    phone_e164 VARCHAR(20) NOT NULL,
                    code_hash VARCHAR(128) NOT NULL,
                    expires_at TIMESTAMPTZ NOT NULL,
                    attempt_count INTEGER NOT NULL DEFAULT 0,
                    last_sent_at TIMESTAMPTZ NOT NULL,
                    verification_token_hash VARCHAR(128),
                    verification_token_expires_at TIMESTAMPTZ,
                    consumed_at TIMESTAMPTZ,
                    created_at TIMESTAMPTZ NOT NULL
                )
                """
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_registration_phone_otps_phone "
                "ON registration_phone_otps (phone_e164)"
            )
        )
    print("registration_phone_otps ready.")


if __name__ == "__main__":
    main()
