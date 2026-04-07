from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db import get_db
from app.auth import decode_access_token
from app.models import User, Internship, Application
from app.users import get_user_by_id
from app.email_service import send_status_email

router = APIRouter()
security = HTTPBearer()


def get_current_admin(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    payload = decode_access_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    user = get_user_by_id(db, payload.get("user_id"))
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    if not user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return user


# ── Stats ──────────────────────────────────────────────────────────────────────

@router.get("/stats")
def get_stats(db: Session = Depends(get_db), _: User = Depends(get_current_admin)):
    return {
        "internships": db.query(Internship).count(),
        "applications": db.query(Application).count(),
        "pending": db.query(Application).filter(Application.status == "pending").count(),
        "accepted": db.query(Application).filter(Application.status == "accepted").count(),
        "rejected": db.query(Application).filter(Application.status == "rejected").count(),
        "users": db.query(User).filter(User.is_admin == False).count(),
    }


# ── Applications ───────────────────────────────────────────────────────────────

@router.get("/applications")
def get_all_applications(db: Session = Depends(get_db), _: User = Depends(get_current_admin)):
    apps = db.query(Application).order_by(Application.created_at.desc()).all()
    return [
        {
            "id": a.id,
            "status": a.status,
            "message": a.message,
            "created_at": a.created_at.isoformat() if a.created_at else None,
            "user_name": a.user.name,
            "user_email": a.user.email,
            "internship_title": a.internship.title,
            "internship_company": a.internship.company,
            "internship_id": a.internship_id,
        }
        for a in apps
    ]


class StatusUpdate(BaseModel):
    status: str  # pending | accepted | rejected


@router.put("/applications/{app_id}/status")
def update_application_status(
    app_id: int,
    body: StatusUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    if body.status not in ("pending", "accepted", "rejected"):
        raise HTTPException(status_code=400, detail="Invalid status")
    app = db.query(Application).filter(Application.id == app_id).first()
    if not app:
        raise HTTPException(status_code=404, detail="Application not found")
    old_status = app.status
    app.status = body.status
    db.commit()
    if old_status != body.status and body.status in ("accepted", "rejected"):
        send_status_email(
            to=app.user.email,
            name=app.user.name,
            internship_title=app.internship.title,
            status=body.status,
        )
    return {"id": app.id, "status": app.status}


# ── Internships CRUD ───────────────────────────────────────────────────────────

class InternshipBody(BaseModel):
    title: str
    company: str
    city: str
    format: str
    paid: bool
    salary_kzt: Optional[int] = None
    duration: str
    description: str
    responsibilities: List[str] = []
    requirements: List[str] = []
    skills: List[str] = []
    tags: List[str] = []
    contact_email: str
    category: str


@router.get("/internships")
def list_internships(db: Session = Depends(get_db), _: User = Depends(get_current_admin)):
    return db.query(Internship).order_by(Internship.id).all()


@router.post("/internships", status_code=201)
def create_internship(
    body: InternshipBody,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    internship = Internship(**body.model_dump())
    db.add(internship)
    db.commit()
    db.refresh(internship)
    return internship


@router.put("/internships/{iid}")
def update_internship(
    iid: int,
    body: InternshipBody,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    internship = db.query(Internship).filter(Internship.id == iid).first()
    if not internship:
        raise HTTPException(status_code=404, detail="Internship not found")
    for field, value in body.model_dump().items():
        setattr(internship, field, value)
    db.commit()
    db.refresh(internship)
    return internship


@router.delete("/internships/{iid}")
def delete_internship(
    iid: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    internship = db.query(Internship).filter(Internship.id == iid).first()
    if not internship:
        raise HTTPException(status_code=404, detail="Internship not found")
    db.delete(internship)
    db.commit()
    return {"deleted": iid}
