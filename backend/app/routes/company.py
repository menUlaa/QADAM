"""Company (employer) auth + dashboard endpoints."""
import uuid
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from typing import List, Optional
from sqlalchemy.orm import Session

from app.db import get_db
from app.auth import verify_password, get_password_hash, create_access_token, decode_access_token
from app.models import Company, Internship, Application, User

router = APIRouter()
security = HTTPBearer()


# ── Schemas ───────────────────────────────────────────────────────────────────

class CompanyRegister(BaseModel):
    name: str
    email: EmailStr
    password: str
    city: Optional[str] = ""
    description: Optional[str] = ""
    website: Optional[str] = ""


class CompanyLogin(BaseModel):
    email: EmailStr
    password: str


class CompanyResponse(BaseModel):
    id: int
    name: str
    email: str
    city: str = ""
    description: str = ""
    website: str = ""

    class Config:
        from_attributes = True


class InternshipCreate(BaseModel):
    title: str
    city: str
    format: str = "Hybrid"
    paid: bool = True
    salary_kzt: Optional[int] = None
    duration: str = ""
    description: str
    responsibilities: List[str] = []
    requirements: List[str] = []
    skills: List[str] = []
    tags: List[str] = []
    category: str = "IT"


# ── Helper ────────────────────────────────────────────────────────────────────

def _get_company(credentials: HTTPAuthorizationCredentials, db: Session) -> Company:
    payload = decode_access_token(credentials.credentials)
    if not payload or not payload.get("company_id"):
        raise HTTPException(status_code=401, detail="Company login required")
    company = db.query(Company).filter(Company.id == payload["company_id"]).first()
    if not company:
        raise HTTPException(status_code=401, detail="Company not found")
    return company


# ── Auth ──────────────────────────────────────────────────────────────────────

@router.post("/register", response_model=dict)
def company_register(data: CompanyRegister, db: Session = Depends(get_db)):
    if db.query(Company).filter(Company.email == data.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    if len(data.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    company = Company(
        name=data.name.strip(),
        email=data.email,
        hashed_password=get_password_hash(data.password),
        city=data.city or "",
        description=data.description or "",
        website=data.website or "",
    )
    db.add(company)
    db.commit()
    db.refresh(company)
    token = create_access_token(data={"company_id": company.id})
    return {
        "access_token": token,
        "token_type": "bearer",
        "company": CompanyResponse.model_validate(company).model_dump(),
    }


@router.post("/login", response_model=dict)
def company_login(data: CompanyLogin, db: Session = Depends(get_db)):
    company = db.query(Company).filter(Company.email == data.email).first()
    if not company or not verify_password(data.password, company.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    token = create_access_token(data={"company_id": company.id})
    return {
        "access_token": token,
        "token_type": "bearer",
        "company": CompanyResponse.model_validate(company).model_dump(),
    }


@router.get("/me", response_model=CompanyResponse)
def company_me(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    return _get_company(credentials, db)


# ── Internships ───────────────────────────────────────────────────────────────

@router.get("/internships", response_model=List[dict])
def my_internships(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    company = _get_company(credentials, db)
    internships = db.query(Internship).filter(Internship.company_id == company.id).all()
    result = []
    for it in internships:
        app_count = db.query(Application).filter(Application.internship_id == it.id).count()
        result.append({
            "id": it.id,
            "title": it.title,
            "city": it.city,
            "format": it.format,
            "paid": it.paid,
            "salary_kzt": it.salary_kzt,
            "category": it.category,
            "created_at": it.created_at.isoformat() if it.created_at else None,
            "application_count": app_count,
        })
    return result


@router.post("/internships", response_model=dict)
def create_internship(
    data: InternshipCreate,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    company = _get_company(credentials, db)
    internship = Internship(
        title=data.title,
        company=company.name,
        company_id=company.id,
        city=data.city,
        format=data.format,
        paid=data.paid,
        salary_kzt=data.salary_kzt,
        duration=data.duration,
        description=data.description,
        responsibilities=data.responsibilities,
        requirements=data.requirements,
        skills=data.skills,
        tags=data.tags,
        category=data.category,
        contact_email=company.email,
    )
    db.add(internship)
    db.commit()
    db.refresh(internship)
    return {"id": internship.id, "message": "Internship created"}


@router.delete("/internships/{internship_id}")
def delete_internship(
    internship_id: int,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    company = _get_company(credentials, db)
    it = db.query(Internship).filter(
        Internship.id == internship_id,
        Internship.company_id == company.id,
    ).first()
    if not it:
        raise HTTPException(status_code=404, detail="Internship not found")
    db.delete(it)
    db.commit()
    return {"message": "Deleted"}


# ── Applications ──────────────────────────────────────────────────────────────

@router.get("/applications", response_model=List[dict])
def company_applications(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    company = _get_company(credentials, db)
    # Get all internship ids for this company
    internship_ids = [
        row.id for row in
        db.query(Internship.id).filter(Internship.company_id == company.id).all()
    ]
    if not internship_ids:
        return []

    apps = db.query(Application).filter(
        Application.internship_id.in_(internship_ids)
    ).order_by(Application.created_at.desc()).all()

    result = []
    for app in apps:
        user = db.query(User).filter(User.id == app.user_id).first()
        internship = db.query(Internship).filter(Internship.id == app.internship_id).first()
        result.append({
            "id": app.id,
            "status": app.status,
            "message": app.message or "",
            "created_at": app.created_at.isoformat() if app.created_at else None,
            "internship_id": app.internship_id,
            "internship_title": internship.title if internship else "",
            "student_name": user.name if user else "",
            "student_email": user.email if user else "",
            "student_university": user.university_name or "",
            "student_specialty": user.specialty or "",
            "student_cv_url": user.cv_url or "",
            "student_skills": user.skills or [],
        })
    return result


@router.put("/applications/{app_id}/status")
def update_application_status(
    app_id: int,
    body: dict,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    company = _get_company(credentials, db)
    app = db.query(Application).filter(Application.id == app_id).first()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")

    # Verify this application belongs to company's internship
    internship = db.query(Internship).filter(
        Internship.id == app.internship_id,
        Internship.company_id == company.id,
    ).first()
    if not internship:
        raise HTTPException(status_code=403, detail="Not your internship")

    new_status = body.get("status")
    if new_status not in ("pending", "accepted", "rejected"):
        raise HTTPException(status_code=400, detail="Invalid status")

    app.status = new_status
    db.commit()
    return {"message": f"Status updated to {new_status}"}


# ── Stats ─────────────────────────────────────────────────────────────────────

@router.get("/stats")
def company_stats(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    company = _get_company(credentials, db)
    internship_ids = [
        row.id for row in
        db.query(Internship.id).filter(Internship.company_id == company.id).all()
    ]
    total_internships = len(internship_ids)
    total_apps = 0
    pending = accepted = rejected = 0

    if internship_ids:
        apps = db.query(Application).filter(
            Application.internship_id.in_(internship_ids)
        ).all()
        total_apps = len(apps)
        pending = sum(1 for a in apps if a.status == "pending")
        accepted = sum(1 for a in apps if a.status == "accepted")
        rejected = sum(1 for a in apps if a.status == "rejected")

    return {
        "total_internships": total_internships,
        "total_applications": total_apps,
        "pending": pending,
        "accepted": accepted,
        "rejected": rejected,
    }
