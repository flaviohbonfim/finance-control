"""Finance Control — Telegram Bot

Usa polling. Comunica-se com o backend via HTTP interno.
Variáveis de ambiente necessárias:
  TELEGRAM_BOT_TOKEN      — token do bot (BotFather)
  BACKEND_URL             — ex: http://backend:8000
  TELEGRAM_INTERNAL_SECRET — secret compartilhado com o backend
"""
import logging
import os

import httpx
from telegram import Update
from telegram.constants import ChatAction, ParseMode
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters

logging.basicConfig(
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)

BOT_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
BACKEND_URL = os.environ.get("BACKEND_URL", "http://backend:8000")
INTERNAL_SECRET = os.environ["TELEGRAM_INTERNAL_SECRET"]

INTERNAL_HEADERS = {"x-internal-secret": INTERNAL_SECRET}

MAX_HISTORY = 20  # mensagens (10 trocas)


# ── Helpers ───────────────────────────────────────────────────────────────────


async def _resolve_token(chat_id: int) -> str | None:
    """Retorna JWT do usuário vinculado ao chat_id, ou None se não vinculado."""
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.post(
                f"{BACKEND_URL}/api/v1/telegram/resolve-user",
                json={"chat_id": chat_id},
                headers=INTERNAL_HEADERS,
            )
        if r.status_code == 200:
            return r.json()["token"]
    except Exception as e:
        logger.error("resolve-user error: %s", e)
    return None


async def _confirm_link(token: str, chat_id: int) -> bool:
    """Confirma vinculação via token do deep link."""
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.post(
                f"{BACKEND_URL}/api/v1/telegram/confirm-link",
                json={"token": token, "chat_id": chat_id},
                headers=INTERNAL_HEADERS,
            )
        return r.status_code == 200
    except Exception as e:
        logger.error("confirm-link error: %s", e)
    return False


async def _transcribe(jwt: str, audio_bytes: bytes, mime_type: str = "audio/ogg") -> str:
    """Upload audio to backend and return transcribed text."""
    async with httpx.AsyncClient(timeout=60) as client:
        r = await client.post(
            f"{BACKEND_URL}/api/v1/ai/transcribe",
            files={"file": ("audio.ogg", audio_bytes, mime_type)},
            headers={"Authorization": f"Bearer {jwt}"},
        )
    r.raise_for_status()
    return r.json()["text"]


async def _chat(jwt: str, message: str, history: list[dict]) -> dict:
    """Chama /ai/chat/sync e retorna {text, invalidate_keys}."""
    async with httpx.AsyncClient(timeout=120) as client:
        r = await client.post(
            f"{BACKEND_URL}/api/v1/ai/chat/sync",
            json={"message": message, "history": history},
            headers={"Authorization": f"Bearer {jwt}"},
        )
    r.raise_for_status()
    return r.json()


import re as _re


def _esc_html(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _md_to_html(text: str) -> str:
    """Convert AI markdown response to Telegram HTML (parse_mode='HTML')."""

    def _esc(s: str) -> str:
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    # Protect fenced code blocks
    code_blocks: list[str] = []

    def _save_block(m: _re.Match) -> str:
        code_blocks.append(f"<pre>{_esc(m.group(1))}</pre>")
        return f"\x00B{len(code_blocks)-1}\x00"

    text = _re.sub(r"```(?:\w+)?\n?(.*?)```", _save_block, text, flags=_re.DOTALL)

    # Protect inline code
    inline_codes: list[str] = []

    def _save_inline(m: _re.Match) -> str:
        inline_codes.append(f"<code>{_esc(m.group(1))}</code>")
        return f"\x00I{len(inline_codes)-1}\x00"

    text = _re.sub(r"`([^`\n]+)`", _save_inline, text)

    # Bullet points: convert `* item` / `- item` → `• item` (before italic)
    text = _re.sub(r"^[*-] (.+)$", r"• \1", text, flags=_re.MULTILINE)

    # Headers → bold
    text = _re.sub(r"^#{1,6} (.+)$", r"<b>\1</b>", text, flags=_re.MULTILINE)

    # Bold **text** / __text__
    text = _re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text, flags=_re.DOTALL)
    text = _re.sub(r"__(.+?)__", r"<b>\1</b>", text, flags=_re.DOTALL)

    # Italic *text* / _text_ (single markers)
    text = _re.sub(r"\*([^*\n]+)\*", r"<i>\1</i>", text)
    text = _re.sub(r"_([^_\n]+)_", r"<i>\1</i>", text)

    # Restore code blocks and inline code
    for i, b in enumerate(code_blocks):
        text = text.replace(f"\x00B{i}\x00", b)
    for i, c in enumerate(inline_codes):
        text = text.replace(f"\x00I{i}\x00", c)

    return text


NOT_LINKED_MSG = (
    "⚠️ Sua conta não está vinculada.\n\n"
    "Acesse o app → <b>Perfil</b> → <b>Vincular ao Telegram</b> e escaneie o link gerado."
)


# ── Handlers ──────────────────────────────────────────────────────────────────


