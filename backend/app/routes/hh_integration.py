"""HH.kz vacancy proxy with OAuth2 Client Credentials token caching. v3"""
import os
import time
import logging
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[2] / ".env", override=True)

import httpx
from fastapi import APIRouter, HTTPException

router = APIRouter()
logger = logging.getLogger(__name__)

HH_TOKEN_URL = "https://hh.ru/oauth/token"
HH_API_URL   = "https://api.hh.ru/vacancies"

_CLIENT_ID     = os.getenv("HH_CLIENT_ID", "")
_CLIENT_SECRET = os.getenv("HH_CLIENT_SECRET", "")
_USER_AGENT    = "Qadam/1.0 (karimovula06@gmail.com)"

# Seed cache from .env if a token was pre-stored (avoids "refresh too early")
_token_cache: dict = {
    "access_token": os.getenv("HH_ACCESS_TOKEN") or None,
    "expires_at":   time.time() + 1_209_600 if os.getenv("HH_ACCESS_TOKEN") else 0.0,
}


async def _get_access_token() -> str:
    now = time.time()
    if _token_cache["access_token"] and now < _token_cache["expires_at"] - 60:
        return _token_cache["access_token"]

    if not _CLIENT_ID or not _CLIENT_SECRET:
        raise HTTPException(status_code=503, detail="HH_CLIENT_ID / HH_CLIENT_SECRET not configured")

    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(
            HH_TOKEN_URL,
            data={
                "grant_type":    "client_credentials",
                "client_id":     _CLIENT_ID,
                "client_secret": _CLIENT_SECRET,
            },
            headers={
                "Content-Type": "application/x-www-form-urlencoded",
                "User-Agent":   _USER_AGENT,
            },
        )

        if resp.status_code != 200:
            body = resp.json()
            # "refresh too early" = existing token is still valid, reuse it
            if "refresh" in body.get("error_description", "").lower():
                existing = os.getenv("HH_ACCESS_TOKEN")
                if existing:
                    logger.info("HH token still valid, reusing from env")
                    _token_cache["access_token"] = existing
                    _token_cache["expires_at"]   = time.time() + 1_209_600
                    return existing
            logger.error("HH token error %s: %s", resp.status_code, resp.text)
            raise HTTPException(
                status_code=502,
                detail=f"HH.kz auth failed ({resp.status_code}): {resp.text[:200]}",
            )

        data = resp.json()

    token      = data["access_token"]
    expires_in = data.get("expires_in", 1_209_600)

    _token_cache["access_token"] = token
    _token_cache["expires_at"]   = time.time() + expires_in
    logger.info("HH token refreshed, expires in %ds", expires_in)
    return token


@router.get("/external/{hh_id}")
async def get_hh_vacancy_detail(hh_id: str):
    """Fetch full vacancy details from HH API including description."""
    token = await _get_access_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent":    _USER_AGENT,
        "HH-User-Agent": _USER_AGENT,
    }
    try:
        async with httpx.AsyncClient(timeout=12.0) as client:
            resp = await client.get(
                f"https://api.hh.ru/vacancies/{hh_id}",
                headers=headers,
            )
            resp.raise_for_status()
            d = resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=502, detail=f"HH returned {e.response.status_code}")
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"HH unreachable: {e}")

    import re
    def strip_html(html: str) -> str:
        return re.sub(r"<[^>]+>", "", html or "").strip()

    description = strip_html(d.get("description", ""))
    skills = [s["name"] for s in d.get("key_skills", [])]
    salary = d.get("salary")

    return {
        "id":           d["id"],
        "title":        d["name"],
        "company":      d["employer"]["name"],
        "company_logo": (d["employer"].get("logo_urls") or {}).get("90"),
        "city":         d["area"]["name"],
        "description":  description,
        "skills":       skills,
        "salary_from":  salary["from"]     if salary else None,
        "salary_to":    salary["to"]       if salary else None,
        "currency":     salary["currency"] if salary else "KZT",
        "format":       (d.get("schedule")    or {}).get("name", ""),
        "experience":   (d.get("experience")  or {}).get("name", ""),
        "employment":   (d.get("employment")  or {}).get("name", ""),
        "published_at": d.get("published_at"),
        "url":          d.get("alternate_url"),
    }


@router.get("/external")
async def get_hh_vacancies(
    text:       str = "",
    area:       int = 40,
    per_page:   int = 20,
    page:       int = 0,
    experience: str = "noExperience",
):
    token = await _get_access_token()

    params = {
        "text":         text if text else "стажёр OR стажировка OR intern OR trainee OR \"без опыта\"",
        "area":         area,
        "per_page":     per_page,
        "page":         page,
        "experience":   "noExperience",
        "search_field": "name",
        "currency":     "KZT",
        "order_by":     "publication_time",
    }
    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent":    _USER_AGENT,
        "HH-User-Agent": _USER_AGENT,
    }

    try:
        async with httpx.AsyncClient(timeout=12.0) as client:
            resp = await client.get(HH_API_URL, params=params, headers=headers)
            if resp.status_code == 403:
                # Token expired — clear and retry once
                _token_cache["access_token"] = None
                _token_cache["expires_at"]   = 0.0
                new_token = await _get_access_token()
                headers["Authorization"] = f"Bearer {new_token}"
                resp = await client.get(HH_API_URL, params=params, headers=headers)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=502, detail=f"HH.kz returned {e.response.status_code}")
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"HH.kz unreachable: {e}")

    vacancies = []
    for item in data.get("items", []):
        salary = item.get("salary")
        vacancies.append({
            "id":           f"hh_{item['id']}",
            "source":       "hh",
            "title":        item["name"],
            "company":      item["employer"]["name"],
            "company_logo": (item["employer"].get("logo_urls") or {}).get("90"),
            "city":         item["area"]["name"],
            "salary_from":  salary["from"]     if salary else None,
            "salary_to":    salary["to"]       if salary else None,
            "currency":     salary["currency"] if salary else "KZT",
            "format":       (item.get("schedule")   or {}).get("name", ""),
            "experience":   (item.get("experience") or {}).get("name", ""),
            "url":          item["alternate_url"],
            "published_at": item["published_at"],
            "is_external":  True,
        })

    return {
        "items":    vacancies,
        "total":    data.get("found", 0),
        "page":     page,
        "per_page": per_page,
    }
