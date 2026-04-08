"""Saved (bookmarked) internships endpoints."""
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session, joinedload
from typing import List
from app.db import get_db
from app.models import SavedInternship, Internship, InternshipSkill
from app.auth import decode_access_token
from app.routes.internships import _to_dict, _base_q

router = APIRouter()
security = HTTPBearer()


def _current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> int:
    payload = decode_access_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    return payload["user_id"]


# ── POST /saved/{internship_id}  — save (bookmark) ───────────────────────────
@router.post("/{internship_id}", response_model=dict)
def save_internship(
    internship_id: int,
    user_id: int = Depends(_current_user_id),
    db: Session = Depends(get_db),
):
    it = db.query(Internship).filter(Internship.id == internship_id).first()
    if not it:
        raise HTTPException(status_code=404, detail="Internship not found")

    existing = db.query(SavedInternship).filter_by(
        user_id=user_id, internship_id=internship_id
    ).first()
    if existing:
        return {"saved": True, "message": "Already saved"}

    db.add(SavedInternship(user_id=user_id, internship_id=internship_id))
    db.commit()
    return {"saved": True}


# ── DELETE /saved/{internship_id}  — unsave ───────────────────────────────────
@router.delete("/{internship_id}", response_model=dict)
def unsave_internship(
    internship_id: int,
    user_id: int = Depends(_current_user_id),
    db: Session = Depends(get_db),
):
    row = db.query(SavedInternship).filter_by(
        user_id=user_id, internship_id=internship_id
    ).first()
    if not row:
        raise HTTPException(status_code=404, detail="Not saved")
    db.delete(row)
    db.commit()
    return {"saved": False}


# ── GET /saved/  — list saved internships ────────────────────────────────────
@router.get("/", response_model=List[dict])
def list_saved(
    user_id: int = Depends(_current_user_id),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(SavedInternship)
        .filter(SavedInternship.user_id == user_id)
        .order_by(SavedInternship.created_at.desc())
        .all()
    )
    result = []
    for row in rows:
        it = _base_q(db).filter(Internship.id == row.internship_id).first()
        if it:
            d = _to_dict(it)
            d["saved_at"] = row.created_at
            result.append(d)
    return result


# ── GET /saved/ids  — just internship IDs (for UI toggle state) ──────────────
@router.get("/ids", response_model=List[int])
def saved_ids(
    user_id: int = Depends(_current_user_id),
    db: Session = Depends(get_db),
):
    rows = db.query(SavedInternship.internship_id).filter(
        SavedInternship.user_id == user_id
    ).all()
    return [r[0] for r in rows]
