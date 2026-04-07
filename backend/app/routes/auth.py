import os
import uuid
import shutil
from pathlib import Path
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File
from fastapi.responses import HTMLResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db import get_db
from app.auth import verify_password, get_password_hash, create_access_token, decode_access_token
from app.users import UserCreate, UserLogin, UserResponse, get_user_by_email, get_user_by_id, create_user
from app.email_service import send_verification_email, EMAIL_ENABLED

UPLOADS_DIR = Path("uploads")
UPLOADS_DIR.mkdir(exist_ok=True)

# ── Kazakhstan universities ────────────────────────────────────────────────────
KZ_UNIVERSITIES = [
    "AITU — Astana IT University",
    "НУ — Назарбаев Университет",
    "ЕНУ — Евразийский национальный университет им. Л.Н. Гумилёва",
    "КазНУ — Казахский национальный университет им. аль-Фараби",
    "КазНТУ — Казахский национальный технический университет им. К. Сатпаева",
    "МУИТ — Международный университет информационных технологий",
    "КазГЮУ — Казахский гуманитарно-юридический университет",
    "КазЭУ — Казахский экономический университет им. Т. Рыскулова",
    "КБТУ — Казахстанско-Британский технический университет",
    "Университет КИМЭП",
    "АДУ — Алматы Дейта Университет",
    "SDU — Suleyman Demirel University",
    "ВКТУ — Восточно-Казахстанский технический университет",
    "КарТУ — Карагандинский технический университет",
    "ЮКТУ — Южно-Казахстанский технический университет",
    "АТУ — Алматы технологический университет",
    "КазАТК — Казахская академия транспорта и коммуникаций",
    "Университет Нархоз",
    "КАЗГИК — Казахская академия искусств им. Т. Жургенова",
    "Другой университет",
]

KZ_SPECIALTIES = {
    "IT": [
        "Информационные системы",
        "Программная инженерия",
        "Кибербезопасность",
        "Компьютерные науки",
        "Искусственный интеллект и машинное обучение",
        "Веб-разработка",
        "Мобильная разработка",
        "Data Science",
        "DevOps",
        "Сети и телекоммуникации",
    ],
    "Финансы": [
        "Финансы и кредит",
        "Бухгалтерский учёт и аудит",
        "Экономика",
        "Банковское дело",
        "Инвестиции",
    ],
    "Дизайн": [
        "Графический дизайн",
        "UX/UI дизайн",
        "Дизайн интерьера",
        "Мультимедиа и анимация",
    ],
    "Маркетинг": [
        "Маркетинг",
        "Digital-маркетинг",
        "PR и коммуникации",
        "Реклама",
    ],
    "HR": [
        "Управление персоналом",
        "Психология",
        "Социология",
    ],
    "Другое": [
        "Менеджмент",
        "Юриспруденция",
        "Медицина",
        "Педагогика",
        "Журналистика",
        "Архитектура",
        "Другая специальность",
    ],
}

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")

router = APIRouter()
security = HTTPBearer()


@router.get("/universities")
def list_universities():
    return {"universities": KZ_UNIVERSITIES, "specialties": KZ_SPECIALTIES}


@router.post("/register", response_model=dict)
def register(user_data: UserCreate, db: Session = Depends(get_db)):
    if get_user_by_email(db, user_data.email):
        raise HTTPException(status_code=400, detail="Email already registered")
    if len(user_data.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    if user_data.password != user_data.confirm_password:
        raise HTTPException(status_code=400, detail="Passwords do not match")
    if not user_data.first_name.strip():
        raise HTTPException(status_code=400, detail="First name is required")
    if not user_data.last_name.strip():
        raise HTTPException(status_code=400, detail="Last name is required")

    token = str(uuid.uuid4()) if EMAIL_ENABLED else None
    hashed_password = get_password_hash(user_data.password)
    user = create_user(
        db,
        email=user_data.email,
        first_name=user_data.first_name.strip(),
        last_name=user_data.last_name.strip(),
        hashed_password=hashed_password,
        verification_token=token,
        is_graduate=user_data.is_graduate,
        university_name=user_data.university_name,
        specialty=user_data.specialty,
        study_year=user_data.study_year,
    )

    if EMAIL_ENABLED and token:
        send_verification_email(user.email, user.first_name, token)
        return {"message": "Registration successful. Check your email to verify your account."}

    access_token = create_access_token(data={"user_id": user.id})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": UserResponse.model_validate(user).model_dump(),
    }


