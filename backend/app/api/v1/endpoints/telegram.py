import secrets
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.core.security import create_access_token
from app.models.telegram import TelegramLinkToken, TelegramSession
from app.models.user import User

router = APIRouter(prefix="/telegram", tags=["telegram"])


def _require_internal(x_internal_secret: str = Header(default="")):
    if not settings.TELEGRAM_INTERNAL_SECRET:
        raise HTTPException(status_code=503, detail="Telegram não configurado")
    if not secrets.compare_digest(x_internal_secret, settings.TELEGRAM_INTERNAL_SECRET):
        raise HTTPException(status_code=403, detail="Forbidden")


# ── Endpoints chamados pelo frontend (requer JWT do usuário) ──────────────────


@router.post("/generate-link")
async def generate_link(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not settings.TELEGRAM_BOT_USERNAME:
        raise HTTPException(status_code=503, detail="TELEGRAM_BOT_USERNAME não configurado")

    token = secrets.token_urlsafe(32)
    expires = datetime.now(UTC) + timedelta(minutes=10)
    db.add(TelegramLinkToken(user_id=current_user.id, token=token, expires_at=expires))
    await db.commit()

    return {"url": f"https://t.me/{settings.TELEGRAM_BOT_USERNAME}?start={token}"}


@router.get("/status")
async def link_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(TelegramSession).where(TelegramSession.user_id == current_user.id)
    )
    session = result.scalar_one_or_none()
    return {"linked": session is not None, "linked_at": session.linked_at if session else None}


@router.delete("/unlink", status_code=status.HTTP_204_NO_CONTENT)
async def unlink(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(TelegramSession).where(TelegramSession.user_id == current_user.id)
    )
    session = result.scalar_one_or_none()
    if session:
        await db.delete(session)
        await db.commit()


# ── Endpoints internos (chamados pelo bot, protegidos por secret) ─────────────


@router.post("/confirm-link")
async def confirm_link(
    body: dict,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(_require_internal),
):
    token_value: str = body.get("token", "")
    chat_id: int = int(body.get("chat_id", 0))

    if not token_value or not chat_id:
        raise HTTPException(status_code=400, detail="token e chat_id são obrigatórios")

    result = await db.execute(
        select(TelegramLinkToken).where(TelegramLinkToken.token == token_value)
    )
    link_token = result.scalar_one_or_none()

    if not link_token:
        raise HTTPException(status_code=404, detail="Token não encontrado")
    if link_token.used:
        raise HTTPException(status_code=410, detail="Token já utilizado")
    if datetime.now(UTC) > link_token.expires_at.replace(tzinfo=UTC):
        raise HTTPException(status_code=410, detail="Token expirado")

    # Remove vínculo anterior desse chat_id se existir
    old = await db.execute(
        select(TelegramSession).where(TelegramSession.telegram_chat_id == chat_id)
    )
    old_session = old.scalar_one_or_none()
    if old_session:
        await db.delete(old_session)

    db.add(TelegramSession(user_id=link_token.user_id, telegram_chat_id=chat_id))
    link_token.used = True
    await db.commit()

    return {"ok": True, "user_id": link_token.user_id}


@router.post("/resolve-user")
async def resolve_user(
    body: dict,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(_require_internal),
):
    chat_id: int = int(body.get("chat_id", 0))
    if not chat_id:
        raise HTTPException(status_code=400, detail="chat_id é obrigatório")

    result = await db.execute(
        select(TelegramSession).where(TelegramSession.telegram_chat_id == chat_id)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Usuário não vinculado")

    token = create_access_token(session.user_id)
    return {"token": token}
