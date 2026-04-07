from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from app.db import get_db
from app.models import Internship

router = APIRouter()


class InternshipResponse(BaseModel):
    id: int
    title: str
    company: str
    city: str
    format: str
    paid: bool
    salary_kzt: Optional[int]
    duration: str
    description: str
    responsibilities: List[str]
    requirements: List[str]
    skills: List[str]
    tags: List[str]
    contact_email: str
    category: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


@router.get("/", response_model=List[InternshipResponse])
def list_internships(
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
    db: Session = Depends(get_db),
):
    return db.query(Internship).order_by(Internship.id.desc()).offset(skip).limit(limit).all()


@router.get("/companies/list", response_model=List[dict])
def list_companies(db: Session = Depends(get_db)):
    """Returns unique companies with their internship counts."""
    internships = db.query(Internship).all()
    companies: dict = {}
    for it in internships:
        if it.company not in companies:
            companies[it.company] = {
                "name": it.company,
                "count": 0,
                "cities": set(),
                "categories": set(),
            }
        companies[it.company]["count"] += 1
        companies[it.company]["cities"].add(it.city)
        companies[it.company]["categories"].add(it.category)

    return [
        {
            "name": v["name"],
            "internship_count": v["count"],
            "cities": sorted(v["cities"]),
            "categories": sorted(v["categories"]),
        }
        for v in sorted(companies.values(), key=lambda x: -x["count"])
    ]


@router.get("/companies/{company_name}", response_model=List[InternshipResponse])
def company_internships(company_name: str, db: Session = Depends(get_db)):
    """Returns all internships for a specific company."""
    internships = (
        db.query(Internship)
        .filter(Internship.company == company_name)
        .order_by(Internship.id.desc())
        .all()
    )
    if not internships:
        raise HTTPException(status_code=404, detail="Company not found")
    return internships


@router.get("/{internship_id}", response_model=InternshipResponse)
def internship_detail(internship_id: int, db: Session = Depends(get_db)):
    internship = db.query(Internship).filter(Internship.id == internship_id).first()
    if not internship:
        raise HTTPException(status_code=404, detail="Internship not found")
    return internship
