"""Notifications endpoints."""
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from app.db import get_db
from app.models import Notification
from app.auth import decode_access_token

router = APIRouter()
security = HTTPBearer()


def _current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> int:
    payload = decode_access_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    return payload["user_id"]


def _notif_to_dict(n: Notification) -> dict:
    return {
        "id": n.id,
        "type": n.type,
        "title": n.title,
        "body": n.body,
        "is_read": n.is_read,
        "related_internship_id": n.related_internship_id,
        "related_application_id": n.related_application_id,
        "created_at": n.created_at,
    }


# ── GET /notifications/  ──────────────────────────────────────────────────────
@router.get("/", response_model=List[dict])
def list_notifications(
    unread_only: bool = False,
    limit: int = 50,
    user_id: int = Depends(_current_user_id),
    db: Session = Depends(get_db),
):
    q = db.query(Notification).filter(Notification.user_id == user_id)
    if unread_only:
        q = q.filter(Notification.is_read == False)
    notifications = q.order_by(Notification.created_at.desc()).limit(limit).all()
    return [_notif_to_dict(n) for n in notifications]


# ── GET /notifications/unread-count  ─────────────────────────────────────────
@router.get("/unread-count", response_model=dict)
def unread_count(
    user_id: int = Depends(_current_user_id),
    db: Session = Depends(get_db),
):
    count = db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.is_read == False,
    ).count()
    return {"count": count}


# ── POST /notifications/{id}/read  ───────────────────────────────────────────
@router.post("/{notification_id}/read", response_model=dict)
def mark_read(
    notification_id: int,
    user_id: int = Depends(_current_user_id),
    db: Session = Depends(get_db),
):
    n = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == user_id,
    ).first()
    if not n:
        raise HTTPException(status_code=404, detail="Notification not found")
    n.is_read = True
    db.commit()
    return {"ok": True}


# ── POST /notifications/read-all  ────────────────────────────────────────────
@router.post("/read-all", response_model=dict)
def mark_all_read(
    user_id: int = Depends(_current_user_id),
    db: Session = Depends(get_db),
):
    db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.is_read == False,
    ).update({"is_read": True})
    db.commit()
    return {"ok": True}


# ── Helper used by other routes to create notifications ───────────────────────
def create_notification(
    db: Session,
    user_id: int,
    type: str,
    title: str,
    body: Optional[str] = None,
    related_internship_id: Optional[int] = None,
    related_application_id: Optional[int] = None,
):
    n = Notification(
        user_id=user_id,
        type=type,
        title=title,
        body=body,
        related_internship_id=related_internship_id,
        related_application_id=related_application_id,
    )
    db.add(n)
    # Don't commit here — caller controls transaction
    return n