@router.post("/login", response_model=dict)
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    user = get_user_by_email(db, credentials.email)
    if not user or not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    if not user.is_verified:
        raise HTTPException(status_code=403, detail="Please verify your email before logging in")

    access_token = create_access_token(data={"user_id": user.id})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": UserResponse.model_validate(user).model_dump(),
    }


@router.get("/verify/{token}", response_class=HTMLResponse)
def verify_email(token: str, db: Session = Depends(get_db)):
    from app.models import User
    user = db.query(User).filter(User.verification_token == token).first()

    if not user:
        return HTMLResponse("""
        <html><body style="font-family:sans-serif;text-align:center;padding:60px">
        <h2 style="color:#EF4444">Неверная или устаревшая ссылка</h2>
        <p>Попробуйте зарегистрироваться снова.</p></body></html>""", status_code=400)

    user.is_verified = True
    user.verification_token = None
    db.commit()

    return HTMLResponse("""
    <html><head><meta charset="utf-8"></head>
    <body style="font-family:sans-serif;text-align:center;padding:60px;background:#F8FAFC">
    <div style="max-width:400px;margin:auto;background:#fff;padding:40px;border-radius:20px;box-shadow:0 4px 20px rgba(0,0,0,.08)">
      <div style="font-size:60px">✅</div>
      <h2 style="color:#6C7DFF;margin:16px 0 8px">Email подтверждён!</h2>
      <p style="color:#64748B">Теперь вы можете войти в приложение Intern KZ.</p>
    </div></body></html>""")


@router.get("/me", response_model=UserResponse)
def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    payload = decode_access_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user_id = payload.get("user_id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    user = get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return UserResponse.model_validate(user)


# ── Google OAuth ──────────────────────────────────────────────────────────────

class GoogleLoginBody(BaseModel):
    id_token: str


@router.post("/google")
def google_login(body: GoogleLoginBody, db: Session = Depends(get_db)):
    if not GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=503, detail="Google Sign-In is not configured on this server")

    try:
        from google.oauth2 import id_token as google_id_token
        from google.auth.transport import requests as google_requests
        idinfo = google_id_token.verify_oauth2_token(
            body.id_token,
            google_requests.Request(),
            GOOGLE_CLIENT_ID,
        )
    except ValueError as e:
        raise HTTPException(status_code=401, detail=f"Invalid Google token: {e}")

    email = idinfo.get("email", "")
    if not email:
        raise HTTPException(status_code=400, detail="No email provided by Google")

    user = get_user_by_email(db, email)
    if not user:
        first_name = idinfo.get("given_name", "User")
        last_name = idinfo.get("family_name", "")
        user = create_user(
            db,
            email=email,
            first_name=first_name,
            last_name=last_name,
            hashed_password="",
            verification_token=None,
        )

    access_token = create_access_token(data={"user_id": user.id})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": UserResponse.model_validate(user).model_dump(),
    }


# ── Reset password ─────────────────────────────────────────────────────────────

class ResetPasswordBody(BaseModel):
    email: str
    new_password: str


@router.post("/reset-password")
def reset_password(body: ResetPasswordBody, db: Session = Depends(get_db)):
    if len(body.new_password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    user = get_user_by_email(db, body.email)
    if not user:
        raise HTTPException(status_code=404, detail="User with this email not found")
    user.hashed_password = get_password_hash(body.new_password)
    db.commit()
    return {"message": "Password updated successfully"}


# ── CV Upload ─────────────────────────────────────────────────────────────────

@router.post("/upload-cv")
def upload_cv(
    file: UploadFile = File(...),
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    payload = decode_access_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = get_user_by_id(db, payload.get("user_id"))
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are allowed")
    if file.size and file.size > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (max 5 MB)")

    filename = f"cv_{user.id}_{uuid.uuid4().hex[:8]}.pdf"
    dest = UPLOADS_DIR / filename
    with dest.open("wb") as f:
        shutil.copyfileobj(file.file, f)

    user.cv_url = f"/uploads/{filename}"
    db.commit()
    return {"cv_url": user.cv_url}


# ── Update profile ─────────────────────────────────────────────────────────────

class UpdateProfileBody(BaseModel):
    name: str


@router.put("/profile", response_model=UserResponse)
def update_profile(
    body: UpdateProfileBody,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    payload = decode_access_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    user = get_user_by_id(db, payload.get("user_id"))
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    if not body.name.strip():
        raise HTTPException(status_code=400, detail="Name cannot be empty")
    user.name = body.name.strip()
    db.commit()
    db.refresh(user)
    return UserResponse.model_validate(user)
