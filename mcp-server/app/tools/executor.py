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


async def execute_tool(name: str, arguments: dict, token: str) -> str:
    today = date.today()

    if name == "get_accounts":
        data = await call_backend("/api/v1/accounts", token)
        if not data:
            return "Nenhuma conta cadastrada."
        lines = ["**Contas:**"]
        for acc in data:
            balance = (
                f"R$ {float(acc['balance']):,.2f}".replace(",", "X")
                .replace(".", ",")
                .replace("X", ".")
            )
            lines.append(f"- {acc['name']} ({acc['type']}): {balance}")
        return "\n".join(lines)

    if name == "get_transactions":
        params = {
            "start_date": arguments.get("start_date"),
            "end_date": arguments.get("end_date"),
            "transaction_type": arguments.get("type"),
            "limit": arguments.get("limit", 30),
        }
        data = await call_backend("/api/v1/transactions", token, params)
        items = data if isinstance(data, list) else data.get("items", [])
        if not items:
            return "Nenhuma transação encontrada para os filtros informados."
        lines = [f"**{len(items)} transação(ões) encontrada(s):**"]
        for t in items:
            sign = "+" if t["type"] == "income" else "-"
            amount = (
                f"R$ {float(t['amount']):,.2f}".replace(",", "X")
                .replace(".", ",")
                .replace("X", ".")
            )
            cat = t.get("category", {}) or {}
            cat_name = (
                cat.get("name", "Sem categoria") if isinstance(cat, dict) else "Sem categoria"
            )
            lines.append(
                f"- {t['transaction_date']} | {sign}{amount} | {t['description']} | {cat_name}"
            )
        return "\n".join(lines)

    if name == "get_monthly_summary":
        month = arguments.get("month", today.month)
        year = arguments.get("year", today.year)
        data = await call_backend(
            "/api/v1/reports/monthly-summary", token, {"month": month, "year": year}
        )
        income = (
            f"R$ {float(data.get('total_income', 0)):,.2f}".replace(",", "X")
            .replace(".", ",")
            .replace("X", ".")
        )
        expense = (
            f"R$ {float(data.get('total_expense', 0)):,.2f}".replace(",", "X")
            .replace(".", ",")
            .replace("X", ".")
        )
        balance = float(data.get("total_income", 0)) - float(data.get("total_expense", 0))
        bal_str = f"R$ {balance:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
        lines = [
            f"**Resumo de {month:02d}/{year}:**",
            f"- Receitas: {income}",
            f"- Despesas: {expense}",
            f"- Saldo do período: {bal_str}",
        ]
        by_cat = data.get("by_category") or []
        if by_cat:
            lines.append("\n**Por categoria:**")
            for c in by_cat:
                amt = (
                    f"R$ {float(c['total']):,.2f}".replace(",", "X")
                    .replace(".", ",")
                    .replace("X", ".")
                )
                lines.append(f"- {c['name']}: {amt}")
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
            amount = (
                f"R$ {float(r['amount']):,.2f}".replace(",", "X")
                .replace(".", ",")
                .replace("X", ".")
            )
            lines.append(f"- {r['description']}: {amount} ({r['frequency']})")
        return "\n".join(lines)

    if name == "get_dashboard":
        data = await call_backend("/api/v1/reports/dashboard", token)
        total_bal = (
            f"R$ {float(data.get('total_balance', 0)):,.2f}".replace(",", "X")
            .replace(".", ",")
            .replace("X", ".")
        )
        income = (
            f"R$ {float(data.get('monthly_income', 0)):,.2f}".replace(",", "X")
            .replace(".", ",")
            .replace("X", ".")
        )
        expense = (
            f"R$ {float(data.get('monthly_expense', 0)):,.2f}".replace(",", "X")
            .replace(".", ",")
            .replace("X", ".")
        )
        lines = [
            f"**Dashboard — {today.strftime('%B/%Y')}:**",
            f"- Saldo total: {total_bal}",
            f"- Receitas do mês: {income}",
            f"- Despesas do mês: {expense}",
        ]
        recent = data.get("recent_transactions") or []
        if recent:
            lines.append("\n**Últimas transações:**")
            for t in recent[:5]:
                sign = "+" if t["type"] == "income" else "-"
                amount = (
                    f"R$ {float(t['amount']):,.2f}".replace(",", "X")
                    .replace(".", ",")
                    .replace("X", ".")
                )
                lines.append(f"- {t['transaction_date']} | {sign}{amount} | {t['description']}")
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
            cur_total = (
                f"R$ {float(current.get('total', 0)):,.2f}".replace(",", "X")
                .replace(".", ",")
                .replace("X", ".")
            )
            nxt_total = (
                f"R$ {float(nxt.get('total', 0)):,.2f}".replace(",", "X")
                .replace(".", ",")
                .replace("X", ".")
            )
            lines.append(f"- Fatura atual ({current.get('period', '-')}): {cur_total}")
            lines.append(f"- Próxima fatura ({nxt.get('period', '-')}): {nxt_total}")
        return "\n".join(lines)

    return f"Ferramenta '{name}' não reconhecida."
