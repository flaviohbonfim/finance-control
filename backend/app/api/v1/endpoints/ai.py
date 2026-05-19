import json
import logging
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
from app.models.recurring_transaction import RecurringTransaction
from app.models.transaction import Transaction, TransactionType
from app.models.user import User

logger = logging.getLogger(__name__)

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
    db: AsyncSession,
    user: User,
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
    db: AsyncSession,
    user: User,
    year: int,
    month: int,
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


# ── Phase 2 & 3 tools ────────────────────────────────────────────────────────


async def _tool_get_categories(db: AsyncSession, user: User, type_filter: str | None = None) -> str:
    stmt = select(Category).where(Category.user_id == user.id)
    if type_filter in ("income", "expense"):
        stmt = stmt.where(Category.type == type_filter)
    result = await db.execute(stmt)
    cats = result.scalars().all()
    data = [{"id": c.id, "name": c.name, "type": c.type.value, "color": c.color} for c in cats]
    return json.dumps(data, ensure_ascii=False)


async def _tool_get_recurring_transactions(db: AsyncSession, user: User) -> str:
    result = await db.execute(
        select(RecurringTransaction)
        .where(RecurringTransaction.user_id == user.id, RecurringTransaction.active.is_(True))
        .options(
            selectinload(RecurringTransaction.category), selectinload(RecurringTransaction.account)
        )
        .order_by(RecurringTransaction.due_day)
    )
    rts = result.scalars().all()
    today = date.today()
    data = [
        {
            "id": rt.id,
            "description": rt.description,
            "type": rt.type.value,
            "amount": float(rt.amount) if rt.amount else None,
            "is_fixed": rt.is_fixed,
            "frequency": rt.frequency.value,
            "due_day": rt.due_day,
            "account": rt.account.name if rt.account else None,
            "category": rt.category.name if rt.category else None,
            "launched_this_month": (
                rt.last_launched_date is not None
                and rt.last_launched_date.year == today.year
                and rt.last_launched_date.month == today.month
            ),
        }
        for rt in rts
    ]
    return json.dumps(data, ensure_ascii=False)


async def _tool_get_monthly_detail(db: AsyncSession, user: User, year: int, month: int) -> str:
    import calendar as cal_mod
    from decimal import Decimal as D

    from sqlalchemy import func

    m_start = date(year, month, 1)
    m_end = date(year, month, cal_mod.monthrange(year, month)[1])

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
    income = float(D(str(inc.scalar())))
    expense = float(D(str(exp.scalar())))

    cat_r = await db.execute(
        select(Category.name, func.sum(Transaction.amount).label("total"))
        .select_from(Transaction)
        .join(Category, Transaction.category_id == Category.id, isouter=True)
        .where(
            Transaction.user_id == user.id,
            Transaction.type == TransactionType.expense,
            Transaction.transaction_date >= m_start,
            Transaction.transaction_date <= m_end,
        )
        .group_by(Category.name)
        .order_by(func.sum(Transaction.amount).desc())
    )
    by_cat = [
        {"category": r.name or "Sem categoria", "total": float(D(str(r.total)))}
        for r in cat_r.all()
    ]

    top_r = await db.execute(
        select(Transaction)
        .where(
            Transaction.user_id == user.id,
            Transaction.type == TransactionType.expense,
            Transaction.transaction_date >= m_start,
            Transaction.transaction_date <= m_end,
        )
        .options(selectinload(Transaction.category))
        .order_by(Transaction.amount.desc())
        .limit(10)
    )
    top = [
        {
            "description": t.description,
            "amount": float(t.amount),
            "date": str(t.transaction_date),
            "category": t.category.name if t.category else None,
        }
        for t in top_r.scalars().all()
    ]

    return json.dumps(
        {
            "income": income,
            "expense": expense,
            "balance": income - expense,
            "by_category": by_cat,
            "top_expenses": top,
        },
        ensure_ascii=False,
    )


