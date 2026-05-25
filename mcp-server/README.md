# Finance Control — MCP Connector

Give Claude (or any MCP-compatible AI assistant) read-only access to your personal finances. Ask questions like *"How much did I spend on restaurants last month?"* or *"What's my credit card bill due this cycle?"* and get answers grounded in your real financial data — no copy-pasting spreadsheets required.

---

## What this connector does

The Finance Control MCP Connector acts as a secure bridge between AI assistants and your Finance Control account. It exposes seven **read-only** tools that let the AI query your accounts, transactions, budgets, and credit cards. The connector never writes, modifies, or deletes any data, and it never stores or caches any financial information between requests.

---

## Tools

| Tool | Description |
|------|-------------|
| `get_accounts` | Lists all financial accounts (checking, savings, credit cards, investments) with their current balances. |
| `get_transactions` | Retrieves transactions with optional filters for date range (`start_date` / `end_date`), type (`income` or `expense`), and result count (`limit`). |
| `get_monthly_summary` | Returns total income, total expenses, net balance, and a per-category breakdown for a given month and year. |
| `get_categories` | Lists all transaction categories, optionally filtered by type (`income` or `expense`). |
| `get_recurring` | Lists active recurring transactions — subscriptions, salary, fixed monthly bills — with their amounts and frequency. |
| `get_dashboard` | Snapshot of the current month: total balance across accounts, month-to-date income and expenses, and the most recent transactions. |
| `get_credit_card_bills` | For each credit card, shows the current billing period amount, next billing period amount, and the corresponding dates. |

All tools carry `readOnlyHint: true` and `destructiveHint: false` in their MCP annotations.

---

## Authentication

The connector uses **OAuth 2.0 with Bearer tokens** (JWT, HS256).

- The Finance Control authorization server is at `https://finance.apti.dev`.
- The discovery endpoint is at `https://finance.apti.dev/.well-known/oauth-authorization-server`.
- The protected-resource metadata is at `https://finance.apti.dev/.well-known/oauth-protected-resource`.
- Each request must include an `Authorization: Bearer <token>` header.
- Tokens are validated on every request and are scoped to a single user account.

The connector enforces an **origin allowlist** — only requests from `claude.ai` and `claude.com` are accepted.

---

## Setup

### Prerequisites

- A running Finance Control backend (see the root-level `docker-compose.yml`).
- Docker and Docker Compose, or Python 3.12+ with [uv](https://github.com/astral-sh/uv).
- A Finance Control user account to authorize.

### 1. Configure environment variables

Copy the example environment file and fill in your values:

```bash
cp mcp-server/.env.example mcp-server/.env
```

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRET_KEY` | JWT signing secret — must match the backend | `change-this-in-production` |
| `ALGORITHM` | JWT algorithm | `HS256` |
| `BACKEND_INTERNAL_URL` | Internal URL of the Finance Control backend | `http://backend:8000` |
| `PUBLIC_URL` | Public base URL of this deployment | `https://finance.apti.dev` |
| `MCP_ALLOWED_ORIGINS` | Comma-separated list of allowed `Origin` headers | `https://claude.ai,https://claude.com` |

### 2. Run with Docker Compose

```bash
docker compose up -d mcp-server
```

The server starts on port `8001` by default (see `docker-compose.yml`).

### 3. Run locally (development)

```bash
cd mcp-server
uv sync
uv run uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
```

### 4. Verify the server is up

```bash
curl https://finance.apti.dev/health
# {"status":"ok"}
```

### 5. Add the connector in Claude

1. Open Claude → **Settings** → **Connectors**.
2. Click **Add connector**.
3. Enter the MCP server URL: `https://finance.apti.dev`
4. Complete the OAuth authorization flow — you will be redirected to Finance Control to log in and grant access.
5. Once authorized, the seven Finance Control tools will appear in your Claude sessions.

---

## Security notes

- The connector validates the JWT signature on **every** request — there is no session state.
- Financial data returned by tools is passed directly to your AI session and is **never** stored on connector infrastructure.
- Rotate `SECRET_KEY` in both the backend and the MCP server simultaneously if a key is compromised.

---

## Privacy

All financial data is fetched live and read-only. No data is stored, cached, or shared with third parties by this connector.

See the full [Privacy Policy](../PRIVACY.md) for details on data handling, retention, and your rights.

---

## License

MIT — see [LICENSE](../LICENSE) at the repository root.
