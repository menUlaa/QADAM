from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import or_
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from app.db import get_db
from app.models import Internship, Skill, InternshipSkill, Company
from app.auth import decode_access_token

router = APIRouter()
security = HTTPBearer(auto_error=False)


# ─────────────────────────────────────────────────────────────────────────────
# Schemas
# ─────────────────────────────────────────────────────────────────────────────
class InternshipResponse(BaseModel):
    id: int
    title: str
    company: str
    company_id: Optional[int] = None
    city: str
    format: str
    paid: bool
    salary_kzt: Optional[int] = None
    duration: str
    description: str
    responsibilities: List[str]
    requirements: List[str]
    skills: List[str]
    tags: List[str]
    contact_email: str
    category: str
    is_active: bool = True
    deadline: Optional[datetime] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ─────────────────────────────────────────────────────────────────────────────
# Helper
# ─────────────────────────────────────────────────────────────────────────────
def _to_dict(it: Internship) -> dict:
    if it.skill_links:
        skill_names = [sl.skill.name for sl in it.skill_links if sl.skill]
    else:
        skill_names = it.skills or []
    company_name = (it.company_obj.name if it.company_obj else None) or it.company
    return {
        "id": it.id,
        "title": it.title,
        "company": company_name,
        "company_id": it.company_id,
        "city": it.city,
        "format": it.format,
        "paid": it.paid,
        "salary_kzt": it.salary_kzt,
        "duration": it.duration,
        "description": it.description,
        "responsibilities": it.responsibilities or [],
        "requirements": it.requirements or [],
        "skills": skill_names,
        "tags": it.tags or [],
        "contact_email": it.contact_email,
        "category": it.category,
        "is_active": it.is_active if it.is_active is not None else True,
        "deadline": it.deadline,
        "created_at": it.created_at,
    }


def _base_q(db: Session):
    return (
        db.query(Internship)
        .options(
            joinedload(Internship.company_obj),
            joinedload(Internship.skill_links).joinedload(InternshipSkill.skill),
        )
    )


# ─────────────────────────────────────────────────────────────────────────────
# GET /internships/  — with filters
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/", response_model=List[InternshipResponse])
def list_internships(
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
    city:      Optional[str]  = Query(default=None),
    category:  Optional[str]  = Query(default=None),
    format:    Optional[str]  = Query(default=None),
    paid:      Optional[bool] = Query(default=None),
    skill:     Optional[str]  = Query(default=None),
    search:    Optional[str]  = Query(default=None),
    is_active: Optional[bool] = Query(default=None),
    db: Session = Depends(get_db),
):
    q = _base_q(db)
    if is_active is not None:
        q = q.filter(Internship.is_active == is_active)
    if city:
        q = q.filter(Internship.city.ilike(f"%{city}%"))
    if category:
        q = q.filter(Internship.category.ilike(f"%{category}%"))
    if format:
        q = q.filter(Internship.format.ilike(f"%{format}%"))
    if paid is not None:
        q = q.filter(Internship.paid == paid)
    if skill:
        q = (
            q.join(InternshipSkill, Internship.id == InternshipSkill.internship_id)
             .join(Skill, InternshipSkill.skill_id == Skill.id)
             .filter(Skill.name.ilike(f"%{skill}%"))
        )
    if search:
        t = f"%{search}%"
        q = q.filter(or_(
            Internship.title.ilike(t),
            Internship.company.ilike(t),
            Internship.description.ilike(t),
        ))
    return [_to_dict(it) for it in q.order_by(Internship.id.desc()).offset(skip).limit(limit).all()]


# ─────────────────────────────────────────────────────────────────────────────
# GET /internships/meta/skills|categories|cities
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/meta/skills", response_model=List[dict])
def list_skills(db: Session = Depends(get_db)):
    return [{"id": s.id, "name": s.name, "category": s.category}
            for s in db.query(Skill).order_by(Skill.category, Skill.name).all()]


@router.get("/meta/categories", response_model=List[str])
def list_categories(db: Session = Depends(get_db)):
    rows = db.query(Internship.category).distinct().all()
    return sorted([r[0] for r in rows if r[0]])


@router.get("/meta/cities", response_model=List[str])
def list_cities(db: Session = Depends(get_db)):
    rows = db.query(Internship.city).distinct().all()
    return sorted([r[0] for r in rows if r[0]])


# ─────────────────────────────────────────────────────────────────────────────
# GET /internships/companies/list
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/companies/list", response_model=List[dict])
def list_companies(db: Session = Depends(get_db)):
    internships = db.query(Internship).all()
    companies: dict = {}
    for it in internships:
        key = it.company
        if key not in companies:
            companies[key] = {
                "name": key,
                "internship_count": 0,
                "cities": set(),
                "categories": set(),
                "logo_url": it.company_obj.logo_url if it.company_obj else None,
                "company_id": it.company_id,
            }
        companies[key]["internship_count"] += 1
        companies[key]["cities"].add(it.city)
        companies[key]["categories"].add(it.category)

    return [
        {**v, "cities": sorted(v["cities"]), "categories": sorted(v["categories"])}
        for v in sorted(companies.values(), key=lambda x: -x["internship_count"])
    ]


# ─────────────────────────────────────────────────────────────────────────────
# GET /internships/companies/{name}
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/companies/{company_name}", response_model=List[InternshipResponse])
def company_internships(company_name: str, db: Session = Depends(get_db)):
    internships = (
        _base_q(db)
        .filter(Internship.company.ilike(company_name))
        .order_by(Internship.id.desc())
        .all()
    )
    if not internships:
        raise HTTPException(status_code=404, detail="Company not found")
    return [_to_dict(it) for it in internships]


# ─────────────────────────────────────────────────────────────────────────────
# GET /internships/{id}
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/{internship_id}", response_model=InternshipResponse)
def internship_detail(internship_id: int, db: Session = Depends(get_db)):
    it = _base_q(db).filter(Internship.id == internship_id).first()
    if not it:
        raise HTTPException(status_code=404, detail="Internship not found")
    return _to_dict(it)