async def _tool_create_transaction(
    db: AsyncSession,
    user: User,
    account_id: int,
    type: str,
    amount: float,
    description: str,
    transaction_date: str | None = None,
    category_id: int | None = None,
) -> str:
    from decimal import Decimal as D

    acc = await db.get(Account, account_id)
    if not acc or acc.user_id != user.id:
        return json.dumps({"error": "Conta não encontrada"})
    if type not in ("income", "expense"):
        return json.dumps({"error": "Tipo deve ser 'income' ou 'expense'"})

    tx_date = date.fromisoformat(transaction_date) if transaction_date else date.today()
    tx = Transaction(
        user_id=user.id,
        account_id=account_id,
        category_id=category_id,
        type=TransactionType(type),
        amount=D(str(amount)),
        description=description,
        transaction_date=tx_date,
    )
    db.add(tx)

    if type == "income":
        acc.balance += D(str(amount))
    else:
        acc.balance -= D(str(amount))

    await db.commit()
    await db.refresh(tx)
    return json.dumps(
        {
            "success": True,
            "id": tx.id,
            "message": f"Transação '{description}' criada! Saldo de '{acc.name}' atualizado.",
        },
        ensure_ascii=False,
    )


async def _tool_delete_transaction(db: AsyncSession, user: User, transaction_id: int) -> str:
    result = await db.execute(
        select(Transaction).where(Transaction.id == transaction_id, Transaction.user_id == user.id)
    )
    tx = result.scalar_one_or_none()
    if not tx:
        return json.dumps({"error": "Transação não encontrada"})

    acc = await db.get(Account, tx.account_id)
    if acc:
        if tx.type == TransactionType.income:
            acc.balance -= tx.amount
        else:
            acc.balance += tx.amount

    desc = tx.description
    await db.delete(tx)
    await db.commit()
    return json.dumps(
        {"success": True, "message": f"Transação '{desc}' deletada com sucesso."},
        ensure_ascii=False,
    )


async def _tool_launch_recurring(
    db: AsyncSession, user: User, recurring_id: int, amount: float | None = None
) -> str:
    from decimal import Decimal as D

    result = await db.execute(
        select(RecurringTransaction)
        .where(RecurringTransaction.id == recurring_id, RecurringTransaction.user_id == user.id)
        .options(selectinload(RecurringTransaction.account))
    )
    rt = result.scalar_one_or_none()
    if not rt:
        return json.dumps({"error": "Recorrente não encontrado"})

    if rt.is_fixed:
        launch_amount = rt.amount
    else:
        if amount is None:
            return json.dumps({"error": "Este lançamento é variável. Informe o valor (amount)."})
        launch_amount = D(str(amount))

    if launch_amount is None:
        return json.dumps({"error": "Valor não disponível"})

    acc = await db.get(Account, rt.account_id)
    if not acc:
        return json.dumps({"error": "Conta não encontrada"})

    today = date.today()
    tx = Transaction(
        user_id=user.id,
        account_id=rt.account_id,
        category_id=rt.category_id,
        type=rt.type,
        amount=launch_amount,
        description=rt.description,
        transaction_date=today,
    )
    db.add(tx)

    if rt.type == TransactionType.income:
        acc.balance += launch_amount
    else:
        acc.balance -= launch_amount

    rt.last_launched_date = today
    await db.commit()
    return json.dumps(
        {
            "success": True,
            "message": f"'{rt.description}' lançado! Valor: R$ {float(launch_amount):.2f}",
        },
        ensure_ascii=False,
    )


