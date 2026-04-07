from sqlalchemy import Column, Integer, String, Boolean, Text, JSON, ForeignKey, DateTime, Float
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(200), unique=True, nullable=False, index=True)
    first_name = Column(String(100), nullable=False, default="")
    last_name = Column(String(100), nullable=False, default="")
    name = Column(String(200), nullable=False, default="")
    hashed_password = Column(String(200), nullable=False)
    is_admin = Column(Boolean, default=False, nullable=False)
    is_verified = Column(Boolean, default=False, nullable=False)
    is_graduate = Column(Boolean, default=False, nullable=False)
    verification_token = Column(String(200), nullable=True)
    # Student profile extras
    university_name = Column(String(300), nullable=True)
    specialty = Column(String(200), nullable=True)
    study_year = Column(Integer, nullable=True)
    cv_url = Column(String(500), nullable=True)
    cv_filename = Column(String(200), nullable=True)
    cv_uploaded_at = Column(DateTime, nullable=True)
    skills = Column(JSON, default=list)
    portfolio_url = Column(String(500), nullable=True)
    bio = Column(Text, nullable=True)
    open_to_work = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    applications = relationship("Application", back_populates="user")
    university_link = relationship("StudentUniversity", back_populates="user", uselist=False)


class Company(Base):
    __tablename__ = "companies"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(300), nullable=False)
    email = Column(String(200), unique=True, nullable=False, index=True)
    hashed_password = Column(String(200), nullable=False)
    description = Column(Text, default="")
    city = Column(String(100), default="")
    website = Column(String(300), default="")
    logo_url = Column(String(500), nullable=True)
    is_verified = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    internships = relationship("Internship", back_populates="company_obj")


class Internship(Base):
    __tablename__ = "internships"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    company = Column(String(200), nullable=False)
    city = Column(String(100), nullable=False, default="")
    format = Column(String(50), nullable=False, default="Hybrid")
    paid = Column(Boolean, nullable=False, default=True)
    salary_kzt = Column(Integer, nullable=True)
    duration = Column(String(100), nullable=False, default="")
    description = Column(Text, nullable=False, default="")

    responsibilities = Column(JSON, nullable=False, default=list)
    requirements = Column(JSON, nullable=False, default=list)
    skills = Column(JSON, nullable=False, default=list)
    tags = Column(JSON, nullable=False, default=list)

    contact_email = Column(String(200), nullable=False, default="")
    category = Column(String(100), nullable=False, default="IT")
    company_id = Column(Integer, ForeignKey("companies.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    applications = relationship("Application", back_populates="internship")
    company_obj = relationship("Company", back_populates="internships")


class Application(Base):
    __tablename__ = "applications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    internship_id = Column(Integer, ForeignKey("internships.id"), nullable=False)
    message = Column(Text, nullable=True)
    status = Column(String(50), default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="applications")
    internship = relationship("Internship", back_populates="applications")
    report = relationship("InternshipReport", back_populates="application", uselist=False)


class University(Base):
    __tablename__ = "universities"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(300), nullable=False)
    email = Column(String(200), unique=True, nullable=False, index=True)
    hashed_password = Column(String(200), nullable=False)
    city = Column(String(100), default="")
    created_at = Column(DateTime, default=datetime.utcnow)

    students = relationship("StudentUniversity", back_populates="university")


class StudentUniversity(Base):
    """Links a User (student) to a University."""
    __tablename__ = "student_universities"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    university_id = Column(Integer, ForeignKey("universities.id"), nullable=False)
    specialty = Column(String(200), default="")
    study_year = Column(Integer, nullable=True)   # 1–4
    student_id_number = Column(String(100), default="")
    joined_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="university_link")
    university = relationship("University", back_populates="students")


class InternshipReport(Base):
    """Report submitted by a student after completing an internship."""
    __tablename__ = "internship_reports"

    id = Column(Integer, primary_key=True, index=True)
    application_id = Column(Integer, ForeignKey("applications.id"), nullable=False)
    hours_completed = Column(Integer, default=0)
    tasks_description = Column(Text, default="")
    skills_gained = Column(JSON, default=list)
    company_rating = Column(Float, nullable=True)   # 1–5 stars given by company
    company_feedback = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    application = relationship("Application", back_populates="report")
