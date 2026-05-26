import calendar
from datetime import date

import httpx

from app.core.config import settings


async def call_backend(path: str, token: str, params: dict | None = None) -> dict | list:
    async with httpx.AsyncClient(base_url=settings.BACKEND_INTERNAL_URL, timeout=30) as client:
        resp = await client.get(
            path,
            headers={"Authorization": f"Bearer {token}"},
            params={k: v for k, v in (params or {}).items() if v is not None},
        )
        resp.raise_for_status()
        return resp.json()


async def post_backend(path: str, token: str, body: dict) -> dict:
    async with httpx.AsyncClient(base_url=settings.BACKEND_INTERNAL_URL, timeout=30) as client:
        resp = await client.post(
            path,
            headers={"Authorization": f"Bearer {token}"},
            json=body,
        )
        resp.raise_for_status()
        return resp.json()


def _fmt_brl(value) -> str:
    return f"R$ {float(value):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def _month_range(month: int, year: int) -> tuple[str, str]:
    last = calendar.monthrange(year, month)[1]
    return f"{year}-{month:02d}-01", f"{year}-{month:02d}-{last:02d}"


async def execute_tool(name: str, arguments: dict, token: str) -> str:
    try:
        return await _execute(name, arguments, token)
    except httpx.HTTPStatusError as exc:
        return f"Erro ao buscar dados: o servidor retornou status {exc.response.status_code}."
    except httpx.RequestError:
        return "Erro de conexão com o servidor. Tente novamente."


