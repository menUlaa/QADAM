"""AI assistant endpoint — proxies to Anthropic Claude API."""
import os
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import List, Optional
from sqlalchemy.orm import Session

from app.db import get_db
from app.auth import decode_access_token
from app.users import get_user_by_id
from app.models import Internship

router = APIRouter()
security = HTTPBearer(auto_error=False)

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")

SYSTEM_PROMPT = """Ты — AI-ассистент платформы Qadam, помогающий студентам Казахстана найти стажировку.

Ты умеешь:
- Давать советы по составлению резюме и сопроводительных писем
- Объяснять как пройти собеседование
- Рекомендовать какие навыки развивать для конкретной профессии
- Рассказывать о компаниях и индустриях в Казахстане
- Помогать выбрать специальность или направление карьеры

Отвечай кратко, по-дружески, на том языке на котором пишет пользователь (русский или казахский).
Не выдумывай конкретные данные о зарплатах или вакансиях — только общие рекомендации."""


class ChatMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    specialty: Optional[str] = None


@router.post("/chat")
def ai_chat(
    body: ChatRequest,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db),
):
    if not ANTHROPIC_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="AI assistant is not configured. Add ANTHROPIC_API_KEY to environment variables.",
        )

    # Optionally personalize with user context
    system = SYSTEM_PROMPT
    if credentials:
        payload = decode_access_token(credentials.credentials)
        if payload and payload.get("user_id"):
            user = get_user_by_id(db, payload["user_id"])
            if user and user.specialty:
                system += f"\n\nПользователь: {user.name}, специальность: {user.specialty}, университет: {user.university_name or 'не указан'}."

    try:
        import anthropic
        client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
        response = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=1024,
            system=system,
            messages=[{"role": m.role, "content": m.content} for m in body.messages],
        )
        reply = response.content[0].text
        return {"reply": reply}
    except ImportError:
        raise HTTPException(status_code=503, detail="anthropic package not installed")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
