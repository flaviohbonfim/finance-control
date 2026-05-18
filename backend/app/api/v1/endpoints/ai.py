import json
import re
from collections.abc import AsyncGenerator
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.account import Account
from app.models.category import Category
from app.models.transaction import Transaction, TransactionType
from app.models.user import User

router = APIRouter(prefix="/ai", tags=["ai"])


# ── Chat schemas ──────────────────────────────────────────────────────────────

class ChatMessage(BaseModel):
    role: str  # "user" | "model"
    content: str


class ChatRequest(BaseModel):
    message: str
    history: list[ChatMessage] = []


# ── Tool implementations ──────────────────────────────────────────────────────

async def _tool_get_accounts(db: AsyncSession, user: User) -> str:
    result = await db.execute(select(Account).where(Account.user_id == user.id))
    accounts = result.scalars().all()
    data = [
        {
            "id": a.id,
            "name": a.name,
            "type": a.type.value,
            "balance": float(a.balance),
            "color": a.color,
            "credit_limit": float(a.credit_limit) if a.credit_limit else None,
            "closing_day": a.closing_day,
            "due_day": a.due_day,
        }
        for a in accounts
    ]
    return json.dumps(data, ensure_ascii=False)


async def _tool_get_dashboard(db: AsyncSession, user: User) -> str:
    import calendar as cal_mod

    from sqlalchemy import func

    today = date.today()
    m_start = today.replace(day=1)
    m_end = today.replace(day=cal_mod.monthrange(today.year, today.month)[1])
    bal_r = await db.execute(
        select(func.coalesce(func.sum(Account.balance), 0)).where(Account.user_id == user.id)
    )
    total_balance = float(bal_r.scalar())

    inc_r = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            Transaction.user_id == user.id,
            Transaction.type == TransactionType.income,
            Transaction.transaction_date >= m_start,
            Transaction.transaction_date <= m_end,
        )
    )
    monthly_income = float(inc_r.scalar())

    exp_r = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            Transaction.user_id == user.id,
            Transaction.type == TransactionType.expense,
            Transaction.transaction_date >= m_start,
            Transaction.transaction_date <= m_end,
        )
    )
    monthly_expense = float(exp_r.scalar())

    data = {
        "today": str(today),
        "total_balance": total_balance,
        "monthly_income": monthly_income,
        "monthly_expense": monthly_expense,
        "monthly_balance": monthly_income - monthly_expense,
    }
    return json.dumps(data, ensure_ascii=False)


async def _tool_get_transactions(
    db: AsyncSession, user: User,
    date_from: str | None = None,
    date_to: str | None = None,
    type_filter: str | None = None,
    limit: int = 20,
) -> str:
    stmt = (
        select(Transaction)
        .where(Transaction.user_id == user.id)
        .options(selectinload(Transaction.category))
        .order_by(Transaction.transaction_date.desc(), Transaction.id.desc())
        .limit(min(limit, 50))
    )
    if date_from:
        stmt = stmt.where(Transaction.transaction_date >= date_from)
    if date_to:
        stmt = stmt.where(Transaction.transaction_date <= date_to)
    if type_filter in ("income", "expense"):
        stmt = stmt.where(Transaction.type == TransactionType(type_filter))

    result = await db.execute(stmt)
    txs = result.scalars().all()
    data = [
        {
            "id": t.id,
            "description": t.description,
            "amount": float(t.amount),
            "type": t.type.value,
            "date": str(t.transaction_date),
            "category": t.category.name if t.category else None,
        }
        for t in txs
    ]
    return json.dumps(data, ensure_ascii=False)


