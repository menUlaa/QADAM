"""
Auto-migration script — runs on every server startup.
Safe to run multiple times (idempotent).

What it does:
  1. Creates all new tables (CREATE TABLE IF NOT EXISTS via SQLAlchemy)
  2. Adds new columns to existing tables (ALTER TABLE … ADD COLUMN IF NOT EXISTS)
  3. Populates the skills master table from existing JSON data
  4. Populates user_skills from users.skills JSON
  5. Populates internship_skills from internships.skills JSON
  6. Seeds universities reference table if empty
"""

import logging
from sqlalchemy import text
from app.db import engine, SessionLocal
from app.models import Base

log = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# New columns that didn't exist in the old schema
# ─────────────────────────────────────────────────────────────────────────────
_NEW_COLUMNS = [
    # (table, column, sql_type, default)
    ("users",       "bio",           "TEXT",         None),
    ("users",       "open_to_work",  "BOOLEAN",      "TRUE"),
    ("users",       "cv_filename",   "VARCHAR(200)",  None),
    ("users",       "cv_uploaded_at","TIMESTAMP",    None),
    ("users",       "avatar_url",    "VARCHAR(500)",  None),
    ("users",       "portfolio_url", "VARCHAR(500)",  None),
    ("users",       "updated_at",    "TIMESTAMP",    None),
    ("companies",   "slug",          "VARCHAR(300)",  None),
    ("companies",   "industry",      "VARCHAR(100)",  None),
    ("companies",   "employee_count","VARCHAR(50)",   None),
    ("companies",   "updated_at",    "TIMESTAMP",    None),
    ("internships", "is_active",     "BOOLEAN",      "TRUE"),
    ("internships", "deadline",      "TIMESTAMP",    None),
    ("internships", "updated_at",    "TIMESTAMP",    None),
    ("applications","updated_at",    "TIMESTAMP",    None),
]

# ─────────────────────────────────────────────────────────────────────────────
# KZ university seed data
# ─────────────────────────────────────────────────────────────────────────────
_UNIVERSITIES = [
    ("AITU — Astana IT University",                          "AITU",   "Астана"),
    ("НУ — Назарбаев Университет",                           "НУ",     "Астана"),
    ("ЕНУ — Евразийский национальный университет",           "ЕНУ",    "Астана"),
    ("КазНУ — Казахский национальный университет",           "КазНУ",  "Алматы"),
    ("КазНТУ — Казахский национальный технический университет","КазНТУ","Алматы"),
    ("МУИТ — Международный университет информационных технологий","МУИТ","Алматы"),
    ("КБТУ — Казахстанско-Британский технический университет","КБТУ",  "Алматы"),
    ("Университет КИМЭП",                                    "КИМЭП",  "Алматы"),
    ("SDU — Suleyman Demirel University",                    "SDU",    "Каскелен"),
    ("КазГЮУ — Казахский гуманитарно-юридический университет","КазГЮУ","Астана"),
    ("КазЭУ — Казахский экономический университет",          "КазЭУ",  "Алматы"),
    ("АТУ — Алматы технологический университет",             "АТУ",    "Алматы"),
    ("ВКТУ — Восточно-Казахстанский технический университет","ВКТУ",   "Усть-Каменогорск"),
    ("КарТУ — Карагандинский технический университет",       "КарТУ",  "Караганда"),
    ("Университет Нархоз",                                   "Нархоз", "Алматы"),
    ("АДУ — Алматы Дейта Университет",                       "АДУ",    "Алматы"),
    ("Другой университет",                                   None,     None),
]

# ─────────────────────────────────────────────────────────────────────────────
# Default skill categories
# ─────────────────────────────────────────────────────────────────────────────
_SKILL_CATEGORIES = {
    "Flutter": "Mobile", "Dart": "Mobile", "Swift": "Mobile", "Kotlin": "Mobile",
    "React Native": "Mobile",
    "Python": "Backend", "Django": "Backend", "FastAPI": "Backend", "Flask": "Backend",
    "Node.js": "Backend", "Go": "Backend", "Java": "Backend", "C++": "Backend",
    "Spring Boot": "Backend", "PostgreSQL": "Backend", "MySQL": "Backend",
    "MongoDB": "Backend", "Redis": "Backend", "Docker": "Backend", "Kubernetes": "Backend",
    "JavaScript": "Frontend", "TypeScript": "Frontend", "React": "Frontend",
    "Vue.js": "Frontend", "Angular": "Frontend", "HTML": "Frontend", "CSS": "Frontend",
    "Figma": "Design", "Adobe XD": "Design", "Photoshop": "Design",
    "Illustrator": "Design", "Sketch": "Design",
    "SQL": "Data", "Data Science": "Data", "Machine Learning": "Data",
    "TensorFlow": "Data", "PyTorch": "Data", "Pandas": "Data", "NumPy": "Data",
    "Excel": "Analytics", "Power BI": "Analytics", "Tableau": "Analytics",
    "Git": "Tools", "Linux": "Tools", "AWS": "Tools", "Azure": "Tools",
}