# ── Tool definitions ──────────────────────────────────────────────────────────

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
    {
        "name": "get_categories",
        "description": "Lista as categorias. Use antes de criar transações para obter IDs válidos.",
        "parameters": {
            "type": "object",
            "properties": {
                "type_filter": {
                    "type": "string",
                    "enum": ["income", "expense"],
                    "description": "Filtrar por tipo (opcional)",
                },
            },
            "required": [],
        },
    },
    {
        "name": "get_recurring_transactions",
        "description": "Lista as transações recorrentes ativas com status de lançamento no mês.",
        "parameters": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "get_monthly_detail",
        "description": "Detalhamento de um mês: receitas, despesas, breakdown por categoria.",
        "parameters": {
            "type": "object",
            "properties": {
                "year": {"type": "integer", "description": "Ano (ex: 2025)"},
                "month": {"type": "integer", "description": "Mês (1-12)"},
            },
            "required": ["year", "month"],
        },
    },
    {
        "name": "create_transaction",
        "description": "Cria uma nova transação (receita ou despesa) e atualiza o saldo da conta.",
        "parameters": {
            "type": "object",
            "properties": {
                "account_id": {"type": "integer", "description": "ID da conta"},
                "type": {"type": "string", "enum": ["income", "expense"]},
                "amount": {"type": "number", "description": "Valor em reais"},
                "description": {"type": "string", "description": "Descrição da transação"},
                "transaction_date": {
                    "type": "string",
                    "description": "Data no formato YYYY-MM-DD (padrão: hoje)",
                },
                "category_id": {
                    "type": "integer",
                    "description": "ID da categoria (opcional)",
                },
            },
            "required": ["account_id", "type", "amount", "description"],
        },
    },
    {
        "name": "delete_transaction",
        "description": "Deleta uma transação e reverte o saldo da conta. Confirme o ID antes.",
        "parameters": {
            "type": "object",
            "properties": {
                "transaction_id": {"type": "integer", "description": "ID da transação"},
            },
            "required": ["transaction_id"],
        },
    },
    {
        "name": "launch_recurring",
        "description": "Lança uma recorrente no mês atual: cria transação e atualiza saldo.",
        "parameters": {
            "type": "object",
            "properties": {
                "recurring_id": {"type": "integer", "description": "ID da recorrente"},
                "amount": {
                    "type": "number",
                    "description": "Valor (obrigatório para recorrentes variáveis)",
                },
            },
            "required": ["recurring_id"],
        },
    },
]

# Tools that modify data — frontend should invalidate cache after these
WRITE_TOOLS = {"create_transaction", "delete_transaction", "launch_recurring"}


async def _dispatch_tool(name: str, args: dict, db: AsyncSession, user: User) -> str:
    today = date.today()
    if name == "get_accounts":
        return await _tool_get_accounts(db, user)
    if name == "get_dashboard":
        return await _tool_get_dashboard(db, user)
    if name == "get_transactions":
        return await _tool_get_transactions(db, user, **args)
    if name == "get_monthly_summary":
        return await _tool_get_monthly_summary(db, user, year=args.get("year", today.year))
    if name == "get_expense_by_category":
        return await _tool_get_expense_by_category(
            db, user, year=args.get("year", today.year), month=args.get("month", today.month)
        )
    if name == "get_categories":
        return await _tool_get_categories(db, user, type_filter=args.get("type_filter"))
    if name == "get_recurring_transactions":
        return await _tool_get_recurring_transactions(db, user)
    if name == "get_monthly_detail":
        return await _tool_get_monthly_detail(
            db, user, year=args.get("year", today.year), month=args.get("month", today.month)
        )
    if name == "create_transaction":
        args["account_id"] = int(args["account_id"])
        if "category_id" in args and args["category_id"] is not None:
            args["category_id"] = int(args["category_id"])
        return await _tool_create_transaction(db, user, **args)
    if name == "delete_transaction":
        return await _tool_delete_transaction(db, user, transaction_id=int(args["transaction_id"]))
    if name == "launch_recurring":
        return await _tool_launch_recurring(
            db, user, recurring_id=int(args["recurring_id"]), amount=args.get("amount")
        )
    return json.dumps({"error": f"Tool desconhecida: {name}"})


# ── SSE helpers ───────────────────────────────────────────────────────────────


def _sse(event: str, data: str) -> str:
    return f"event: {event}\ndata: {data}\n\n"


# ── AI provider helpers ───────────────────────────────────────────────────────