async def _tool_get_monthly_summary(db: AsyncSession, user: User, year: int) -> str:
    import calendar as cal_mod
    from decimal import Decimal as D

    from sqlalchemy import func

    months = []
    for m in range(1, 13):
        m_start = date(year, m, 1)
        m_end = date(year, m, cal_mod.monthrange(year, m)[1])
        label = f"{year}-{m:02d}"

        inc = await db.execute(
            select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                Transaction.user_id == user.id,
                Transaction.type == TransactionType.income,
                Transaction.transaction_date >= m_start,
                Transaction.transaction_date <= m_end,
            )
        )
        exp = await db.execute(
            select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                Transaction.user_id == user.id,
                Transaction.type == TransactionType.expense,
                Transaction.transaction_date >= m_start,
                Transaction.transaction_date <= m_end,
            )
        )
        i = float(D(str(inc.scalar())))
        e = float(D(str(exp.scalar())))
        months.append({"month": label, "income": i, "expense": e, "balance": i - e})

    return json.dumps(months, ensure_ascii=False)


async def _tool_get_expense_by_category(
    db: AsyncSession, user: User,
    year: int, month: int,
) -> str:
    import calendar as cal_mod
    from decimal import Decimal as D

    from sqlalchemy import func

    m_start = date(year, month, 1)
    m_end = date(year, month, cal_mod.monthrange(year, month)[1])

    cat_r = await db.execute(
        select(
            Category.id,
            Category.name,
            func.sum(Transaction.amount).label("total"),
        )
        .select_from(Transaction)
        .join(Category, Transaction.category_id == Category.id, isouter=True)
        .where(
            Transaction.user_id == user.id,
            Transaction.type == TransactionType.expense,
            Transaction.transaction_date >= m_start,
            Transaction.transaction_date <= m_end,
        )
        .group_by(Category.id, Category.name)
        .order_by(func.sum(Transaction.amount).desc())
    )
    rows = cat_r.all()
    total = sum(float(D(str(r.total))) for r in rows) or 1.0
    data = [
        {
            "category": r.name or "Sem categoria",
            "total": float(D(str(r.total))),
            "percentage": round(float(D(str(r.total))) / total * 100, 1),
        }
        for r in rows
    ]
    return json.dumps(data, ensure_ascii=False)


# ── Tool definitions for Gemini ───────────────────────────────────────────────

