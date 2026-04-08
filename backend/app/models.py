"""
Database schema for QADAM Internship Platform
=============================================

Tables:
  Core:         users, companies, universities
  Link:         student_universities
  Internships:  internships, skills, user_skills, internship_skills
  Activity:     applications, saved_internships, internship_reports
  Social:       company_reviews
  Engagement:   notifications
  AI:           ai_conversations, ai_messages
"""

from sqlalchemy import (
    Column, Integer, String, Boolean, Text, JSON,
    ForeignKey, DateTime, Float, UniqueConstraint, Index,
)
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db import Base


# ─────────────────────────────────────────────────────────────────────────────
# USERS
# ─────────────────────────────────────────────────────────────────────────────
class User(Base):
    __tablename__ = "users"

    id            = Column(Integer, primary_key=True, index=True)
    email         = Column(String(200), unique=True, nullable=False, index=True)
    first_name    = Column(String(100), nullable=False, default="")
    last_name     = Column(String(100), nullable=False, default="")
    name          = Column(String(200), nullable=False, default="")   # denormalised full name
    hashed_password = Column(String(200), nullable=False)

    # Status flags
    is_admin      = Column(Boolean, default=False, nullable=False)
    is_verified   = Column(Boolean, default=False, nullable=False)
    is_graduate   = Column(Boolean, default=False, nullable=False)
    open_to_work  = Column(Boolean, default=True,  nullable=False)

    # Verification
    verification_token = Column(String(200), nullable=True)

    # Profile
    bio           = Column(Text,         nullable=True)
    portfolio_url = Column(String(500),  nullable=True)
    avatar_url    = Column(String(500),  nullable=True)

    # CV
    cv_url        = Column(String(500),  nullable=True)
    cv_filename   = Column(String(200),  nullable=True)
    cv_uploaded_at = Column(DateTime,    nullable=True)

    # Legacy JSON skills kept for backward-compat; normalised in user_skills
    skills        = Column(JSON, default=list)

    # Timestamps
    created_at    = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at    = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    applications     = relationship("Application",     back_populates="user")
    saved            = relationship("SavedInternship", back_populates="user")
    notifications    = relationship("Notification",    back_populates="user")
    university_link  = relationship("StudentUniversity", back_populates="user", uselist=False)
    skill_links      = relationship("UserSkill",       back_populates="user")
    conversations    = relationship("AiConversation",  back_populates="user")
    reviews          = relationship("CompanyReview",   back_populates="user")


# ─────────────────────────────────────────────────────────────────────────────
# COMPANIES
# ─────────────────────────────────────────────────────────────────────────────
class Company(Base):
    __tablename__ = "companies"

    id              = Column(Integer, primary_key=True, index=True)
    name            = Column(String(300), nullable=False)
    slug            = Column(String(300), nullable=True,  index=True)   # url-friendly name
    email           = Column(String(200), unique=True, nullable=False, index=True)
    hashed_password = Column(String(200), nullable=False)
    description     = Column(Text,        default="")
    city            = Column(String(100), default="",     index=True)
    website         = Column(String(300), default="")
    logo_url        = Column(String(500), nullable=True)
    industry        = Column(String(100), nullable=True)   # IT, Finance, etc.
    employee_count  = Column(String(50),  nullable=True)   # "1-10", "11-50", "51-200"…
    is_verified     = Column(Boolean, default=True)
    created_at      = Column(DateTime, default=datetime.utcnow)
    updated_at      = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    internships = relationship("Internship",    back_populates="company_obj")
    reviews     = relationship("CompanyReview", back_populates="company")


# ─────────────────────────────────────────────────────────────────────────────
# UNIVERSITIES  (reference data — does NOT need login)
# ─────────────────────────────────────────────────────────────────────────────
class University(Base):
    __tablename__ = "universities"

    id              = Column(Integer, primary_key=True, index=True)
    name            = Column(String(300), nullable=False, unique=True)
    short_name      = Column(String(50),  nullable=True)
    city            = Column(String(100), default="")
    country         = Column(String(100), default="Казахстан")
    website         = Column(String(300), nullable=True)
    # Login fields (kept for university portal login)
    email           = Column(String(200), unique=True, nullable=True, index=True)
    hashed_password = Column(String(200), nullable=True)
    created_at      = Column(DateTime, default=datetime.utcnow)

    students   = relationship("StudentUniversity", back_populates="university")


class StudentUniversity(Base):
    """M:M link between User and University with extra attrs."""
    __tablename__ = "student_universities"
    __table_args__ = (
        UniqueConstraint("user_id", "university_id", name="uq_student_university"),
    )

    id                = Column(Integer, primary_key=True, index=True)
    user_id           = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    university_id     = Column(Integer, ForeignKey("universities.id"), nullable=False)
    specialty         = Column(String(200), default="")
    study_year        = Column(Integer, nullable=True)   # 1–5
    student_id_number = Column(String(100), default="")
    is_current        = Column(Boolean, default=True)
    joined_at         = Column(DateTime, default=datetime.utcnow)

    user       = relationship("User",       back_populates="university_link")
    university = relationship("University", back_populates="students")