async def _execute(name: str, arguments: dict, token: str) -> str:
    today = date.today()

    # ── get_accounts ──────────────────────────────────────────────────────────
    if name == "get_accounts":
        data = await call_backend("/api/v1/accounts", token)
        if not data:
            return "Nenhuma conta cadastrada."
        lines = ["**Contas:**"]
        for acc in data:
            lines.append(f"- {acc['name']} ({acc['type']}): {_fmt_brl(acc['balance'])}")
        return "\n".join(lines)

    # ── list_transactions ────────────────────────────────────────────────────
    if name == "list_transactions":
        month = arguments.get("month", today.month)
        year = arguments.get("year", today.year)
        date_from, date_to = _month_range(int(month), int(year))

        tx_type = arguments.get("type")  # "income" | "expense" | None
        category_name = (arguments.get("category_name") or "").strip().lower()

        # Resolve category name → id
        category_id = None
        if category_name:
            cats = await call_backend("/api/v1/categories", token)
            match = next((c for c in cats if c["name"].lower() == category_name), None)
            if not match:
                match = next((c for c in cats if category_name in c["name"].lower()), None)
            if match:
                category_id = match["id"]

        params = {
            "date_from": date_from,
            "date_to": date_to,
            "page_size": 100,
        }
        if tx_type:
            params["type"] = tx_type
        if category_id:
            params["category_id"] = category_id

        data = await call_backend("/api/v1/transactions", token, params)
        items = data.get("items", [])
        total_count = data.get("total", len(items))

        if not items:
            period_label = f"{month:02d}/{year}"
            if tx_type == "expense":
                return f"Nenhuma despesa encontrada em {period_label}."
            if tx_type == "income":
                return f"Nenhuma receita encontrada em {period_label}."
            return f"Nenhuma transação encontrada em {period_label}."

        total_amount = sum(float(t["amount"]) for t in items)
        period_label = f"{int(month):02d}/{int(year)}"

        if tx_type == "expense":
            header = (
                f"**{len(items)} despesa(s) em {period_label} — Total: -{_fmt_brl(total_amount)}**"
            )
        elif tx_type == "income":
            header = (
                f"**{len(items)} receita(s) em {period_label} — Total: +{_fmt_brl(total_amount)}**"
            )
        else:
            header = f"**{len(items)} transação(ões) em {period_label} — Total: {_fmt_brl(total_amount)}**"

        if total_count > len(items):
            header += f" *(mostrando {len(items)} de {total_count})*"

        lines = [header]
        for t in items:
            sign = "+" if t["type"] == "income" else "-"
            cat = t.get("category") or {}
            cat_name = (
                cat.get("name", "Sem categoria") if isinstance(cat, dict) else "Sem categoria"
            )
            lines.append(
                f"- {t['transaction_date']} | {sign}{_fmt_brl(t['amount'])} | {t['description']} | {cat_name}"
            )
        return "\n".join(lines)

    # ── get_monthly_summary ───────────────────────────────────────────────────
    if name == "get_monthly_summary":
        month = arguments.get("month", today.month)
        year = arguments.get("year", today.year)
        data = await call_backend(
            "/api/v1/reports/monthly-detail", token, {"month": month, "year": year}
        )
        income = _fmt_brl(data.get("income", 0))
        expense = _fmt_brl(data.get("expense", 0))
        balance = float(data.get("income", 0)) - float(data.get("expense", 0))
        lines = [
            f"**Resumo de {int(month):02d}/{int(year)}:**",
            f"- Receitas: {income}",
            f"- Despesas: {expense}",
            f"- Saldo do período: {_fmt_brl(balance)}",
        ]
        by_cat = data.get("expense_by_category") or []
        if by_cat:
            lines.append("\n**Despesas por categoria:**")
            for c in by_cat:
                lines.append(
                    f"- {c['category_name']}: {_fmt_brl(c['total'])} ({c['percentage']:.1f}%)"
                )
        top = data.get("top_transactions") or []
        if top:
            lines.append("\n**Maiores despesas do mês:**")
            for t in top:
                cat = t.get("category") or {}
                cat_name = (
                    cat.get("name", "Sem categoria") if isinstance(cat, dict) else "Sem categoria"
                )
                lines.append(f"- {t['description']}: {_fmt_brl(t['amount'])} ({cat_name})")
        return "\n".join(lines)

    # ── get_categories ────────────────────────────────────────────────────────
    if name == "get_categories":
        params = {"type": arguments.get("type")} if arguments.get("type") else {}
        data = await call_backend("/api/v1/categories", token, params)
        if not data:
            return "Nenhuma categoria cadastrada."
        by_type: dict[str, list[str]] = {}
        for c in data:
            by_type.setdefault(c["type"], []).append(c["name"])
        lines = []
        for t, names in by_type.items():
            label = "Receitas" if t == "income" else "Despesas"
            lines.append(f"**{label}:** {', '.join(names)}")
        return "\n".join(lines)

    # ── get_recurring ─────────────────────────────────────────────────────────
    if name == "get_recurring":
        data = await call_backend("/api/v1/recurring-transactions", token)
        if not data:
            return "Nenhuma transação recorrente ativa."
        lines = ["**Recorrentes:**"]
        for r in data:
            lines.append(f"- {r['description']}: {_fmt_brl(r['amount'])} ({r['frequency']})")
        return "\n".join(lines)

    # ── get_dashboard ─────────────────────────────────────────────────────────
    if name == "get_dashboard":
        data = await call_backend("/api/v1/reports/dashboard", token)
        lines = [
            f"**Dashboard — {today.strftime('%B/%Y')}:**",
            f"- Saldo total: {_fmt_brl(data.get('total_balance', 0))}",
            f"- Receitas do mês: {_fmt_brl(data.get('monthly_income', 0))}",
            f"- Despesas do mês: {_fmt_brl(data.get('monthly_expense', 0))}",
        ]
        recent = data.get("recent_transactions") or []
        if recent:
            lines.append("\n**Últimas transações:**")
            for t in recent[:5]:
                sign = "+" if t["type"] == "income" else "-"
                lines.append(
                    f"- {t['transaction_date']} | {sign}{_fmt_brl(t['amount'])} | {t['description']}"
                )
        return "\n".join(lines)

    # ── get_credit_card_bills ─────────────────────────────────────────────────
    if name == "get_credit_card_bills":
        data = await call_backend("/api/v1/reports/credit-card-bills", token)
        cards = data if isinstance(data, list) else data.get("cards", [])
        if not cards:
            return "Nenhum cartão de crédito encontrado."
        lines = ["**Faturas dos cartões de crédito:**"]
        for card in cards:
            lines.append(
                f"\n**{card['name']}** (fecha dia {card['closing_day']}, vence dia {card['due_day']})"
            )
            current = card.get("current_bill") or {}
            nxt = card.get("next_bill") or {}
            lines.append(
                f"- Fatura atual ({current.get('period', '-')}): {_fmt_brl(current.get('total', 0))}"
            )
            lines.append(
                f"- Próxima fatura ({nxt.get('period', '-')}): {_fmt_brl(nxt.get('total', 0))}"
            )
        return "\n".join(lines)

    return f"Ferramenta '{name}' não reconhecida."