async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id
    args = context.args  # token passado via deep link (?start=TOKEN)

    if args:
        token = args[0]
        await update.message.reply_text("🔗 Vinculando sua conta...")
        ok = await _confirm_link(token, chat_id)
        if ok:
            await update.message.reply_text(
                "✅ Conta vinculada com sucesso!\n\n"
                "Agora você pode me perguntar sobre seu saldo, transações, despesas e muito mais. "
                "Pode também criar e deletar transações por aqui.\n\n"
                "Use /ajuda para ver os comandos disponíveis."
            )
        else:
            await update.message.reply_text(
                "❌ Link inválido ou expirado.\n\n"
                "Gere um novo link pelo app: <b>Perfil → Vincular ao Telegram</b>",
                parse_mode=ParseMode.HTML,
            )
        return

    jwt = await _resolve_token(chat_id)
    if jwt:
        await update.message.reply_text(
            "👋 Olá! Sua conta já está vinculada.\n\n"
            "Pode me perguntar qualquer coisa sobre suas finanças, ou use /ajuda."
        )
    else:
        await update.message.reply_text(NOT_LINKED_MSG, parse_mode=ParseMode.HTML)


async def cmd_ajuda(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(
        "<b>Assistente Financeiro</b>\n\n"
        "Envie qualquer mensagem e responderei com base nos seus dados financeiros.\n\n"
        "<b>Exemplos:</b>\n"
        "• Qual meu saldo atual?\n"
        "• Quanto gastei esse mês?\n"
        "• Crie uma despesa de R$ 50 de almoço\n"
        "• Mostre minhas últimas transações\n"
        "• Quais são minhas contas?\n\n"
        "<b>Comandos:</b>\n"
        "/ajuda — esta mensagem\n"
        "/limpar — limpa o histórico da conversa\n"
        "/desconectar — desvincula sua conta",
        parse_mode=ParseMode.HTML,
    )


async def cmd_limpar(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    context.user_data["history"] = []
    await update.message.reply_text("🗑️ Histórico limpo.")


async def cmd_desconectar(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id
    jwt = await _resolve_token(chat_id)
    if not jwt:
        await update.message.reply_text("Você não tem uma conta vinculada.")
        return

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            await client.delete(
                f"{BACKEND_URL}/api/v1/telegram/unlink",
                headers={"Authorization": f"Bearer {jwt}"},
            )
    except Exception as e:
        logger.error("unlink error: %s", e)

    context.user_data["history"] = []
    await update.message.reply_text(
        "✅ Conta desvinculada. Use /start para vincular novamente."
    )


async def handle_voice(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id
    jwt = await _resolve_token(chat_id)
    if not jwt:
        await update.message.reply_text(NOT_LINKED_MSG, parse_mode=ParseMode.HTML)
        return

    voice = update.message.voice or update.message.audio
    if not voice:
        return

    await update.message.chat.send_action(ChatAction.TYPING)

    try:
        voice_file = await voice.get_file()
        audio_bytes = bytes(await voice_file.download_as_bytearray())
        text = await _transcribe(jwt, audio_bytes)
    except Exception as e:
        logger.error("transcription error: %s", e)
        await update.message.reply_text("⚠️ Não consegui transcrever o áudio. Tente novamente.")
        return

    if not text.strip():
        await update.message.reply_text("⚠️ Não consegui entender o áudio.")
        return

    await update.message.reply_text(f"🎙️ <i>{_esc_html(text)}</i>", parse_mode=ParseMode.HTML)
    await update.message.chat.send_action(ChatAction.TYPING)

    history: list[dict] = context.user_data.get("history", [])

    try:
        result = await _chat(jwt, text, history)
    except Exception as e:
        logger.error("chat error after voice: %s", e)
        await update.message.reply_text("⚠️ Erro ao processar. Tente novamente.")
        return

    reply = result.get("text", "Não consegui gerar uma resposta.")
    history.append({"role": "user", "content": text})
    history.append({"role": "model", "content": reply})
    context.user_data["history"] = history[-MAX_HISTORY:]

    try:
        await update.message.reply_text(_md_to_html(reply), parse_mode=ParseMode.HTML)
    except Exception:
        await update.message.reply_text(reply)


async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id
    text = update.message.text or ""

    jwt = await _resolve_token(chat_id)
    if not jwt:
        await update.message.reply_text(NOT_LINKED_MSG, parse_mode=ParseMode.HTML)
        return

    await update.message.chat.send_action(ChatAction.TYPING)

    history: list[dict] = context.user_data.get("history", [])

    try:
        result = await _chat(jwt, text, history)
    except Exception as e:
        logger.error("chat error: %s", e)
        await update.message.reply_text(
            "⚠️ Erro ao processar sua mensagem. Tente novamente."
        )
        return

    reply = result.get("text", "Não consegui gerar uma resposta.")

    # Atualiza histórico (mantém últimas MAX_HISTORY mensagens)
    history.append({"role": "user", "content": text})
    history.append({"role": "model", "content": reply})
    context.user_data["history"] = history[-MAX_HISTORY:]

    try:
        await update.message.reply_text(_md_to_html(reply), parse_mode=ParseMode.HTML)
    except Exception:
        await update.message.reply_text(reply)


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    app = Application.builder().token(BOT_TOKEN).build()

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("ajuda", cmd_ajuda))
    app.add_handler(CommandHandler("limpar", cmd_limpar))
    app.add_handler(CommandHandler("desconectar", cmd_desconectar))
    app.add_handler(MessageHandler(filters.VOICE | filters.AUDIO, handle_voice))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))

    logger.info("Bot iniciado (polling)...")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
