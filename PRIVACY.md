# Privacy Policy — Finance Control MCP Connector

**Last updated:** 2026-05-25

## 1. Overview

The Finance Control MCP Connector ("the Connector") is a Model Context Protocol server that gives AI assistants (such as Claude) read-only access to your personal financial data stored in your Finance Control account. This policy explains exactly what data is accessed, how it is used, and what protections are in place.

## 2. What data the Connector reads

When you authorize the Connector and invoke one of its tools, it retrieves the following data from your Finance Control account on your behalf:

| Tool | Data retrieved |
|------|----------------|
| `get_accounts` | Account names, types (checking, savings, credit card, investment), and current balances |
| `get_transactions` | Transaction date, amount, description, category, and account — filtered to the date range or limit you specify |
| `get_monthly_summary` | Aggregated income and expense totals and per-category breakdown for a given month |
| `get_categories` | Category names and types (income / expense) |
| `get_recurring` | Name, amount, frequency, and status of recurring transactions (subscriptions, salary, fixed payments) |
| `get_dashboard` | Current-month totals and the most recent transactions |
| `get_credit_card_bills` | Credit card names, current billing period dates, current bill amount, next bill amount |

All data is fetched live from your Finance Control backend at the moment of the request. **No financial data is cached, stored, or persisted by the Connector at any point.**

## 3. What the Connector never does

- **Never writes, modifies, or deletes** any financial record. Every tool is strictly read-only (`readOnlyHint: true`).
- **Never stores** your account data, transaction history, balances, or any personally identifiable information on Connector infrastructure.
- **Never logs** financial data. Server logs record only request metadata (timestamp, HTTP method, response status code) for operational purposes; they never contain the content of tool responses.
- **Never shares** your financial data with any third party. Data flows only between your Finance Control backend and the AI assistant session that you initiated.

## 4. Authentication and authorization

Access to the Connector requires a valid OAuth 2.0 Bearer token issued by the Finance Control authorization server (`https://finance.apti.dev`). The token:

- Is scoped to your user account only — the Connector cannot access other users' data.
- Is validated on every request using HS256 signature verification.
- Is never stored by the Connector; it is used solely to authenticate the proxied request to your backend and then discarded.
- Expires according to the token lifetime configured in your Finance Control account.

The Connector enforces an origin allowlist (`claude.ai`, `claude.com`) so that only authorized AI clients can make requests.

## 5. Data in transit

All communication between the AI assistant, the Connector, and your Finance Control backend uses HTTPS with TLS. No financial data is transmitted over unencrypted connections.

## 6. Data retention

The Connector retains **no user data**. Because data is fetched live and never persisted, there is nothing to delete or expire on the Connector side. Your financial data itself remains in your Finance Control account, governed by the Finance Control application's own data retention policies.

## 7. Third-party services

The Connector does not transmit your financial data to any third-party analytics, monitoring, or advertising service. The only external party that receives your data is the AI assistant (Claude) running in your active session — which is governed by Anthropic's own [Privacy Policy](https://www.anthropic.com/privacy).

## 8. Your rights

Because the Connector stores no personal data, there is no data to access, correct, or delete on the Connector side. To manage your underlying financial data, log in to your Finance Control account directly.

## 9. Changes to this policy

Material changes to this policy will be reflected in an updated "Last updated" date at the top of this document. Continued use of the Connector after a policy update constitutes acceptance of the revised terms.

## 10. Contact

Questions or concerns about this privacy policy can be directed to:

**Flávio Henrique Bonfim**
Email: flaviohbonfim@gmail.com
Project: https://github.com/flavim/finance-control
