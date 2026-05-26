TOOLS = [
    {
        "name": "get_dashboard",
        "description": (
            "Visão geral das finanças do mês atual: saldo total de todas as contas, "
            "receitas e despesas do mês, e últimas transações. "
            "Use como ponto de partida quando o usuário quiser um resumo rápido."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
        "annotations": {"title": "Get Dashboard", "readOnlyHint": True, "destructiveHint": False},
    },
    {
        "name": "get_monthly_summary",
        "description": (
            "Resumo financeiro completo de um mês: total de receitas, total de despesas, "
            "saldo do período, ranking de despesas por categoria (com valor e percentual) "
            "e as 10 maiores despesas individuais. "
            "Use para perguntas como: 'quanto gastei em maio?', 'qual categoria mais gastei?', "
            "'quanto foi com alimentação no mês X?'. "
            "Padrão: mês e ano atuais."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "month": {"type": "integer", "description": "Mês (1-12). Padrão: mês atual."},
                "year": {"type": "integer", "description": "Ano com 4 dígitos. Padrão: ano atual."},
            },
        },
        "annotations": {
            "title": "Get Monthly Summary",
            "readOnlyHint": True,
            "destructiveHint": False,
        },
    },
    {
        "name": "list_transactions",
        "description": (
            "Lista todas as transações de um mês específico, ordenadas da mais recente para a mais antiga. "
            "Retorna até 100 lançamentos com data, valor, descrição e categoria. "
            "Compras parceladas aparecem individualmente por mês — isso é correto e esperado. "
            "Use para: 'quais foram minhas despesas de maio?', 'mostre meus gastos com alimentação em abril', "
            "'liste as receitas de junho'. "
            "Padrão: mês e ano atuais. "
            "Para totais e percentuais por categoria, prefira get_monthly_summary."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "month": {"type": "integer", "description": "Mês (1-12). Padrão: mês atual."},
                "year": {"type": "integer", "description": "Ano com 4 dígitos. Padrão: ano atual."},
                "type": {
                    "type": "string",
                    "enum": ["income", "expense"],
                    "description": "Filtrar por tipo: income (receita) ou expense (despesa). Omita para trazer ambos.",
                },
                "category_name": {
                    "type": "string",
                    "description": "Filtrar por categoria (ex: 'Alimentação', 'Lazer'). Case-insensitive.",
                },
            },
        },
        "annotations": {
            "title": "List Transactions",
            "readOnlyHint": True,
            "destructiveHint": False,
        },
    },
    {
        "name": "get_accounts",
        "description": (
            "Lista todas as contas do usuário com saldos atuais "
            "(contas correntes, poupança, cartões de crédito, investimentos)."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
        "annotations": {"title": "Get Accounts", "readOnlyHint": True, "destructiveHint": False},
    },
    {
        "name": "get_categories",
        "description": "Lista todas as categorias de receita e despesa cadastradas.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "enum": ["income", "expense"],
                    "description": "Filtrar por tipo. Omita para listar todas.",
                },
            },
        },
        "annotations": {"title": "Get Categories", "readOnlyHint": True, "destructiveHint": False},
    },
    {
        "name": "get_recurring",
        "description": "Lista assinaturas e pagamentos recorrentes ativos (salários, aluguel, streaming etc.).",
        "inputSchema": {"type": "object", "properties": {}, "required": []},
        "annotations": {"title": "Get Recurring", "readOnlyHint": True, "destructiveHint": False},
    },
    {
        "name": "get_credit_card_bills",
        "description": (
            "Faturas dos cartões de crédito: valor atual, próxima fatura e datas de fechamento/vencimento. "
            "Use quando o usuário perguntar sobre fatura, valor a pagar ou débitos no cartão."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
        "annotations": {
            "title": "Get Credit Card Bills",
            "readOnlyHint": True,
            "destructiveHint": False,
        },
    },
]
