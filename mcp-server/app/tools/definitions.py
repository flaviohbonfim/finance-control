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
            "Lista transações financeiras individuais de um período. "
            "Sempre informe month+year (preferido) ou start_date+end_date. "
            "Transações parceladas aparecem com '(N/M)' na descrição — isso indica a parcela N de M; "
            "a data da transação é o vencimento desta parcela no mês consultado, o que é correto. "
            "Os resultados retornados já estão filtrados pelo período solicitado; não remova o filtro "
            "de data mesmo que veja itens parcelados — eles pertencem ao mês consultado. "
            "Para totais e breakdown por categoria use get_monthly_summary."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "month": {
                    "type": "integer",
                    "description": "Mês (1-12). Use com year para consultas mensais (preferido sobre start_date/end_date).",
                },
                "year": {
                    "type": "integer",
                    "description": "Ano com 4 dígitos. Use com month.",
                },
                "start_date": {
                    "type": "string",
                    "description": "Data início YYYY-MM-DD. Use apenas para intervalos personalizados.",
                },
                "end_date": {
                    "type": "string",
                    "description": "Data fim YYYY-MM-DD. Use apenas para intervalos personalizados.",
                },
                "type": {
                    "type": "string",
                    "enum": ["income", "expense"],
                    "description": "Filtrar por tipo: income (receita) ou expense (despesa)",
                },
                "category_name": {
                    "type": "string",
                    "description": (
                        "Nome da categoria para filtrar (ex: 'Alimentação', 'Lazer'). "
                        "A busca é case-insensitive e suporta correspondência parcial."
                    ),
                },
                "limit": {
                    "type": "integer",
                    "description": "Número máximo de transações a retornar (padrão: 100)",
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
            "Retorna o resumo completo de um mês: total de receitas, total de despesas, "
            "saldo do período, breakdown de despesas por categoria (com valor e percentual) "
            "e as maiores despesas do mês. "
            "É a ferramenta ideal para perguntas como 'quanto gastei em maio?', "
            "'qual foi minha maior despesa?', 'quanto gastei com alimentação no mês X?' "
            "— use-a antes de recorrer a get_transactions para consultas agregadas."
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
