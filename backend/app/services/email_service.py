import logging
from fastapi_mail import ConnectionConfig, FastMail, MessageSchema, MessageType

from app.core.config import settings

logger = logging.getLogger(__name__)


def _get_mail_config() -> ConnectionConfig:
    return ConnectionConfig(
        MAIL_USERNAME=settings.SMTP_USER,
        MAIL_PASSWORD=settings.SMTP_PASSWORD,
        MAIL_FROM=settings.SMTP_FROM or settings.SMTP_USER,
        MAIL_PORT=settings.SMTP_PORT,
        MAIL_SERVER=settings.SMTP_HOST,
        MAIL_FROM_NAME="Finance Control",
        MAIL_STARTTLS=True,
        MAIL_SSL_TLS=False,
        USE_CREDENTIALS=True,
        VALIDATE_CERTS=True,
    )


def _make_code_html(title: str, greeting: str, body: str, code: str, expiry: str) -> str:
    return f"""
    <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px 24px;background:#f9fafb;border-radius:12px">
      <h2 style="color:#111827;margin-bottom:8px">{title}</h2>
      <p style="color:#374151;margin-bottom:24px">{greeting},</p>
      <p style="color:#374151;margin-bottom:24px">{body}</p>
      <div style="background:#fff;border:2px solid #e5e7eb;border-radius:8px;padding:20px;text-align:center;margin-bottom:24px">
        <span style="font-size:36px;font-weight:700;letter-spacing:12px;color:#111827">{code}</span>
      </div>
      <p style="color:#6b7280;font-size:13px">Este código expira em {expiry}.</p>
      <p style="color:#6b7280;font-size:13px">Se você não solicitou isso, ignore este email.</p>
    </div>
    """


async def send_verification_code(email: str, name: str, code: str) -> None:
    html = _make_code_html(
        title="Verifique seu email",
        greeting=f"Olá, {name}",
        body="Use o código abaixo para ativar sua conta no Finance Control:",
        code=code,
        expiry="15 minutos",
    )
    message = MessageSchema(
        subject="Código de verificação — Finance Control",
        recipients=[email],
        body=html,
        subtype=MessageType.html,
    )
    try:
        fm = FastMail(_get_mail_config())
        await fm.send_message(message)
    except Exception:
        logger.exception("Falha ao enviar email de verificação para %s", email)
        raise


async def send_reset_code(email: str, name: str, code: str) -> None:
    html = _make_code_html(
        title="Redefinição de senha",
        greeting=f"Olá, {name}",
        body="Use o código abaixo para redefinir sua senha no Finance Control:",
        code=code,
        expiry="15 minutos",
    )
    message = MessageSchema(
        subject="Código de redefinição de senha — Finance Control",
        recipients=[email],
        body=html,
        subtype=MessageType.html,
    )
    try:
        fm = FastMail(_get_mail_config())
        await fm.send_message(message)
    except Exception:
        logger.exception("Falha ao enviar email de reset para %s", email)
        raise