_SYSTEM_PROMPT = (
    "Você é um assistente financeiro pessoal inteligente e simpático. "
    "Você tem acesso a ferramentas para CONSULTAR e MODIFICAR as finanças do usuário. "
    "Responda sempre em português brasileiro de forma clara e objetiva. "
    "Use dados reais das ferramentas para responder. "
    "REGRA OBRIGATÓRIA: antes de chamar create_transaction, você DEVE chamar get_accounts "
    "para obter o account_id numérico real da conta. Se o usuário mencionar categoria, "
    "chame get_categories antes para obter o category_id numérico real. "
    "Nunca invente IDs ou use strings como IDs — apenas integers retornados pelas ferramentas. "
    "Para operações de escrita, confirme os detalhes com o usuário se houver ambiguidade."
)

_TOOLS_LIST = [
    {
        "type": "function",
        "function": {
            "name": t["name"],
            "description": t["description"],
            "parameters": t["parameters"],
        },
    }
    for t in TOOL_DEFINITIONS
]


def _provider_clients() -> list[tuple]:
    """Returns (client, model) pairs ordered by LLM_PROVIDER preference."""
    from groq import AsyncGroq
    from openai import AsyncOpenAI  # available as transitive dep of groq

    def _groq():
        return (AsyncGroq(api_key=settings.GROQ_API_KEY), "llama-3.3-70b-versatile")

    def _cerebras():
        return (
            AsyncOpenAI(api_key=settings.CEREBRAS_API_KEY, base_url="https://api.cerebras.ai/v1"),
            "llama-3.3-70b",
        )

    def _gemini():
        return (
            AsyncOpenAI(
                api_key=settings.GEMINI_API_KEY,
                base_url="https://generativelanguage.googleapis.com/v1beta/openai/",
            ),
            "gemini-2.0-flash",
        )

    available = {
        "groq": (_groq, settings.GROQ_API_KEY),
        "cerebras": (_cerebras, settings.CEREBRAS_API_KEY),
        "gemini": (_gemini, settings.GEMINI_API_KEY),
    }

    preferred = settings.LLM_PROVIDER.lower()
    ordered = [preferred] + [k for k in available if k != preferred]

    return [
        factory()
        for name in ordered
        if (entry := available.get(name)) and entry[1]
        for factory in [entry[0]]
    ]


def _build_messages(request: ChatRequest) -> list[dict]:
    system = f"{_SYSTEM_PROMPT}\nA data de hoje é {date.today().strftime('%d/%m/%Y')}."
    messages: list[dict] = [{"role": "system", "content": system}]
    for msg in request.history:
        messages.append(
            {"role": "user" if msg.role == "user" else "assistant", "content": msg.content}
        )
    messages.append({"role": "user", "content": request.message})
    return messages


async def _run_agentic_loop(
    client, model: str, messages: list[dict], db: AsyncSession, user: User
) -> tuple[list[dict], list[str]]:
    """Non-streaming tool-calling loop. Returns (updated_messages, invalidate_keys)."""
    invalidate_keys: list[str] = []
    messages = list(messages)

    for _ in range(5):
        response = await client.chat.completions.create(
            model=model,
            messages=messages,
            tools=_TOOLS_LIST,
            tool_choice="auto",
            max_tokens=4096,
            temperature=0.3,
        )
        assistant_msg = response.choices[0].message
        tool_calls = assistant_msg.tool_calls or []

        if not tool_calls:
            break

        messages.append(assistant_msg)
        for tc in tool_calls:
            fn_name = tc.function.name
            fn_args = json.loads(tc.function.arguments or "{}") or {}
            logger.info("Tool call: %s(%s)", fn_name, fn_args)
            result = await _dispatch_tool(fn_name, fn_args, db, user)
            logger.info("Tool result for %s: %.200s", fn_name, result)
            if fn_name in WRITE_TOOLS:
                invalidate_keys = ["transactions", "accounts", "dashboard", "recurring"]
            messages.append({"role": "tool", "tool_call_id": tc.id, "content": result})

    return messages, invalidate_keys


