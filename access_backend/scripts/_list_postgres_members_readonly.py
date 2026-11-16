from sqlalchemy import create_engine, text
from app.config import settings

e = create_engine(settings.database_url)
with e.connect() as c:
    for row in c.execute(
        text(
            "SELECT u.id, u.email, u.status FROM users u "
            "JOIN roles r ON r.id = u.role_id WHERE r.role_name = 'Member'"
        )
    ):
        print(row[0], row[1], row[2])
e.dispose()
