from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List
from collections import defaultdict

from app.db import get_db
from app.auth import verify_password, get_password_hash, create_access_token, decode_access_token
from app.models import University, StudentUniversity, User, Application, Internship, InternshipReport

router = APIRouter()
security = HTTPBearer()


# ── Schemas ────────────────────────────────────────────────────────────────────

class UniversityRegister(BaseModel):
    name: str
    email: str
    password: str
    city: Optional[str] = ""


class UniversityLogin(BaseModel):
    email: str
    password: str


class UniversityResponse(BaseModel):
    id: int
    name: str
    email: str
    city: str

    class Config:
        from_attributes = True


class LinkStudentBody(BaseModel):
    student_email: str
    specialty: Optional[str] = ""
    study_year: Optional[int] = None
    student_id_number: Optional[str] = ""


class SubmitReportBody(BaseModel):
    application_id: int
    hours_completed: int
    tasks_description: str
    skills_gained: List[str] = []


# ── Auth helpers ───────────────────────────────────────────────────────────────

def get_current_university(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> University:
    payload = decode_access_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    uni_id = payload.get("university_id")
    if not uni_id:
        raise HTTPException(status_code=401, detail="Not a university token")
    uni = db.query(University).filter(University.id == uni_id).first()
    if not uni:
        raise HTTPException(status_code=401, detail="University not found")
    return uni


# ── Register / Login ───────────────────────────────────────────────────────────

@router.post("/register", response_model=dict)
def register(body: UniversityRegister, db: Session = Depends(get_db)):
    if not body.name.strip():
        raise HTTPException(status_code=400, detail="University name is required")
    if len(body.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    if db.query(University).filter(University.email == body.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    uni = University(
        name=body.name.strip(),
        email=body.email.lower().strip(),
        hashed_password=get_password_hash(body.password),
        city=body.city or "",
    )
    db.add(uni)
    db.commit()
    db.refresh(uni)

    token = create_access_token(data={"university_id": uni.id})
    return {
        "access_token": token,
        "token_type": "bearer",
        "university": {"id": uni.id, "name": uni.name, "email": uni.email, "city": uni.city},
    }


@router.post("/login", response_model=dict)
def login(body: UniversityLogin, db: Session = Depends(get_db)):
    uni = db.query(University).filter(University.email == body.email.lower().strip()).first()
    if not uni or not verify_password(body.password, uni.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    token = create_access_token(data={"university_id": uni.id})
    return {
        "access_token": token,
        "token_type": "bearer",
        "university": {"id": uni.id, "name": uni.name, "email": uni.email, "city": uni.city},
    }


@router.get("/me", response_model=dict)
def me(uni: University = Depends(get_current_university)):
    return {"id": uni.id, "name": uni.name, "email": uni.email, "city": uni.city}


# ── Student management ─────────────────────────────────────────────────────────

@router.post("/students/link", response_model=dict)
def link_student(
    body: LinkStudentBody,
    uni: University = Depends(get_current_university),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == body.student_email.lower().strip()).first()
    if not user:
        raise HTTPException(status_code=404, detail="Student with this email not found")

    existing = db.query(StudentUniversity).filter(
        StudentUniversity.user_id == user.id,
        StudentUniversity.university_id == uni.id,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Student already linked to this university")

    link = StudentUniversity(
        user_id=user.id,
        university_id=uni.id,
        specialty=body.specialty or "",
        study_year=body.study_year,
        student_id_number=body.student_id_number or "",
    )
    db.add(link)
    db.commit()
    return {"message": f"Student {user.name or user.email} linked successfully"}


@router.delete("/students/{user_id}", response_model=dict)
def unlink_student(
    user_id: int,
    uni: University = Depends(get_current_university),
    db: Session = Depends(get_db),
):
    link = db.query(StudentUniversity).filter(
        StudentUniversity.user_id == user_id,
        StudentUniversity.university_id == uni.id,
    ).first()
    if not link:
        raise HTTPException(status_code=404, detail="Student not linked to this university")
    db.delete(link)
    db.commit()
    return {"message": "Student unlinked"}


@router.get("/students", response_model=List[dict])
def list_students(
    uni: University = Depends(get_current_university),
    db: Session = Depends(get_db),
):
    links = (
        db.query(StudentUniversity)
        .filter(StudentUniversity.university_id == uni.id)
        .all()
    )

    result = []
    for link in links:
        user = link.user
        apps = db.query(Application).filter(Application.user_id == user.id).all()

        result.append({
            "user_id": user.id,
            "name": user.name or f"{user.first_name} {user.last_name}".strip(),
            "email": user.email,
            "specialty": link.specialty,
            "study_year": link.study_year,
            "student_id_number": link.student_id_number,
            "joined_at": link.joined_at.isoformat(),
            "applications": [
                {
                    "id": a.id,
                    "internship_title": a.internship.title,
                    "company": a.internship.company,
                    "status": a.status,
                    "created_at": a.created_at.isoformat(),
                    "has_report": a.report is not None,
                }
                for a in apps
            ],
        })

    return result


# ── Analytics ──────────────────────────────────────────────────────────────────

@router.get("/analytics", response_model=dict)
def analytics(
    uni: University = Depends(get_current_university),
    db: Session = Depends(get_db),
):
    links = db.query(StudentUniversity).filter(StudentUniversity.university_id == uni.id).all()
    user_ids = [l.user_id for l in links]

    total_students = len(user_ids)
    if not user_ids:
        return {
            "total_students": 0,
            "total_applications": 0,
            "accepted": 0,
            "rejected": 0,
            "pending": 0,
            "acceptance_rate": 0.0,
            "by_category": [],
            "by_status": [],
            "top_companies": [],
        }

    apps = db.query(Application).filter(Application.user_id.in_(user_ids)).all()
    total_apps = len(apps)

    status_counts: dict = defaultdict(int)
    category_counts: dict = defaultdict(int)
    company_counts: dict = defaultdict(int)

    for a in apps:
        status_counts[a.status] += 1
        category_counts[a.internship.category] += 1
        company_counts[a.internship.company] += 1

    accepted = status_counts.get("accepted", 0)
    acceptance_rate = round(accepted / total_apps * 100, 1) if total_apps else 0.0

    top_companies = sorted(
        [{"company": k, "count": v} for k, v in company_counts.items()],
        key=lambda x: x["count"],
        reverse=True,
    )[:5]

    return {
        "total_students": total_students,
        "total_applications": total_apps,
        "accepted": accepted,
        "rejected": status_counts.get("rejected", 0),
        "pending": status_counts.get("pending", 0),
        "acceptance_rate": acceptance_rate,
        "by_category": [{"category": k, "count": v} for k, v in category_counts.items()],
        "by_status": [{"status": k, "count": v} for k, v in status_counts.items()],
        "top_companies": top_companies,
    }


# ── Internship reports ─────────────────────────────────────────────────────────

@router.post("/reports", response_model=dict)
def submit_report(
    body: SubmitReportBody,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    """Student submits a report for a completed internship."""
    payload = decode_access_token(credentials.credentials)
    if not payload or not payload.get("user_id"):
        raise HTTPException(status_code=401, detail="Student login required")

    app = db.query(Application).filter(Application.id == body.application_id).first()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")
    if app.user_id != payload["user_id"]:
        raise HTTPException(status_code=403, detail="Not your application")
    if app.status != "accepted":
        raise HTTPException(status_code=400, detail="Can only report for accepted internships")
    if app.report:
        raise HTTPException(status_code=400, detail="Report already submitted")

    report = InternshipReport(
        application_id=app.id,
        hours_completed=body.hours_completed,
        tasks_description=body.tasks_description,
        skills_gained=body.skills_gained,
    )
    db.add(report)
    db.commit()
    return {"message": "Report submitted successfully"}