def run():
    """Entry point — call from main.py at startup."""
    log.info("Running database migrations…")

    # 1. Create all tables declared in models.py
    Base.metadata.create_all(bind=engine)
    log.info("Tables created / verified.")

    with engine.connect() as conn:
        # 2. Add missing columns to existing tables
        _add_missing_columns(conn)

        # 3. Seed universities
        _seed_universities(conn)

        # 4. Sync skills from existing JSON data
        _sync_skills(conn)

        conn.commit()

    log.info("Migrations complete.")


def _add_missing_columns(conn):
    for table, column, col_type, default in _NEW_COLUMNS:
        default_clause = f" DEFAULT {default}" if default else ""
        try:
            conn.execute(text(
                f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS "
                f"{column} {col_type}{default_clause}"
            ))
        except Exception as e:
            log.warning(f"Could not add {table}.{column}: {e}")


def _seed_universities(conn):
    count = conn.execute(text("SELECT COUNT(*) FROM universities")).scalar()
    if count > 0:
        return
    log.info("Seeding universities…")
    for name, short_name, city in _UNIVERSITIES:
        try:
            conn.execute(text(
                "INSERT INTO universities (name, short_name, city, country) "
                "VALUES (:name, :short, :city, 'Казахстан') "
                "ON CONFLICT (name) DO NOTHING"
            ), {"name": name, "short": short_name, "city": city or ""})
        except Exception as e:
            log.warning(f"University seed error: {e}")
    log.info("Universities seeded.")


def _get_or_create_skill(conn, skill_name: str) -> int:
    """Returns skill.id, creating the record if needed."""
    skill_name = skill_name.strip()
    if not skill_name:
        return None
    row = conn.execute(
        text("SELECT id FROM skills WHERE LOWER(name) = LOWER(:n)"),
        {"n": skill_name}
    ).fetchone()
    if row:
        return row[0]
    category = _SKILL_CATEGORIES.get(skill_name, "Другое")
    result = conn.execute(
        text("INSERT INTO skills (name, category) VALUES (:n, :c) "
             "ON CONFLICT (name) DO UPDATE SET name=EXCLUDED.name RETURNING id"),
        {"n": skill_name, "c": category}
    )
    return result.fetchone()[0]


def _sync_skills(conn):
    """Migrate JSON skill arrays → normalised skill tables."""

    # ── User skills ──────────────────────────────────────────────────────────
    users = conn.execute(text(
        "SELECT id, skills FROM users WHERE skills IS NOT NULL AND skills != '[]'::jsonb"
    )).fetchall()

    for user_id, skills_json in users:
        if not skills_json:
            continue
        skill_list = skills_json if isinstance(skills_json, list) else []
        for skill_name in skill_list:
            skill_id = _get_or_create_skill(conn, str(skill_name))
            if skill_id:
                conn.execute(text(
                    "INSERT INTO user_skills (user_id, skill_id) VALUES (:u, :s) "
                    "ON CONFLICT DO NOTHING"
                ), {"u": user_id, "s": skill_id})

    # ── Internship skills ────────────────────────────────────────────────────
    internships = conn.execute(text(
        "SELECT id, skills FROM internships WHERE skills IS NOT NULL AND skills != '[]'::jsonb"
    )).fetchall()

    for intern_id, skills_json in internships:
        if not skills_json:
            continue
        skill_list = skills_json if isinstance(skills_json, list) else []
        for skill_name in skill_list:
            skill_id = _get_or_create_skill(conn, str(skill_name))
            if skill_id:
                conn.execute(text(
                    "INSERT INTO internship_skills (internship_id, skill_id) VALUES (:i, :s) "
                    "ON CONFLICT DO NOTHING"
                ), {"i": intern_id, "s": skill_id})

    log.info("Skills synced.")
