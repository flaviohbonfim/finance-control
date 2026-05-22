import base64
import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import RedirectResponse
from jose import jwt
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.oauth import OAuthCode
from app.models.user import User

router = APIRouter(prefix="/oauth", tags=["oauth"])

_CODE_TTL = timedelta(minutes=5)
_SUPPORTED_CLIENT_ID = "finance-control-mcp"


def _now() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode()).hexdigest()


def _verify_pkce(code_verifier: str, code_challenge: str) -> bool:
    digest = hashlib.sha256(code_verifier.encode()).digest()
    computed = base64.urlsafe_b64encode(digest).rstrip(b"=").decode()
    return computed == code_challenge


def _create_mcp_access_token(user_id: int) -> str:
    expire = _now() + timedelta(days=settings.MCP_ACCESS_TOKEN_EXPIRE_DAYS)
    return jwt.encode(
        {"sub": str(user_id), "exp": expire},
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )


def _create_mcp_refresh_token(user_id: int) -> str:
    expire = _now() + timedelta(days=settings.MCP_REFRESH_TOKEN_EXPIRE_DAYS)
    return jwt.encode(
        {"sub": str(user_id), "type": "mcp_refresh", "exp": expire},
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )


# ── GET /oauth/authorize ──────────────────────────────────────────────────────


@router.get("/authorize")
async def authorize(
    response_type: str = "",
    client_id: str = "",
    redirect_uri: str = "",
    state: str = "",
    code_challenge: str = "",
    code_challenge_method: str = "",
):
    if response_type != "code":
        raise HTTPException(status_code=400, detail="response_type must be 'code'")
    if not redirect_uri:
        raise HTTPException(status_code=400, detail="redirect_uri required")
    if not state:
        raise HTTPException(status_code=400, detail="state required")
    if not code_challenge:
        raise HTTPException(status_code=400, detail="code_challenge required (PKCE)")
    if code_challenge_method != "S256":
        raise HTTPException(status_code=400, detail="code_challenge_method must be S256")

    params = urlencode(
        {
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "state": state,
            "code_challenge": code_challenge,
            "code_challenge_method": code_challenge_method,
        }
    )
    return RedirectResponse(
        url=f"{settings.FRONTEND_URL}/oauth/authorize?{params}",
        status_code=302,
    )


# ── POST /oauth/confirm ───────────────────────────────────────────────────────


class OAuthConfirmRequest(BaseModel):
    client_id: str
    redirect_uri: str
    state: str
    code_challenge: str
    code_challenge_method: str


@router.post("/confirm")
async def confirm(
    payload: OAuthConfirmRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if payload.code_challenge_method != "S256":
        raise HTTPException(status_code=400, detail="code_challenge_method must be S256")

    raw_code = secrets.token_urlsafe(32)
    record = OAuthCode(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        code_hash=_hash_code(raw_code),
        code_challenge=payload.code_challenge,
        redirect_uri=payload.redirect_uri,
        expires_at=_now() + _CODE_TTL,
        used=False,
    )
    db.add(record)
    await db.commit()

    params = urlencode({"code": raw_code, "state": payload.state})
    return {"redirect_url": f"{payload.redirect_uri}?{params}"}


# ── POST /oauth/token ─────────────────────────────────────────────────────────


class OAuthTokenRequest(BaseModel):
    grant_type: str
    code: str | None = None
    redirect_uri: str | None = None
    code_verifier: str | None = None
    client_id: str | None = None
    refresh_token: str | None = None


@router.post("/token")
async def token(
    payload: OAuthTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    if payload.grant_type == "authorization_code":
        return await _exchange_code(payload, db)
    if payload.grant_type == "refresh_token":
        return await _refresh(payload)
    raise HTTPException(status_code=400, detail="unsupported grant_type")


async def _exchange_code(payload: OAuthTokenRequest, db: AsyncSession):
    if not payload.code or not payload.redirect_uri or not payload.code_verifier:
        raise HTTPException(status_code=400, detail="code, redirect_uri and code_verifier required")

    code_hash = _hash_code(payload.code)
    result = await db.execute(select(OAuthCode).where(OAuthCode.code_hash == code_hash))
    record = result.scalar_one_or_none()

    now = _now()
    if not record or record.used or record.expires_at < now:
        raise HTTPException(status_code=400, detail="invalid or expired code")
    if record.redirect_uri != payload.redirect_uri:
        raise HTTPException(status_code=400, detail="redirect_uri mismatch")
    if not _verify_pkce(payload.code_verifier, record.code_challenge):
        raise HTTPException(status_code=400, detail="invalid code_verifier")

    record.used = True
    await db.commit()

    return {
        "access_token": _create_mcp_access_token(record.user_id),
        "refresh_token": _create_mcp_refresh_token(record.user_id),
        "token_type": "bearer",
        "expires_in": settings.MCP_ACCESS_TOKEN_EXPIRE_DAYS * 86400,
    }


async def _refresh(payload: OAuthTokenRequest):
    if not payload.refresh_token:
        raise HTTPException(status_code=400, detail="refresh_token required")
    try:
        data = jwt.decode(
            payload.refresh_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        if data.get("type") != "mcp_refresh":
            raise ValueError
        user_id = int(data["sub"])
    except Exception:
        raise HTTPException(status_code=401, detail="invalid refresh_token")

    return {
        "access_token": _create_mcp_access_token(user_id),
        "refresh_token": _create_mcp_refresh_token(user_id),
        "token_type": "bearer",
        "expires_in": settings.MCP_ACCESS_TOKEN_EXPIRE_DAYS * 86400,
    }
