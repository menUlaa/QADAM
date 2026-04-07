from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List
from app.db import get_db
from app.auth import decode_access_token
from app.users import get_user_by_id
from app.models import Application, Internship

router = APIRouter()
security = HTTPBearer()


class ApplicationCreate(BaseModel):
    internship_id: int
    message: Optional[str] = None


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> int:
    payload = decode_access_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    user_id = payload.get("user_id")
    if not user_id or not get_user_by_id(db, user_id):
        raise HTTPException(status_code=401, detail="User not found")
    return user_id


@router.post("/", response_model=dict)
def apply(
    app_data: ApplicationCreate,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    internship = db.query(Internship).filter(Internship.id == app_data.internship_id).first()
    if not internship:
        raise HTTPException(status_code=404, detail="Internship not found")

    existing = db.query(Application).filter(
        Application.user_id == user_id,
        Application.internship_id == app_data.internship_id,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Already applied to this internship")

    application = Application(
        user_id=user_id,
        internship_id=app_data.internship_id,
        message=app_data.message,
        status="pending",
    )
    db.add(application)
    db.commit()
    db.refresh(application)

    return {"message": "Application submitted", "application_id": application.id}


@router.get("/my", response_model=List[dict])
def my_applications(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    applications = (
        db.query(Application)
        .filter(Application.user_id == user_id)
        .all()
    )
    return [
        {
            "id": app.id,
            "internship_id": app.internship_id,
            "internship_title": app.internship.title,
            "internship_company": app.internship.company,
            "message": app.message,
            "status": app.status,
            "created_at": app.created_at.isoformat(),
        }
        for app in applications
    ]
