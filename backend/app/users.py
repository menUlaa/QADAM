from typing import Optional, List
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
from app.models import User


class UserCreate(BaseModel):
    email: EmailStr
    first_name: str
    last_name: str
    password: str
    confirm_password: str
    is_graduate: bool = False
    university_name: Optional[str] = None
    specialty: Optional[str] = None
    study_year: Optional[int] = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: int
    email: str
    first_name: str = ""
    last_name: str = ""
    name: str
    is_admin: bool = False
    is_verified: bool = False
    is_graduate: bool = False
    university_name: Optional[str] = None
    specialty: Optional[str] = None
    study_year: Optional[int] = None
    cv_url: Optional[str] = None
    cv_filename: Optional[str] = None
    cv_uploaded_at: Optional[str] = None
    skills: Optional[List[str]] = None
    portfolio_url: Optional[str] = None
    bio: Optional[str] = None
    open_to_work: bool = True

    class Config:
        from_attributes = True

    @classmethod
    def model_validate(cls, obj, **kwargs):
        cv_uploaded_at = getattr(obj, "cv_uploaded_at", None)
        data = {
            "id": obj.id,
            "email": obj.email,
            "first_name": getattr(obj, "first_name", "") or "",
            "last_name": getattr(obj, "last_name", "") or "",
            "name": getattr(obj, "name", "") or "",
            "is_admin": getattr(obj, "is_admin", False),
            "is_verified": getattr(obj, "is_verified", True),
            "is_graduate": getattr(obj, "is_graduate", False),
            "university_name": getattr(obj, "university_name", None),
            "specialty": getattr(obj, "specialty", None),
            "study_year": getattr(obj, "study_year", None),
            "cv_url": getattr(obj, "cv_url", None),
            "cv_filename": getattr(obj, "cv_filename", None),
            "cv_uploaded_at": cv_uploaded_at.isoformat() if cv_uploaded_at else None,
            "skills": getattr(obj, "skills", None) or [],
            "portfolio_url": getattr(obj, "portfolio_url", None),
            "bio": getattr(obj, "bio", None),
            "open_to_work": getattr(obj, "open_to_work", True) or True,
        }
        return cls(**data)


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    return db.query(User).filter(User.email == email).first()


def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
    return db.query(User).filter(User.id == user_id).first()


def create_user(
    db: Session,
    email: str,
    first_name: str,
    last_name: str,
    hashed_password: str,
    verification_token: Optional[str] = None,
    is_graduate: bool = False,
    university_name: Optional[str] = None,
    specialty: Optional[str] = None,
    study_year: Optional[int] = None,
) -> User:
    name = f"{first_name} {last_name}".strip()
    user = User(
        email=email,
        first_name=first_name,
        last_name=last_name,
        name=name,
        hashed_password=hashed_password,
        is_verified=verification_token is None,
        verification_token=verification_token,
        is_graduate=is_graduate,
        university_name=university_name,
        specialty=specialty,
        study_year=study_year,
        skills=[],
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user
