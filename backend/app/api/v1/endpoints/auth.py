import asyncio
import secrets
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.core.security import create_access_token, hash_password, verify_password
from app.models.user import User
from app.schemas.user import (
    ForgotPasswordRequest,
    GoogleAuthRequest,
    ResendVerificationRequest,
    ResetPasswordRequest,
    Token,
    UserChangePassword,
    UserCreate,
    UserLogin,
    UserOut,
    UserUpdate,
    VerifyEmailRequest,
)
from app.services.email_service import send_reset_code, send_verification_code

router = APIRouter(prefix="/auth", tags=["auth"])

_CODE_TTL = timedelta(minutes=15)
_RESEND_COOLDOWN = timedelta(seconds=60)


def _generate_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _now() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
async def register(payload: UserCreate, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email já cadastrado")

    if len(payload.password) < 6:
        raise HTTPException(status_code=400, detail="Senha deve ter no mínimo 6 caracteres")

    code = _generate_code()
    user = User(
        name=payload.name,
        email=payload.email,
        hashed_password=hash_password(payload.password),
        is_verified=False,
        verification_code=code,
        verification_code_expires_at=_now() + _CODE_TTL,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    await send_verification_code(user.email, user.name, code)

    token = create_access_token(user.id)
    return Token(access_token=token, user=UserOut.model_validate(user))


@router.post("/verify-email", status_code=status.HTTP_204_NO_CONTENT)
async def verify_email(
    payload: VerifyEmailRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    now = _now()
    if (
        not user
        or user.is_verified
        or user.verification_code != payload.code
        or user.verification_code_expires_at is None
        or user.verification_code_expires_at < now
    ):
        raise HTTPException(status_code=400, detail="Código inválido ou expirado")

    user.is_verified = True
    user.verification_code = None
    user.verification_code_expires_at = None
    await db.commit()


@router.post("/resend-verification", status_code=status.HTTP_204_NO_CONTENT)
async def resend_verification(
    payload: ResendVerificationRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    # Responde 204 mesmo se email não existir — não revela cadastros
    if not user or user.is_verified:
        return

    now = _now()
    # Cooldown: não reenviar se o código atual ainda não expirou o cooldown
    if user.verification_code_expires_at is not None and user.verification_code_expires_at > now + (
        _CODE_TTL - _RESEND_COOLDOWN
    ):
        raise HTTPException(status_code=429, detail="Aguarde antes de solicitar novo código")

    code = _generate_code()
    user.verification_code = code
    user.verification_code_expires_at = now + _CODE_TTL
    await db.commit()

    await send_verification_code(user.email, user.name, code)


@router.post("/forgot-password", status_code=status.HTTP_204_NO_CONTENT)
async def forgot_password(
    payload: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    # Sempre 204 — não revela se o email está cadastrado
    if not user or not user.is_verified:
        return

    now = _now()
    # Cooldown: não reenviar se o código atual ainda não expirou o cooldown
    if (
        user.reset_password_code_expires_at is not None
        and user.reset_password_code_expires_at > now + (_CODE_TTL - _RESEND_COOLDOWN)
    ):
        raise HTTPException(status_code=429, detail="Aguarde antes de solicitar novo código")

    code = _generate_code()
    user.reset_password_code = code
    user.reset_password_code_expires_at = now + _CODE_TTL
    await db.commit()

    await send_reset_code(user.email, user.name, code)


@router.post("/reset-password", status_code=status.HTTP_204_NO_CONTENT)
async def reset_password(
    payload: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    now = _now()
    if (
        not user
        or user.reset_password_code != payload.code
        or user.reset_password_code_expires_at is None
        or user.reset_password_code_expires_at < now
    ):
        raise HTTPException(status_code=400, detail="Código inválido ou expirado")

    if len(payload.new_password) < 6:
        raise HTTPException(status_code=400, detail="Nova senha deve ter no mínimo 6 caracteres")

    user.hashed_password = hash_password(payload.new_password)
    user.reset_password_code = None
    user.reset_password_code_expires_at = None
    await db.commit()


@router.post("/google", response_model=Token)
async def google_auth(payload: GoogleAuthRequest, db: AsyncSession = Depends(get_db)):
    if not settings.GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=501, detail="Google login não configurado")

    # verify_oauth2_token faz I/O síncrono — rodar fora da event loop
    loop = asyncio.get_event_loop()
    try:
        id_info = await loop.run_in_executor(
            None,
            lambda: google_id_token.verify_oauth2_token(
                payload.id_token,
                google_requests.Request(),
                settings.GOOGLE_CLIENT_ID,
            ),
        )
    except ValueError:
        raise HTTPException(status_code=401, detail="Token Google inválido")

    google_sub: str = id_info["sub"]
    email: str = id_info["email"]
    name: str = id_info.get("name") or email.split("@")[0]

    # Busca por google_id primeiro, depois por email
    result = await db.execute(select(User).where(User.google_id == google_sub))
    user = result.scalar_one_or_none()

    if not user:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user:
            # Vincula conta existente ao Google
            user.google_id = google_sub
        else:
            # Cria nova conta — email já verificado pelo Google
            user = User(
                name=name,
                email=email,
                google_id=google_sub,
                is_verified=True,
            )
            db.add(user)

    await db.commit()
    await db.refresh(user)

    token = create_access_token(user.id)
    return Token(access_token=token, user=UserOut.model_validate(user))


@router.post("/login", response_model=Token)
async def login(payload: UserLogin, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    pw_ok = (
        user and user.hashed_password and verify_password(payload.password, user.hashed_password)
    )
    if not pw_ok:
        raise HTTPException(status_code=401, detail="Email ou senha inválidos")

    if not user.is_verified:
        raise HTTPException(status_code=403, detail="EMAIL_NOT_VERIFIED")

    token = create_access_token(user.id)
    return Token(access_token=token, user=UserOut.model_validate(user))


@router.get("/me", response_model=UserOut)
async def me(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UserOut)
async def update_me(
    payload: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if payload.email != current_user.email:
        existing = await db.execute(select(User).where(User.email == payload.email))
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="Email já cadastrado por outro usuário")

    current_user.name = payload.name
    current_user.email = payload.email
    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.put("/me/password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    payload: UserChangePassword,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    pw_ok = current_user.hashed_password and verify_password(
        payload.current_password, current_user.hashed_password
    )
    if not pw_ok:
        raise HTTPException(status_code=400, detail="Senha atual incorreta")
    if len(payload.new_password) < 6:
        raise HTTPException(status_code=400, detail="Nova senha deve ter no mínimo 6 caracteres")

    current_user.hashed_password = hash_password(payload.new_password)
    await db.commit()
