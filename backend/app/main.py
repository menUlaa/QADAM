from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from app.routes.internships import router as internships_router
from app.routes.auth import router as auth_router
from app.routes.applications import router as applications_router
from app.routes.admin import router as admin_router
from app.routes.university import router as university_router
from app.routes.company import router as company_router
from app.routes.ai import router as ai_router
from app.db import Base, engine
import app.models  # noqa: F401 — registers all models with Base

Base.metadata.create_all(bind=engine)

UPLOADS_DIR = Path("uploads")
UPLOADS_DIR.mkdir(exist_ok=True)

app = FastAPI(title="Intern KZ API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.include_router(internships_router, prefix="/internships", tags=["Internships"])
app.include_router(auth_router, prefix="/auth", tags=["Authentication"])
app.include_router(applications_router, prefix="/applications", tags=["Applications"])
app.include_router(admin_router, prefix="/admin", tags=["Admin"])
app.include_router(university_router, prefix="/university", tags=["University"])
app.include_router(company_router, prefix="/company", tags=["Company"])
app.include_router(ai_router, prefix="/ai", tags=["AI"])

ADMIN_HTML = Path(__file__).parent.parent / "admin.html"


@app.get("/panel", include_in_schema=False)
def admin_panel():
    return FileResponse(ADMIN_HTML)


@app.get("/")
def root():
    return {"status": "ok", "message": "Intern KZ API is running"}
