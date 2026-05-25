TOOLS = [
    {
        "name": "get_accounts",
        "description": (
            "Lista todas as contas financeiras do usuário com seus saldos atuais. "
            "Inclui contas correntes, poupança, cartões de crédito e investimentos."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
        "annotations": {
            "title": "Get Accounts",
            "readOnlyHint": True,
            "destructiveHint": False,
        },
    },
    {
        "name": "get_transactions",
        "description": (
            "Lista transações financeiras com filtros opcionais por período, "
            "categoria, conta e tipo (receita/despesa)."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "start_date": {
                    "type": "string",
                    "description": "Data início no formato YYYY-MM-DD",
                },
                "end_date": {
                    "type": "string",
                    "description": "Data fim no formato YYYY-MM-DD",
                },
                "type": {
                    "type": "string",
                    "enum": ["income", "expense"],
                    "description": "Filtrar por tipo: income (receita) ou expense (despesa)",
                },
                "limit": {
                    "type": "integer",
                    "description": "Número máximo de transações a retornar (padrão: 30)",
                },
            },
        },
        "annotations": {
            "title": "Get Transactions",
            "readOnlyHint": True,
            "destructiveHint": False,
        },
    },
    {
        "name": "get_monthly_summary",
        "description": (
            "Retorna o resumo financeiro de um mês específico: total de receitas, "
            "total de despesas, saldo do período e breakdown por categoria."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "month": {
                    "type": "integer",
                    "description": "Mês (1-12). Padrão: mês atual.",
                },
                "year": {
                    "type": "integer",
                    "description": "Ano com 4 dígitos. Padrão: ano atual.",
                },
            },
        },
        "annotations": {
            "title": "Get Monthly Summary",
            "readOnlyHint": True,
            "destructiveHint": False,
        },
    },
    {
        "name": "get_categories",
        "description": "Lista todas as categorias financeiras do usuário.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "enum": ["income", "expense"],
                    "description": "Filtrar por tipo: income (receita) ou expense (despesa)",
                },
            },
        },
        "annotations": {
            "title": "Get Categories",
            "readOnlyHint": True,
            "destructiveHint": False,
        },
    },
    {
        "name": "get_recurring",
        "description": (
            "Lista as transações recorrentes ativas (assinaturas, salários, "
            "pagamentos mensais etc.)."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
        "annotations": {
            "title": "Get Recurring Transactions",
            "readOnlyHint": True,
            "destructiveHint": False,
        },
    },
    {
        "name": "get_dashboard",
        "description": (
            "Retorna o resumo do mês atual: saldo total, receitas e despesas do mês, "
            "e últimas transações. Ideal para uma visão geral rápida das finanças."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
        "annotations": {
            "title": "Get Dashboard",
            "readOnlyHint": True,
            "destructiveHint": False,
        },
    },
    {
        "name": "get_credit_card_bills",
        "description": (
            "Retorna as faturas dos cartões de crédito do usuário. "
            "Para cada cartão mostra o valor da fatura atual (período já fechado ou em aberto) "
            "e da próxima fatura, com as datas de cada período. "
            "Use esta ferramenta quando o usuário perguntar sobre fatura, valor a pagar, "
            "próxima fatura ou débitos no cartão de crédito."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
        "annotations": {
            "title": "Get Credit Card Bills",
            "readOnlyHint": True,
            "destructiveHint": False,
        },
    },
]
