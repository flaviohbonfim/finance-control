---
name: finance-control
description: Consulta dados financeiros pessoais via MCP Finance Control. Use para responder perguntas sobre saldos, transações, gastos por categoria, resumos mensais, assinaturas recorrentes e faturas de cartão de crédito. Ative sempre que o usuário mencionar finanças, dinheiro, gastos, saldo, cartão, fatura, orçamento ou categorias de despesa.
compatibility: Requires Finance Control MCP connector configured in Claude.ai
metadata:
  author: finance-control
  version: "1.0"
---

# Finance Control

Conector MCP para consultar dados financeiros pessoais do sistema Finance Control. Todas as tools são somente leitura.

---

## Tools disponíveis

### `get_dashboard`

Retorna visão geral do mês atual: saldo total de todas as contas, receitas e despesas do mês, últimas transações.

**Usar quando o usuário pedir:**
- "Como estão minhas finanças?"
- "Resumo rápido do mês"
- "Me dê um overview financeiro"
- "Como estou financeiramente?"
- "O que está acontecendo com meu dinheiro?"

---

### `get_accounts`

Lista todas as contas (corrente, poupança, cartão de crédito, investimentos) com saldos atuais.

**Usar quando o usuário pedir:**
- "Qual é o saldo da minha conta?"
- "Quais contas eu tenho?"
- "Quanto tenho no banco?"
- "Meu saldo atual"
- "Qual o saldo da [nome da conta]?"

---

### `get_monthly_summary`

Resumo financeiro completo de um mês: total de receitas, total de despesas, saldo do período, ranking de despesas por categoria (valor e percentual) e as 10 maiores despesas individuais.

**Parâmetros:** `month` (1–12, padrão: atual), `year` (4 dígitos, padrão: atual)

**Usar quando o usuário pedir:**
- "Quanto gastei em maio?"
- "Qual categoria mais gastei no mês passado?"
- "Resumo financeiro de março de 2026"
- "Quanto foi com alimentação este mês?"
- "Comparação de gastos de abril"
- "Minhas maiores despesas de junho"
- "Quanto entrou e saiu em fevereiro?"

**Preferir a `list_transactions` para:** totais e percentuais por categoria.

---

### `list_transactions`

Lista transações individuais de um mês (até 100), ordenadas da mais recente para a mais antiga. Suporta filtro por tipo e categoria.

**Parâmetros:** `month`, `year`, `type` (`income` | `expense`), `category_name`

**Usar quando o usuário pedir:**
- "Quais foram minhas despesas de maio?"
- "Mostre meus gastos com alimentação em abril"
- "Liste as receitas de junho"
- "O que comprei esta semana?"
- "Transações de [categoria] em [mês]"
- "Preciso ver cada lançamento"

**Não usar para:** totais por categoria → prefira `get_monthly_summary`.

---

### `get_categories`

Lista todas as categorias de receita e despesa cadastradas.

**Parâmetros:** `type` (`income` | `expense`, opcional)

**Usar quando o usuário pedir:**
- "Quais categorias de gasto eu tenho?"
- "Mostre as categorias de receita"
- "Que categorias existem no sistema?"
- Antes de filtrar `list_transactions` por categoria (para confirmar o nome exato).

---

### `get_recurring`

Lista assinaturas e pagamentos recorrentes ativos: salários, aluguel, streaming, mensalidades etc.

**Usar quando o usuário pedir:**
- "Quais são minhas assinaturas?"
- "Quanto pago de streaming por mês?"
- "Quais são meus gastos fixos?"
- "Mostre meus pagamentos recorrentes"
- "Qual é o meu salário cadastrado?"
- "Tenho alguma assinatura que posso cancelar?"

---

### `get_credit_card_bills`

Faturas dos cartões de crédito: valor atual, próxima fatura, datas de fechamento e vencimento.

**Usar quando o usuário pedir:**
- "Qual é o valor da minha fatura?"
- "Quanto devo no cartão?"
- "Quando vence minha fatura do Nubank?"
- "Fatura atual do cartão"
- "Quanto já gastei no crédito este mês?"
- "Data de vencimento do meu cartão"

---

## Combinações de tools

Para perguntas amplas, chame múltiplas tools na mesma resposta:

| Pergunta do usuário | Tools a chamar |
|---|---|
| "Como estão minhas finanças?" | `get_dashboard` + `get_monthly_summary` |
| "Análise completa do mês" | `get_dashboard` + `get_monthly_summary` + `get_recurring` |
| "Quanto tenho e quanto devo?" | `get_accounts` + `get_credit_card_bills` |
| "Meus gastos fixos e variáveis" | `get_recurring` + `get_monthly_summary` |
| "Visão patrimonial completa" | `get_accounts` + `get_credit_card_bills` + `get_recurring` |
| "Detalhes de [categoria] em [mês]" | `get_monthly_summary` + `list_transactions` (com `category_name`) |
| "Comparar dois meses" | `get_monthly_summary` (mês 1) + `get_monthly_summary` (mês 2) |

---

## Resolução de parâmetros de data

- "este mês" / "mês atual" → omita `month` e `year` (usa padrão)
- "mês passado" → `month = mês atual − 1`; se mês atual = 1, então `month = 12, year = ano atual − 1`
- "maio", "junho" etc. → converta para inteiro (1–12)
- Ano omitido → use o ano atual
- "primeiro trimestre" → chame `get_monthly_summary` três vezes (meses 1, 2, 3)

---

## Regras de prioridade

1. Totais e percentuais por categoria → `get_monthly_summary`, nunca `list_transactions`
2. Transações individuais ou detalhadas → `list_transactions` com filtros
3. Saldo preciso de conta → `get_accounts` (mais confiável que `get_dashboard` para este fim)
4. Faturas de cartão → `get_credit_card_bills` (não confundir com transações do cartão)
5. Nomes de categoria desconhecidos → chame `get_categories` antes de filtrar

---

## Tratamento de erros

- **Erro de autenticação:** oriente o usuário a reconectar o conector em Claude.ai → Configurações → Conectores → Finance Control.
- **Sem dados para o período:** informe claramente e sugira verificar um período diferente.
- **Categoria não encontrada:** chame `get_categories` para listar as disponíveis e corrija o filtro.
