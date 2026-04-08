"""
Auto-migration — runs on every server startup (idempotent).
Each step is wrapped in its own try/except so one failure
never crashes the whole application.
"""

import logging
from sqlalchemy import text
from app.db import engine
from app.models import Base

log = logging.getLogger(__name__)


# ── New columns to add if missing ────────────────────────────────────────────
_NEW_COLUMNS = [
    # (table, column, sql_type, default_sql)
    ("users",        "bio",            "TEXT",          None),
    ("users",        "open_to_work",   "BOOLEAN",       "TRUE"),
    ("users",        "cv_filename",    "VARCHAR(200)",   None),
    ("users",        "cv_uploaded_at", "TIMESTAMP",     None),
    ("users",        "avatar_url",     "VARCHAR(500)",   None),
    ("users",        "portfolio_url",  "VARCHAR(500)",   None),
    ("users",        "updated_at",     "TIMESTAMP",     None),
    ("companies",    "slug",           "VARCHAR(300)",   None),
    ("companies",    "industry",       "VARCHAR(100)",   None),
    ("companies",    "employee_count", "VARCHAR(50)",    None),
    ("companies",    "updated_at",     "TIMESTAMP",     None),
    ("internships",  "is_active",      "BOOLEAN",       "TRUE"),
    ("internships",  "deadline",       "TIMESTAMP",     None),
    ("internships",  "updated_at",     "TIMESTAMP",     None),
    ("applications", "updated_at",     "TIMESTAMP",     None),
    # universities — make login fields optional
    ("universities", "short_name",     "VARCHAR(50)",    None),
    ("universities", "country",        "VARCHAR(100)",   "'Казахстан'"),
    ("universities", "website",        "VARCHAR(300)",   None),
]

_SKILL_CATEGORIES = {
    "Flutter": "Mobile", "Dart": "Mobile", "Swift": "Mobile", "Kotlin": "Mobile",
    "React Native": "Mobile",
    "Python": "Backend", "Django": "Backend", "FastAPI": "Backend",
    "Flask": "Backend", "Node.js": "Backend", "Go": "Backend",
    "Java": "Backend", "C++": "Backend", "PostgreSQL": "Backend",
    "MySQL": "Backend", "MongoDB": "Backend", "Redis": "Backend",
    "Docker": "Backend", "Kubernetes": "Backend",
    "JavaScript": "Frontend", "TypeScript": "Frontend", "React": "Frontend",
    "Vue.js": "Frontend", "Angular": "Frontend", "HTML": "Frontend", "CSS": "Frontend",
    "Figma": "Design", "Adobe XD": "Design", "Photoshop": "Design",
    "Illustrator": "Design", "Sketch": "Design",
    "SQL": "Data", "Data Science": "Data", "Machine Learning": "Data",
    "TensorFlow": "Data", "PyTorch": "Data", "Pandas": "Data",
    "Excel": "Analytics", "Power BI": "Analytics", "Tableau": "Analytics",
    "Git": "Tools", "Linux": "Tools", "AWS": "Tools", "Azure": "Tools",
}


def run():
    """Entry point — call from main.py. Never raises."""
    log.info("=== Running DB migrations ===")
    try:
        Base.metadata.create_all(bind=engine)
        log.info("Tables OK")
    except Exception as e:
        log.error(f"create_all failed: {e}")
        return  # can't continue without tables

    try:
        with engine.connect() as conn:
            _add_columns(conn)
            _sync_skills(conn)
            conn.commit()
        log.info("=== Migrations done ===")
    except Exception as e:
        log.error(f"Migration error (non-fatal): {e}")


def _add_columns(conn):
    for table, column, col_type, default in _NEW_COLUMNS:
        try:
            default_clause = f" DEFAULT {default}" if default else ""
            conn.execute(text(
                f"ALTER TABLE {table} "
                f"ADD COLUMN IF NOT EXISTS {column} {col_type}{default_clause}"
            ))
        except Exception as e:
            log.warning(f"  skip {table}.{column}: {e}")


def _get_or_create_skill(conn, name: str) -> int | None:
    name = name.strip()
    if not name:
        return None
    try:
        row = conn.execute(
            text("SELECT id FROM skills WHERE LOWER(name) = LOWER(:n)"),
            {"n": name}
        ).fetchone()
        if row:
            return row[0]
        cat = _SKILL_CATEGORIES.get(name, "Другое")
        result = conn.execute(
            text(
                "INSERT INTO skills (name, category) VALUES (:n, :c) "
                "ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name RETURNING id"
            ),
            {"n": name, "c": cat},
        )
        return result.fetchone()[0]
    except Exception as e:
        log.warning(f"  skill '{name}' error: {e}")
        return None


def _sync_skills(conn):
    """Populate skills / user_skills / internship_skills from JSON columns."""
    try:
        # user skills
        rows = conn.execute(text(
            "SELECT id, skills FROM users "
            "WHERE skills IS NOT NULL AND skills::text NOT IN ('null', '[]')"
        )).fetchall()
        for user_id, skills_json in rows:
            for skill_name in (skills_json or []):
                sid = _get_or_create_skill(conn, str(skill_name))
                if sid:
                    conn.execute(text(
                        "INSERT INTO user_skills (user_id, skill_id) VALUES (:u, :s) "
                        "ON CONFLICT DO NOTHING"
                    ), {"u": user_id, "s": sid})
    except Exception as e:
        log.warning(f"  user_skills sync error: {e}")

    try:
        # internship skills
        rows = conn.execute(text(
            "SELECT id, skills FROM internships "
            "WHERE skills IS NOT NULL AND skills::text NOT IN ('null', '[]')"
        )).fetchall()
        for intern_id, skills_json in rows:
            for skill_name in (skills_json or []):
                sid = _get_or_create_skill(conn, str(skill_name))
                if sid:
                    conn.execute(text(
                        "INSERT INTO internship_skills (internship_id, skill_id) "
                        "VALUES (:i, :s) ON CONFLICT DO NOTHING"
                    ), {"i": intern_id, "s": sid})
    except Exception as e:
        log.warning(f"  internship_skills sync error: {e}")
