"""AI assistant endpoint — proxies to Groq (Llama 3.3) API with conversation persistence."""
import os
from pathlib import Path
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException, Depends

# Explicit path: backend/app/routes/ai.py → backend/.env
load_dotenv(Path(__file__).resolve().parents[2] / ".env", override=True)
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import List, Optional
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.db import get_db
from app.auth import decode_access_token
from app.users import get_user_by_id
from app.models import Internship, AiConversation, AiMessage, InternshipSkill

router = APIRouter()
security = HTTPBearer(auto_error=False)

GROQ_MODEL = "llama-3.3-70b-versatile"

def _get_groq_key() -> str:
    return os.getenv("GROQ_API_KEY", "")

BASE_SYSTEM_PROMPT = """Ты — Qadam AI, умный карьерный ассистент платформы Qadam (Казахстан).

## О платформе Qadam
Qadam — это платформа для поиска стажировок для студентов Казахстана.
- Студенты регистрируются, заполняют профиль (специальность, навыки, CV) и подают заявки на стажировки
- Компании публикуют вакансии стажировок и просматривают заявки
- Университеты мониторят своих студентов и их трудоустройство
- Платформа охватывает все крупные города: Алматы, Астана, Шымкент, Атырау, Актобе, Костанай, Павлодар, Семей и другие
- Категории стажировок: IT, Финансы, Маркетинг, Дизайн, Право, Инженерия, Медицина, Образование и другие

## Функции платформы
- **Лента стажировок** — поиск по городу, формату (офис/удалённо/гибрид), зарплате, категории
- **Избранное** — сохранение интересных вакансий
- **Мои заявки** — отслеживание статусов: Подана → Просмотрено → Собеседование → Оффер → Принят
- **AI ассистент** — ты сам! Помогаешь с резюме, подготовкой к собеседованиям, выбором карьеры
- **Профиль** — загрузка CV, указание навыков, университета, специальности

## Что ты умеешь
- Помогать составить резюме и сопроводительное письмо под конкретную вакансию
- Готовить к собеседованию: типичные вопросы, советы по ответам
- Рекомендовать навыки для развития по специальности
- Объяснять как работает рынок стажировок в Казахстане
- Анализировать профиль студента и давать советы по улучшению
- Помогать выбрать специальность или направление карьеры
- Отвечать на вопросы о платформе Qadam

## Правила общения
- Отвечай на том языке на котором пишет пользователь (русский, казахский или английский)
- Будь дружелюбным, конкретным и полезным — как старший друг-ментор
- Если знаешь данные пользователя из контекста — используй их в ответах
- Не выдумывай конкретные компании или зарплаты если они не указаны в контексте
- Структурируй длинные ответы с помощью списков и заголовков"""


def _build_system_prompt(db: Session, user_id: Optional[int]) -> str:
    """Build system prompt enriched with live platform data and user context."""
    parts = [BASE_SYSTEM_PROMPT]

    # --- Live platform stats from DB ---
    try:
        from app.models import Internship as InternshipModel, Application
        total = db.query(InternshipModel).filter(InternshipModel.is_active == True).count()
        paid_count = db.query(InternshipModel).filter(
            InternshipModel.is_active == True,
            InternshipModel.paid == True,
        ).count()

        # Top cities
        from sqlalchemy import func
        cities_q = (
            db.query(InternshipModel.city, func.count().label("n"))
            .filter(InternshipModel.is_active == True, InternshipModel.city != "")
            .group_by(InternshipModel.city)
            .order_by(func.count().desc())
            .limit(5)
            .all()
        )
        cities_str = ", ".join(f"{r.city} ({r.n})" for r in cities_q) if cities_q else "нет данных"

        # Top categories
        cats_q = (
            db.query(InternshipModel.category, func.count().label("n"))
            .filter(InternshipModel.is_active == True, InternshipModel.category != None)
            .group_by(InternshipModel.category)
            .order_by(func.count().desc())
            .limit(5)
            .all()
        )
        cats_str = ", ".join(f"{r.category} ({r.n})" for r in cats_q) if cats_q else "нет данных"

        parts.append(
            f"\n## Текущие данные платформы (живые)\n"
            f"- Активных стажировок сейчас: {total}\n"
            f"- Из них с оплатой: {paid_count}\n"
            f"- Топ города: {cities_str}\n"
            f"- Топ категории: {cats_str}"
        )
    except Exception:
        db.rollback()

    # --- User context ---
    if user_id:
        try:
            user = get_user_by_id(db, user_id)
            if user:
                from app.models import Application
                apps = db.query(Application).filter(Application.user_id == user_id).all()
                app_statuses = {}
                for a in apps:
                    app_statuses[a.status] = app_statuses.get(a.status, 0) + 1

                # Skills
                skills_list = []
                try:
                    if user.skill_links:
                        skills_list = [sl.skill.name for sl in user.skill_links if sl.skill]
                except Exception:
                    skills_list = list(user.skills or [])

                # University & specialty
                specialty = getattr(user, "specialty", None) or ""
                uni_name = getattr(user, "university_name", None) or ""
                try:
                    link = user.university_link
                    if link:
                        specialty = specialty or getattr(link, "specialty", "") or ""
                        if link.university:
                            uni_name = uni_name or link.university.name
                except Exception:
                    pass

                user_lines = [f"\n## Профиль текущего студента", f"- Имя: {user.name}"]
                if uni_name:
                    user_lines.append(f"- Университет: {uni_name}")
                if specialty:
                    user_lines.append(f"- Специальность: {specialty}")
                if skills_list:
                    user_lines.append(f"- Навыки: {', '.join(skills_list[:10])}")
                if user.cv_url:
                    user_lines.append("- CV: загружен")
                else:
                    user_lines.append("- CV: не загружен (рекомендуй загрузить)")
                if app_statuses:
                    apps_summary = ", ".join(f"{s}: {n}" for s, n in app_statuses.items())
                    user_lines.append(f"- Заявки: {apps_summary}")
                else:
                    user_lines.append("- Заявок ещё нет (рекомендуй подать первую)")

                parts.append("\n".join(user_lines))
        except Exception:
            db.rollback()

    return "\n".join(parts)


class ChatMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    specialty: Optional[str] = None
    conversation_id: Optional[int] = None


class InternshipContextRequest(BaseModel):
    internship_id: int


def _get_user_id(credentials, db):
    """Extract user_id from JWT token, return None if not authenticated."""
    if not credentials:
        return None
    payload = decode_access_token(credentials.credentials)
    if payload and payload.get("user_id"):
        return payload["user_id"]
    return None


def _get_or_create_conversation(db: Session, user_id: int, conversation_id: Optional[int], first_user_message: str) -> AiConversation:
    """Get existing conversation or create a new one."""
    if conversation_id:
        conv = db.query(AiConversation).filter(
            AiConversation.id == conversation_id,
            AiConversation.user_id == user_id,
        ).first()
        if conv:
            return conv

    title = first_user_message[:60] + ("..." if len(first_user_message) > 60 else "")
    conv = AiConversation(user_id=user_id, title=title)
    db.add(conv)
    db.flush()
    return conv


def _call_groq(system: str, messages: list[dict]) -> str:
    """
    Call Groq API.
    messages: list of {"role": "user"|"assistant", "content": str}
    """
    api_key = _get_groq_key()
    if not api_key:
        raise HTTPException(status_code=503, detail="AI assistant is not configured. Add GROQ_API_KEY to environment variables.")
    try:
        from groq import Groq
        client = Groq(api_key=api_key)
        response = client.chat.completions.create(
            model=GROQ_MODEL,
            max_tokens=1024,
            messages=[{"role": "system", "content": system}] + messages,
        )
        return response.choices[0].message.content
    except ImportError:
        raise HTTPException(status_code=503, detail="groq package not installed")
    except Exception as e:
        msg = str(e)
        if "429" in msg or "rate_limit" in msg.lower():
            raise HTTPException(status_code=429, detail="Превышен лимит запросов к AI. Попробуйте позже.")
        if "invalid_api_key" in msg.lower() or "401" in msg:
            raise HTTPException(status_code=503, detail="Неверный API ключ. Проверьте GROQ_API_KEY.")
        raise HTTPException(status_code=500, detail="Ошибка AI сервиса. Попробуйте позже.")


def _call_groq_single(system: str, user_prompt: str) -> str:
    """Single-turn Groq call for contextual features."""
    return _call_groq(system, [{"role": "user", "content": user_prompt}])


@router.post("/chat")
def ai_chat(
    body: ChatRequest,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db),
):
    user_id = _get_user_id(credentials, db)
    system = _build_system_prompt(db, user_id)
    messages = [{"role": m.role, "content": m.content} for m in body.messages]
    reply = _call_groq(system, messages)

    # Persist conversation for authenticated users
    conv_id = None
    if user_id and body.messages:
        last_user_msg = next(
            (m.content for m in reversed(body.messages) if m.role == "user"), ""
        )
        conv = _get_or_create_conversation(db, user_id, body.conversation_id, last_user_msg)
        conv_id = conv.id

        if not body.conversation_id:
            for m in body.messages:
                db.add(AiMessage(conversation_id=conv_id, role=m.role, content=m.content))
        else:
            if last_user_msg:
                db.add(AiMessage(conversation_id=conv_id, role="user", content=last_user_msg))

        db.add(AiMessage(conversation_id=conv_id, role="assistant", content=reply))
        db.commit()

    return {"reply": reply, "conversation_id": conv_id}