# ─────────────────────────────────────────────────────────────────────────────
# SKILLS  (normalised — replaces JSON arrays)
# ─────────────────────────────────────────────────────────────────────────────
class Skill(Base):
    """Master list of skills (Flutter, Python, Figma, …)."""
    __tablename__ = "skills"

    id       = Column(Integer, primary_key=True, index=True)
    name     = Column(String(100), unique=True, nullable=False, index=True)
    category = Column(String(100), default="Другое")   # IT, Design, Finance…

    user_links       = relationship("UserSkill",        back_populates="skill")
    internship_links = relationship("InternshipSkill",  back_populates="skill")


class UserSkill(Base):
    """User ↔ Skill (M:M)."""
    __tablename__ = "user_skills"
    __table_args__ = (
        UniqueConstraint("user_id", "skill_id", name="uq_user_skill"),
    )

    id       = Column(Integer, primary_key=True, index=True)
    user_id  = Column(Integer, ForeignKey("users.id",  ondelete="CASCADE"), nullable=False, index=True)
    skill_id = Column(Integer, ForeignKey("skills.id", ondelete="CASCADE"), nullable=False, index=True)

    user  = relationship("User",  back_populates="skill_links")
    skill = relationship("Skill", back_populates="user_links")


class InternshipSkill(Base):
    """Internship ↔ Skill (M:M)."""
    __tablename__ = "internship_skills"
    __table_args__ = (
        UniqueConstraint("internship_id", "skill_id", name="uq_internship_skill"),
    )

    id             = Column(Integer, primary_key=True, index=True)
    internship_id  = Column(Integer, ForeignKey("internships.id", ondelete="CASCADE"), nullable=False, index=True)
    skill_id       = Column(Integer, ForeignKey("skills.id",      ondelete="CASCADE"), nullable=False, index=True)

    internship = relationship("Internship", back_populates="skill_links")
    skill      = relationship("Skill",      back_populates="internship_links")


# ─────────────────────────────────────────────────────────────────────────────
# INTERNSHIPS
# ─────────────────────────────────────────────────────────────────────────────
class Internship(Base):
    __tablename__ = "internships"
    __table_args__ = (
        Index("ix_internships_category", "category"),
        Index("ix_internships_city",     "city"),
        Index("ix_internships_format",   "format"),
        Index("ix_internships_active",   "is_active"),
    )

    id           = Column(Integer, primary_key=True, index=True)
    title        = Column(String(200), nullable=False)

    # Company: company_id is the correct FK; `company` string kept for legacy
    company_id   = Column(Integer, ForeignKey("companies.id"), nullable=True, index=True)
    company      = Column(String(200), nullable=False, default="")   # denormalised, legacy

    # Location & format
    city         = Column(String(100), nullable=False, default="")
    format       = Column(String(50),  nullable=False, default="Hybrid")   # Remote|Office|Hybrid

    # Compensation
    paid         = Column(Boolean, nullable=False, default=True)
    salary_kzt   = Column(Integer, nullable=True)

    # Details
    duration     = Column(String(100), nullable=False, default="")
    description  = Column(Text,        nullable=False, default="")
    category     = Column(String(100), nullable=False, default="IT")
    contact_email = Column(String(200), nullable=False, default="")

    # Ordered lists — stay as JSON (queried as whole, not filtered)
    responsibilities = Column(JSON, nullable=False, default=list)
    requirements     = Column(JSON, nullable=False, default=list)
    tags             = Column(JSON, nullable=False, default=list)

    # Legacy skills JSON — still populated for backward-compat
    skills       = Column(JSON, nullable=False, default=list)

    # Lifecycle
    is_active    = Column(Boolean, default=True,  nullable=False, index=True)
    deadline     = Column(DateTime, nullable=True)
    created_at   = Column(DateTime, default=datetime.utcnow)
    updated_at   = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    company_obj  = relationship("Company",          back_populates="internships")
    applications = relationship("Application",      back_populates="internship")
    saves        = relationship("SavedInternship",  back_populates="internship")
    skill_links  = relationship("InternshipSkill",  back_populates="internship")


# ─────────────────────────────────────────────────────────────────────────────
# APPLICATIONS
# ─────────────────────────────────────────────────────────────────────────────
class Application(Base):
    __tablename__ = "applications"
    __table_args__ = (
        UniqueConstraint("user_id", "internship_id", name="uq_application"),
    )

    id             = Column(Integer, primary_key=True, index=True)
    user_id        = Column(Integer, ForeignKey("users.id",        ondelete="CASCADE"), nullable=False, index=True)
    internship_id  = Column(Integer, ForeignKey("internships.id",  ondelete="CASCADE"), nullable=False, index=True)
    message        = Column(Text, nullable=True)

    # Status: pending | accepted | rejected | completed
    status         = Column(String(50), default="pending", nullable=False, index=True)

    created_at     = Column(DateTime, default=datetime.utcnow)
    updated_at     = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user       = relationship("User",              back_populates="applications")
    internship = relationship("Internship",        back_populates="applications")
    report     = relationship("InternshipReport",  back_populates="application", uselist=False)


