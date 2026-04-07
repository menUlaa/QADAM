"""
Usage: python make_admin.py <email>
Makes an existing user an admin.
"""
import sys
from app.db import SessionLocal
from app.models import User

def make_admin(email: str):
    db = SessionLocal()
    user = db.query(User).filter(User.email == email).first()
    if not user:
        print(f"User '{email}' not found. Register first via the mobile app.")
        return
    user.is_admin = True
    db.commit()
    print(f"✓ '{user.name}' ({email}) is now an admin.")
    db.close()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python make_admin.py <email>")
        sys.exit(1)
    make_admin(sys.argv[1])
