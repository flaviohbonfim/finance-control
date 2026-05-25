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


def _fmt_brl(value) -> str:
    return f"R$ {float(value):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


async def execute_tool(name: str, arguments: dict, token: str) -> str:
    today = date.today()

    if name == "get_accounts":
        data = await call_backend("/api/v1/accounts", token)
        if not data:
            return "Nenhuma conta cadastrada."
        lines = ["**Contas:**"]
        for acc in data:
            lines.append(f"- {acc['name']} ({acc['type']}): {_fmt_brl(acc['balance'])}")
        return "\n".join(lines)

    if name == "get_transactions":
        category_name = (arguments.get("category_name") or "").strip().lower()
        params = {
            "start_date": arguments.get("start_date"),
            "end_date": arguments.get("end_date"),
            "transaction_type": arguments.get("type"),
            "limit": arguments.get("limit", 100),
        }

        # If filtering by category, resolve to category_id first
        if category_name:
            cats = await call_backend("/api/v1/categories", token)
            match = next(
                (c for c in cats if c["name"].lower() == category_name),
                None,
            )
            if match:
                params["category_id"] = match["id"]
            else:
                # Partial match fallback
                match = next(
                    (c for c in cats if category_name in c["name"].lower()),
                    None,
                )
                if match:
                    params["category_id"] = match["id"]

        data = await call_backend("/api/v1/transactions", token, params)
        items = data if isinstance(data, list) else data.get("items", [])
        if not items:
            return "Nenhuma transação encontrada para os filtros informados."

        total = sum(float(t["amount"]) for t in items)
        tx_type = arguments.get("type")
        sign_total = "+" if tx_type == "income" else "-" if tx_type == "expense" else "±"

        lines = [
            f"**{len(items)} transação(ões) encontrada(s) — Total: {sign_total}{_fmt_brl(total)}**"
        ]
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
            f"**Resumo de {month:02d}/{year}:**",
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

    if name == "get_recurring":
        data = await call_backend("/api/v1/recurring-transactions", token)
        if not data:
            return "Nenhuma transação recorrente ativa."
        lines = ["**Recorrentes:**"]
        for r in data:
            lines.append(f"- {r['description']}: {_fmt_brl(r['amount'])} ({r['frequency']})")
        return "\n".join(lines)

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
