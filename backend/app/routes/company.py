"""Company (employer) auth + dashboard endpoints."""
import json
import os
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from typing import List, Optional
from sqlalchemy.orm import Session, joinedload

from app.db import get_db
from app.auth import verify_password, get_password_hash, create_access_token, decode_access_token
from app.models import Company, Internship, Application, User, UserSkill, StudentUniversity

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")

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

    apps = (
        db.query(Application)
        .filter(Application.internship_id.in_(internship_ids))
        .order_by(Application.created_at.desc())
        .all()
    )

    # Pre-load users and internships
    user_ids = list({a.user_id for a in apps})
    users = {
        u.id: u for u in
        db.query(User)
        .options(
            joinedload(User.university_link).joinedload(StudentUniversity.university),
            joinedload(User.skill_links),
        )
        .filter(User.id.in_(user_ids))
        .all()
    }
    internship_map = {it.id: it for it in
        db.query(Internship).filter(Internship.id.in_(internship_ids)).all()}

    result = []
    for app in apps:
        user = users.get(app.user_id)
        internship = internship_map.get(app.internship_id)

        # Resolve university name via relationship
        student_university = ""
        student_specialty = ""
        if user and user.university_link:
            if user.university_link.university:
                student_university = user.university_link.university.name or ""
            student_specialty = user.university_link.specialty or ""

        # Resolve skills: prefer normalised skill_links, fallback to JSON
        student_skills: list = []
        if user:
            if user.skill_links:
                student_skills = [sl.skill.name for sl in user.skill_links if sl.skill]
            elif user.skills:
                student_skills = user.skills if isinstance(user.skills, list) else []

        result.append({
            "id": app.id,
            "status": app.status,
            "message": app.message or "",
            "created_at": app.created_at.isoformat() if app.created_at else None,
            "internship_id": app.internship_id,
            "internship_title": internship.title if internship else "",
            "student_name": user.name if user else "",
            "student_email": user.email if user else "",
            "student_university": student_university,
            "student_specialty": student_specialty,
            "student_cv_url": user.cv_url or "" if user else "",
            "student_skills": student_skills,
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
    valid_statuses = ("pending", "reviewed", "interview", "offer", "accepted", "rejected")
    if new_status not in valid_statuses:
        raise HTTPException(status_code=400, detail="Invalid status")

    app.status = new_status

    # Create notification for the student
    from app.routes.notifications import create_notification
    status_labels = {
        "accepted": ("Заявка принята! 🎉", f"Вас приняли на стажировку «{internship.title}» в {company.name}"),
        "rejected": ("Обновление по заявке", f"К сожалению, ваша заявка на «{internship.title}» отклонена"),
        "pending":  ("Заявка на рассмотрении", f"Ваша заявка на «{internship.title}» взята на рассмотрение"),
        "reviewed": ("Заявка рассмотрена", f"Ваша заявка на «{internship.title}» в {company.name} рассмотрена"),
        "interview": ("Приглашение на интервью!", f"Компания {company.name} приглашает вас на интервью по «{internship.title}»"),
        "offer": ("Получен оффер!", f"Поздравляем! {company.name} делает вам оффер на стажировку «{internship.title}»"),
    }
    title, body_text = status_labels.get(new_status, ("Обновление заявки", "Статус вашей заявки обновлён"))
    notif = create_notification(
        db, user_id=app.user_id,
        type="application_status",
        title=title, body=body_text,
        related_internship_id=internship.id,
        related_application_id=app.id,
    )
    db.add(notif)
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
        reviewed = sum(1 for a in apps if a.status == "reviewed")
        interview = sum(1 for a in apps if a.status == "interview")
        offer = sum(1 for a in apps if a.status == "offer")

    return {
        "total_internships": total_internships,
        "total_applications": total_apps,
        "pending": pending,
        "reviewed": reviewed,
        "interview": interview,
        "offer": offer,
        "accepted": accepted,
        "rejected": rejected,
    }


# ── AI Candidate Scoring ──────────────────────────────────────────────────────

@router.post("/applications/{app_id}/ai-score")
def ai_score_application(
    app_id: int,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    """Score a candidate using Claude AI based on their profile vs internship requirements."""
    company = _get_company(credentials, db)

    app = db.query(Application).filter(Application.id == app_id).first()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")

    internship = db.query(Internship).filter(
        Internship.id == app.internship_id,
        Internship.company_id == company.id,
    ).first()
    if not internship:
        raise HTTPException(status_code=403, detail="Not your internship")

    user = (
        db.query(User)
        .options(
            joinedload(User.university_link).joinedload(StudentUniversity.university),
            joinedload(User.skill_links),
        )
        .filter(User.id == app.user_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="Student not found")

    # Resolve student details
    student_university = ""
    student_specialty = ""
    if user.university_link:
        if user.university_link.university:
            student_university = user.university_link.university.name or ""
        student_specialty = user.university_link.specialty or ""

    student_skills: list = []
    if user.skill_links:
        student_skills = [sl.skill.name for sl in user.skill_links if sl.skill]
    elif user.skills:
        student_skills = user.skills if isinstance(user.skills, list) else []

    # Build Claude prompt
    system_prompt = (
        "You are a professional recruiter AI. Evaluate candidate fit for an internship. "
        "Return ONLY a valid JSON object with keys: score (int 0-100), "
        "summary (string, 1 sentence in Russian), "
        "strengths (list of 2-3 strings in Russian), "
        "gaps (list of 1-3 strings in Russian, can be empty)."
    )

    user_prompt = f"""Internship: {internship.title}
Category: {internship.category}
Required skills: {json.dumps(internship.skills or [], ensure_ascii=False)}
Requirements: {json.dumps(internship.requirements or [], ensure_ascii=False)}

Candidate: {user.name}
University: {student_university}
Specialty: {student_specialty}
Skills: {json.dumps(student_skills, ensure_ascii=False)}
Bio: {user.bio or 'Не указано'}
Has CV: {'Yes' if user.cv_url else 'No'}
Cover letter: {app.message or 'Не указано'}

Score the candidate fit and return the JSON."""

    try:
        import anthropic
        client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
        response = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=400,
            system=system_prompt,
            messages=[{"role": "user", "content": user_prompt}],
        )
        raw = response.content[0].text.strip()
        # Extract JSON block if wrapped in markdown
        if "```" in raw:
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        result = json.loads(raw)
        return {
            "score": int(result.get("score", 0)),
            "summary": result.get("summary", ""),
            "strengths": result.get("strengths", []),
            "gaps": result.get("gaps", []),
        }
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"AI scoring failed: {str(exc)}")