@router.get("/conversations")
def list_conversations(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    user_id = _get_user_id(credentials, db)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")

    convs = (
        db.query(AiConversation)
        .filter(AiConversation.user_id == user_id)
        .order_by(AiConversation.updated_at.desc())
        .all()
    )

    result = []
    for c in convs:
        last_msg = (
            db.query(AiMessage)
            .filter(AiMessage.conversation_id == c.id, AiMessage.role == "assistant")
            .order_by(AiMessage.created_at.desc())
            .first()
        )
        result.append({
            "id": c.id,
            "title": c.title,
            "created_at": c.created_at.isoformat(),
            "updated_at": c.updated_at.isoformat(),
            "last_message": last_msg.content[:120] if last_msg else None,
        })

    return result


@router.get("/conversations/{conversation_id}")
def get_conversation(
    conversation_id: int,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    user_id = _get_user_id(credentials, db)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")

    conv = db.query(AiConversation).filter(
        AiConversation.id == conversation_id,
        AiConversation.user_id == user_id,
    ).first()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    messages = (
        db.query(AiMessage)
        .filter(AiMessage.conversation_id == conversation_id)
        .order_by(AiMessage.created_at)
        .all()
    )

    return {
        "id": conv.id,
        "title": conv.title,
        "created_at": conv.created_at.isoformat(),
        "messages": [
            {"role": m.role, "content": m.content, "created_at": m.created_at.isoformat()}
            for m in messages
        ],
    }


@router.delete("/conversations/{conversation_id}")
def delete_conversation(
    conversation_id: int,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    user_id = _get_user_id(credentials, db)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")

    conv = db.query(AiConversation).filter(
        AiConversation.id == conversation_id,
        AiConversation.user_id == user_id,
    ).first()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    db.delete(conv)
    db.commit()
    return {"ok": True}


# ── Contextual AI helpers ──────────────────────────────────────────────────────

def _get_university_name(user) -> str:
    try:
        link = user.university_link
        if link and link.university:
            return link.university.name
    except Exception:
        pass
    return getattr(user, "university_name", None) or ""


def _get_specialty(user) -> str:
    try:
        link = user.university_link
        if link and link.specialty:
            return link.specialty
    except Exception:
        pass
    return getattr(user, "specialty", None) or ""


def _get_user_skills_list(user) -> list:
    try:
        if user.skill_links:
            return [sl.skill.name for sl in user.skill_links if sl.skill]
    except Exception:
        pass
    return list(user.skills or [])


def _get_internship_context(internship_id: int, db: Session) -> dict:
    it = (
        db.query(Internship)
        .options(joinedload(Internship.skill_links).joinedload(InternshipSkill.skill))
        .filter(Internship.id == internship_id)
        .first()
    )
    if not it:
        raise HTTPException(status_code=404, detail="Internship not found")
    skills = [sl.skill.name for sl in it.skill_links if sl.skill] if it.skill_links else (it.skills or [])
    return {
        "title": it.title,
        "company": it.company,
        "description": it.description or "",
        "skills": skills,
        "requirements": it.requirements or [],
        "responsibilities": it.responsibilities or [],
        "category": it.category,
    }


# ── POST /ai/cover-letter ──────────────────────────────────────────────────────

@router.post("/cover-letter")
def generate_cover_letter(
    body: InternshipContextRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    user_id = _get_user_id(credentials, db)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")

    user = get_user_by_id(db, user_id)
    internship = _get_internship_context(body.internship_id, db)

    specialty = _get_specialty(user)
    university = _get_university_name(user)
    user_skills = _get_user_skills_list(user)

    user_info = f"Студент: {user.name}"
    if specialty:
        user_info += f", специальность: {specialty}"
    if university:
        user_info += f", университет: {university}"
    if user_skills:
        user_info += f", навыки: {', '.join(user_skills[:8])}"

    system = (
        "Ты помогаешь студентам Казахстана писать сопроводительные письма. "
        "Пиши на русском языке. Письмо должно быть:\n"
        "- Длиной 150–200 слов\n"
        "- Конкретным: упоминай название компании и должности\n"
        "- Живым и искренним, не шаблонным\n"
        "- Подчёркивать совпадение навыков студента с требованиями\n"
        "Начинай с обращения 'Уважаемая команда [Компания],' и заканчивай подписью."
    )

    prompt = (
        f"{user_info}\n\n"
        f"Вакансия: {internship['title']} в {internship['company']}\n"
        f"Описание: {internship['description'][:300]}\n"
        f"Требуемые навыки: {', '.join(internship['skills'][:10])}\n\n"
        "Напиши сопроводительное письмо для этой стажировки."
    )

    result = _call_groq_single(system, prompt)
    return {"cover_letter": result, "internship_title": internship["title"], "company": internship["company"]}


# ── POST /ai/interview-prep ────────────────────────────────────────────────────

@router.post("/interview-prep")
def generate_interview_prep(
    body: InternshipContextRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    user_id = _get_user_id(credentials, db)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")

    internship = _get_internship_context(body.internship_id, db)

    system = (
        "Ты карьерный коуч для студентов Казахстана. Отвечай на русском языке. "
        "Давай конкретные, практичные советы. Формат — структурированный список."
    )

    prompt = (
        f"Вакансия: {internship['title']} в {internship['company']} (категория: {internship['category']})\n"
        f"Требования: {', '.join(internship['requirements'][:6])}\n"
        f"Навыки: {', '.join(internship['skills'][:8])}\n\n"
        "Составь план подготовки к собеседованию:\n"
        "1. Топ-7 вопросов которые скорее всего зададут (с краткими подсказками ответа)\n"
        "2. Что нужно изучить о компании (3 пункта)\n"
        "3. Что взять на собеседование (2–3 пункта)\n"
        "4. Один совет который выделит кандидата среди других\n"
    )

    result = _call_groq_single(system, prompt)
    return {"prep_guide": result, "internship_title": internship["title"], "company": internship["company"]}


# ── POST /ai/skill-gap ─────────────────────────────────────────────────────────

@router.post("/skill-gap")
def analyze_skill_gap(
    body: InternshipContextRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    user_id = _get_user_id(credentials, db)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")

    user = get_user_by_id(db, user_id)
    internship = _get_internship_context(body.internship_id, db)

    user_skills = _get_user_skills_list(user)

    required = set(s.lower() for s in internship["skills"])
    user_set = set(s.lower() for s in user_skills)
    matched = required & user_set
    missing = required - user_set

    system = (
        "Ты карьерный консультант. Отвечай кратко на русском языке. "
        "Давай конкретные ресурсы (курсы, платформы) для изучения навыков."
    )

    prompt = (
        f"Вакансия: {internship['title']} в {internship['company']}\n"
        f"Требуемые навыки: {', '.join(internship['skills'][:10])}\n"
        f"Навыки студента: {', '.join(user_skills[:10]) if user_skills else 'не указаны'}\n"
        f"Совпадающие навыки: {', '.join(matched) if matched else 'нет'}\n"
        f"Недостающие навыки: {', '.join(missing) if missing else 'нет'}\n\n"
        "Составь план:\n"
        "1. Оценка шансов (1 предложение)\n"
        "2. Топ-3 навыка которые нужно прокачать (с конкретными ресурсами: курс/платформа)\n"
        "3. Что уже есть и как это подчеркнуть в резюме\n"
        "4. Сколько времени нужно для подготовки (реалистично)\n"
    )

    result = _call_groq_single(system, prompt)
    return {
        "analysis": result,
        "matched_skills": sorted(matched),
        "missing_skills": sorted(missing),
        "match_percent": int(len(matched) / len(required) * 100) if required else 70,
    }


# ── POST /ai/profile-analysis ─────────────────────────────────────────────────

@router.post("/profile-analysis")
def analyze_profile(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    user_id = _get_user_id(credentials, db)
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")

    user = get_user_by_id(db, user_id)

    university = _get_university_name(user)
    specialty = _get_specialty(user)
    user_skills = _get_user_skills_list(user)

    fields = {
        "photo": bool(user.avatar_url),
        "university": bool(university),
        "specialty": bool(specialty),
        "skills": len(user_skills) >= 3,
        "bio": bool(user.bio),
        "cv": bool(user.cv_url),
    }
    weights = {"photo": 10, "university": 15, "specialty": 15, "skills": 25, "bio": 15, "cv": 20}
    score = sum(weights[k] for k, v in fields.items() if v)
    missing_fields = [k for k, v in fields.items() if not v]

    system = "Ты карьерный консультант для студентов. Отвечай кратко и по-дружески на русском."

    prompt = (
        f"Профиль студента:\n"
        f"- Имя: {user.name}\n"
        f"- Специальность: {specialty or 'не указана'}\n"
        f"- Университет: {university or 'не указан'}\n"
        f"- Навыки: {', '.join(user_skills[:10]) if user_skills else 'не указаны'}\n"
        f"- CV загружен: {'да' if fields['cv'] else 'нет'}\n"
        f"- Заполненность профиля: {score}%\n\n"
        "Дай краткий анализ (4–5 предложений):\n"
        "1. Что сильного в профиле\n"
        "2. Главный пробел который снижает шансы\n"
        "3. Конкретный следующий шаг который улучшит профиль больше всего\n"
    )

    result = _call_groq_single(system, prompt)
    return {
        "analysis": result,
        "score": score,
        "missing_fields": missing_fields,
        "completed_fields": [k for k, v in fields.items() if v],
    }