# ── Chat stream ───────────────────────────────────────────────────────────────


async def _chat_stream(
    request: ChatRequest, db: AsyncSession, user: User
) -> AsyncGenerator[str, None]:
    from openai import RateLimitError

    providers = _provider_clients()
    if not providers:
        yield _sse("error", json.dumps({"detail": "Nenhuma API key de IA configurada"}))
        return

    messages = _build_messages(request)
    yield _sse("status", json.dumps({"text": "pensando..."}))

    client, model = None, None
    final_messages: list[dict] = messages
    invalidate_keys: list[str] = []

    for i, (c, m) in enumerate(providers):
        try:
            final_messages, invalidate_keys = await _run_agentic_loop(c, m, messages, db, user)
            client, model = c, m
            break
        except RateLimitError:
            logger.warning("Rate limit em %s, tentando próximo provedor...", m)
            if i < len(providers) - 1:
                yield _sse(
                    "status",
                    json.dumps({"text": "limite atingido, usando provedor alternativo..."}),
                )
            else:
                yield _sse(
                    "error",
                    json.dumps(
                        {"detail": "Limite de tokens atingido. Tente novamente mais tarde."}
                    ),
                )
                return
        except Exception as e:
            logger.exception("Erro no loop agnético: %s", e)
            yield _sse("error", json.dumps({"detail": str(e)}))
            return

    if invalidate_keys:
        yield _sse("invalidate", json.dumps({"keys": invalidate_keys}))

    yield _sse("status", json.dumps({"text": "gerando resposta..."}))

    try:
        full_text = ""
        stream = await client.chat.completions.create(
            model=model,
            messages=final_messages,
            stream=True,
            max_tokens=4096,
            temperature=0.3,
        )
        async for chunk in stream:
            text = chunk.choices[0].delta.content or ""
            if text:
                full_text += text
                yield _sse("delta", json.dumps({"text": text}))
    except Exception as e:
        logger.exception("Erro no stream final: %s", e)
        yield _sse("error", json.dumps({"detail": str(e)}))
        return

    if not full_text:
        yield _sse("error", json.dumps({"detail": "Resposta vazia do modelo"}))
        return

    yield _sse("done", json.dumps({"text": full_text}))


async def _chat_sync(request: ChatRequest, db: AsyncSession, user: User) -> dict:
    """Non-streaming chat for the Telegram bot. Returns {text, invalidate_keys}."""
    from openai import RateLimitError

    providers = _provider_clients()
    if not providers:
        raise ValueError("Nenhuma API key de IA configurada")

    messages = _build_messages(request)
    last_error: Exception | None = None

    for c, m in providers:
        try:
            final_messages, invalidate_keys = await _run_agentic_loop(c, m, messages, db, user)
            final = await c.chat.completions.create(
                model=m,
                messages=final_messages,
                max_tokens=4096,
                temperature=0.3,
            )
            return {
                "text": final.choices[0].message.content or "",
                "invalidate_keys": invalidate_keys,
            }
        except RateLimitError as e:
            logger.warning("Rate limit em %s, tentando próximo provedor...", m)
            last_error = e
            continue

    raise last_error or ValueError("Todos os provedores falharam")


# ── Chat endpoints ─────────────────────────────────────────────────────────────


@router.post("/chat")
async def chat(
    request: ChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not settings.GROQ_API_KEY:
        raise HTTPException(status_code=400, detail="GROQ_API_KEY não configurada no servidor")

    return StreamingResponse(
        _chat_stream(request, db, current_user),
        media_type="text/event-stream",
        headers={
            "X-Accel-Buffering": "no",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )


@router.post("/chat/sync")
async def chat_sync(
    request: ChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not settings.GROQ_API_KEY:
        raise HTTPException(status_code=400, detail="GROQ_API_KEY não configurada no servidor")
    return await _chat_sync(request, db, current_user)


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