TOOL_DEFINITIONS = [
    {
        "name": "get_accounts",
        "description": "Retorna as contas do usuário com saldo, tipo e limite de crédito.",
        "parameters": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
    {
        "name": "get_dashboard",
        "description": "Retorna resumo do mês atual: saldo total, receitas, despesas e saldo.",
        "parameters": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
    {
        "name": "get_transactions",
        "description": "Lista transações do usuário com filtros opcionais de data e tipo.",
        "parameters": {
            "type": "object",
            "properties": {
                "date_from": {
                    "type": "string",
                    "description": "Data inicial no formato YYYY-MM-DD",
                },
                "date_to": {
                    "type": "string",
                    "description": "Data final no formato YYYY-MM-DD",
                },
                "type_filter": {
                    "type": "string",
                    "enum": ["income", "expense"],
                    "description": "Filtrar por tipo",
                },
                "limit": {
                    "type": "integer",
                    "description": "Número máximo de transações (máx 50, padrão 20)",
                },
            },
            "required": [],
        },
    },
    {
        "name": "get_monthly_summary",
        "description": "Retorna receitas, despesas e saldo de todos os meses de um ano.",
        "parameters": {
            "type": "object",
            "properties": {
                "year": {"type": "integer", "description": "Ano (ex: 2025)"},
            },
            "required": ["year"],
        },
    },
    {
        "name": "get_expense_by_category",
        "description": "Retorna as despesas agrupadas por categoria em um mês específico.",
        "parameters": {
            "type": "object",
            "properties": {
                "year": {"type": "integer", "description": "Ano (ex: 2025)"},
                "month": {"type": "integer", "description": "Mês (1-12)"},
            },
            "required": ["year", "month"],
        },
    },
]


async def _dispatch_tool(name: str, args: dict, db: AsyncSession, user: User) -> str:
    if name == "get_accounts":
        return await _tool_get_accounts(db, user)
    if name == "get_dashboard":
        return await _tool_get_dashboard(db, user)
    if name == "get_transactions":
        return await _tool_get_transactions(db, user, **args)
    if name == "get_monthly_summary":
        return await _tool_get_monthly_summary(db, user, year=args.get("year", date.today().year))
    if name == "get_expense_by_category":
        today = date.today()
        return await _tool_get_expense_by_category(
            db, user,
            year=args.get("year", today.year),
            month=args.get("month", today.month),
        )
    return json.dumps({"error": f"Tool desconhecida: {name}"})


# ── SSE helpers ───────────────────────────────────────────────────────────────

def _sse(event: str, data: str) -> str:
    return f"event: {event}\ndata: {data}\n\n"


async def _chat_stream(
    request: ChatRequest, db: AsyncSession, user: User
) -> AsyncGenerator[str, None]:
    from google import genai
    from google.genai import types as gtypes

    client = genai.Client(api_key=settings.GEMINI_API_KEY)

    system_instruction = (
        "Você é um assistente financeiro pessoal inteligente e simpático. "
        "Você tem acesso às ferramentas para consultar as finanças do usuário. "
        "Responda sempre em português brasileiro de forma clara e objetiva. "
        "Use dados reais das ferramentas para responder. "
        f"A data de hoje é {date.today().strftime('%d/%m/%Y')}."
    )

    # Build conversation history
    contents = []
    for msg in request.history:
        contents.append(
            gtypes.Content(
                role=msg.role,
                parts=[gtypes.Part(text=msg.content)],
            )
        )
    contents.append(
        gtypes.Content(
            role="user",
            parts=[gtypes.Part(text=request.message)],
        )
    )

    tools = [gtypes.Tool(function_declarations=[
        gtypes.FunctionDeclaration(
            name=t["name"],
            description=t["description"],
            parameters=gtypes.Schema(**_schema_to_genai(t["parameters"])),
        )
        for t in TOOL_DEFINITIONS
    ])]

    candidate = None
    try:
        MAX_TOOL_ROUNDS = 5
        for _ in range(MAX_TOOL_ROUNDS):
            response = await client.aio.models.generate_content(
                model="gemini-2.5-flash",
                contents=contents,
                config=gtypes.GenerateContentConfig(
                    system_instruction=system_instruction,
                    tools=tools,
                    temperature=0.3,
                ),
            )

            candidate = response.candidates[0]

            has_tool_call = any(
                part.function_call is not None
                for part in candidate.content.parts
            )

            if not has_tool_call:
                break

            contents.append(candidate.content)

            tool_parts = []
            for part in candidate.content.parts:
                if part.function_call is None:
                    continue
                fc = part.function_call
                tool_args = dict(fc.args) if fc.args else {}

                yield _sse("tool_call", json.dumps({"name": fc.name}))

                tool_result = await _dispatch_tool(fc.name, tool_args, db, user)

                tool_parts.append(
                    gtypes.Part(
                        function_response=gtypes.FunctionResponse(
                            name=fc.name,
                            response={"result": tool_result},
                        )
                    )
                )

            contents.append(gtypes.Content(role="user", parts=tool_parts))

    except Exception as e:
        yield _sse("error", json.dumps({"detail": f"Erro ao chamar Gemini: {e}"}))
        return

    if candidate is None:
        yield _sse("error", json.dumps({"detail": "Sem resposta do modelo"}))
        return

    final_text = "".join(part.text for part in candidate.content.parts if part.text)

    if not final_text:
        yield _sse("error", json.dumps({"detail": "Resposta vazia do modelo"}))
        return

    words = final_text.split(" ")
    for i, word in enumerate(words):
        chunk = word if i == 0 else " " + word
        yield _sse("delta", json.dumps({"text": chunk}))

    yield _sse("done", json.dumps({"text": final_text}))


def _schema_to_genai(schema: dict) -> dict:
    """Convert JSON Schema dict to google-genai Schema kwargs."""
    result = {"type": schema.get("type", "object").upper()}
    if "properties" in schema:
        result["properties"] = {
            k: _prop_to_genai(v) for k, v in schema["properties"].items()
        }
    if "required" in schema:
        result["required"] = schema["required"]
    return result


def _prop_to_genai(prop: dict):
    from google.genai import types as gtypes

    type_map = {"string": "STRING", "integer": "INTEGER", "number": "NUMBER", "boolean": "BOOLEAN"}
    kwargs = {"type": type_map.get(prop.get("type", "string"), "STRING")}
    if "description" in prop:
        kwargs["description"] = prop["description"]
    if "enum" in prop:
        kwargs["enum"] = prop["enum"]
    return gtypes.Schema(**kwargs)


# ── Chat endpoint ─────────────────────────────────────────────────────────────

@router.post("/chat")
async def chat(
    request: ChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not settings.GEMINI_API_KEY:
        raise HTTPException(status_code=400, detail="GEMINI_API_KEY não configurada no servidor")

    return StreamingResponse(
        _chat_stream(request, db, current_user),
        media_type="text/event-stream",
        headers={
            "X-Accel-Buffering": "no",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )


@router.post("/auto-categorize")
async def auto_categorize(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not settings.GEMINI_API_KEY:
        raise HTTPException(status_code=400, detail="GEMINI_API_KEY não configurada no servidor")

    # Busca transações sem categoria
    tx_result = await db.execute(
        select(Transaction).where(
            Transaction.user_id == current_user.id,
            Transaction.category_id.is_(None),
            Transaction.type == TransactionType.expense,
        )
    )
    transactions = tx_result.scalars().all()

    if not transactions:
        return {"categorized": 0, "message": "Nenhuma transação sem categoria encontrada"}

    # Busca categorias disponíveis
    cat_result = await db.execute(select(Category).where(Category.user_id == current_user.id))
    categories = cat_result.scalars().all()

    if not categories:
        raise HTTPException(status_code=400, detail="Nenhuma categoria cadastrada")

    # Monta o prompt
    categories_list = "\n".join(f'  {{"id": {c.id}, "name": "{c.name}"}}' for c in categories)
    transactions_list = "\n".join(
        f'  {{"id": {t.id}, "description": "{t.description}"}}'
        for t in transactions[:200]  # limite de 200 por chamada
    )

    prompt = f"""Você é um categorizador de transações financeiras brasileiras.
Classifique cada transação na categoria mais adequada com base na descrição.
Descrições de cartão podem ter prefixos como "DL*", "EBN *", "ZP*", "EC *" — ignore-os.

Categorias disponíveis:
{categories_list}

Transações para classificar:
{transactions_list}

Responda APENAS com um array JSON válido, sem explicações, sem markdown:
[{{"transaction_id": <id>, "category_id": <id>}}, ...]

Se uma transação não se encaixar em nenhuma categoria, omita-a do resultado."""

    try:
        from google import genai

        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        response = await client.aio.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
        )
        raw = response.text.strip()

        # Extrai JSON mesmo se vier com markdown
        match = re.search(r"\[.*\]", raw, re.DOTALL)
        if not match:
            raise ValueError("Resposta não contém JSON válido")
        suggestions = json.loads(match.group())
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Erro ao chamar Gemini: {e}") from e

    # Aplica as categorias sugeridas
    tx_map = {t.id: t for t in transactions}
    cat_ids = {c.id for c in categories}
    categorized = 0

    for item in suggestions:
        tx_id = item.get("transaction_id")
        cat_id = item.get("category_id")
        if tx_id in tx_map and cat_id in cat_ids:
            tx_map[tx_id].category_id = cat_id
            categorized += 1

    await db.commit()

    return {
        "categorized": categorized,
        "total_uncategorized": len(transactions),
        "message": f"{categorized} de {len(transactions)} transações categorizadas automaticamente",
    }