# ─────────────────────────────────────────────────────────────────────────────
# SAVED INTERNSHIPS  (bookmarks / favourites)
# ─────────────────────────────────────────────────────────────────────────────
class SavedInternship(Base):
    __tablename__ = "saved_internships"
    __table_args__ = (
        UniqueConstraint("user_id", "internship_id", name="uq_saved"),
    )

    id             = Column(Integer, primary_key=True, index=True)
    user_id        = Column(Integer, ForeignKey("users.id",       ondelete="CASCADE"), nullable=False, index=True)
    internship_id  = Column(Integer, ForeignKey("internships.id", ondelete="CASCADE"), nullable=False, index=True)
    created_at     = Column(DateTime, default=datetime.utcnow)

    user       = relationship("User",       back_populates="saved")
    internship = relationship("Internship", back_populates="saves")


# ─────────────────────────────────────────────────────────────────────────────
# INTERNSHIP REPORTS
# ─────────────────────────────────────────────────────────────────────────────
class InternshipReport(Base):
    __tablename__ = "internship_reports"

    id               = Column(Integer, primary_key=True, index=True)
    application_id   = Column(Integer, ForeignKey("applications.id", ondelete="CASCADE"),
                               nullable=False, unique=True)
    hours_completed  = Column(Integer, default=0)
    tasks_description = Column(Text, default="")
    skills_gained    = Column(JSON, default=list)
    company_rating   = Column(Float, nullable=True)   # 1–5 given by student
    company_feedback = Column(Text, nullable=True)    # company's written feedback
    created_at       = Column(DateTime, default=datetime.utcnow)

    application = relationship("Application", back_populates="report")


# ─────────────────────────────────────────────────────────────────────────────
# COMPANY REVIEWS
# ─────────────────────────────────────────────────────────────────────────────
class CompanyReview(Base):
    """Student review of a company after completing an internship."""
    __tablename__ = "company_reviews"
    __table_args__ = (
        UniqueConstraint("user_id", "company_id", name="uq_review"),
    )

    id             = Column(Integer, primary_key=True, index=True)
    user_id        = Column(Integer, ForeignKey("users.id",      ondelete="CASCADE"), nullable=False)
    company_id     = Column(Integer, ForeignKey("companies.id",  ondelete="CASCADE"), nullable=False, index=True)
    application_id = Column(Integer, ForeignKey("applications.id"), nullable=True)
    rating         = Column(Float, nullable=False)          # 1.0–5.0
    review_text    = Column(Text, nullable=True)
    is_anonymous   = Column(Boolean, default=False)
    created_at     = Column(DateTime, default=datetime.utcnow)

    user    = relationship("User",    back_populates="reviews")
    company = relationship("Company", back_populates="reviews")


# ─────────────────────────────────────────────────────────────────────────────
# NOTIFICATIONS
# ─────────────────────────────────────────────────────────────────────────────
class Notification(Base):
    __tablename__ = "notifications"
    __table_args__ = (
        Index("ix_notifications_user_unread", "user_id", "is_read"),
    )

    id          = Column(Integer, primary_key=True, index=True)
    user_id     = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # Type: application_status | new_internship | system | ai_recommendation
    type        = Column(String(50), nullable=False, default="system")
    title       = Column(String(200), nullable=False)
    body        = Column(Text, nullable=True)
    is_read     = Column(Boolean, default=False, nullable=False)

    # Optional FK to related entity
    related_internship_id  = Column(Integer, ForeignKey("internships.id",  ondelete="SET NULL"), nullable=True)
    related_application_id = Column(Integer, ForeignKey("applications.id", ondelete="SET NULL"), nullable=True)

    created_at  = Column(DateTime, default=datetime.utcnow, index=True)

    user = relationship("User", back_populates="notifications")


# ─────────────────────────────────────────────────────────────────────────────
# AI CHAT
# ─────────────────────────────────────────────────────────────────────────────
class AiConversation(Base):
    """One conversation thread per user (can have many)."""
    __tablename__ = "ai_conversations"

    id         = Column(Integer, primary_key=True, index=True)
    user_id    = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title      = Column(String(200), default="Новый чат")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user     = relationship("User",      back_populates="conversations")
    messages = relationship("AiMessage", back_populates="conversation",
                            order_by="AiMessage.created_at", cascade="all, delete-orphan")


class AiMessage(Base):
    """Single message inside an AI conversation."""
    __tablename__ = "ai_messages"

    id              = Column(Integer, primary_key=True, index=True)
    conversation_id = Column(Integer, ForeignKey("ai_conversations.id", ondelete="CASCADE"),
                             nullable=False, index=True)
    role            = Column(String(20), nullable=False)   # "user" | "assistant"
    content         = Column(Text, nullable=False)
    created_at      = Column(DateTime, default=datetime.utcnow)

    conversation = relationship("AiConversation", back_populates="messages")
