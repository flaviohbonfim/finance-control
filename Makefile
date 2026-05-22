.PHONY: lint format check fix \
        lint-backend lint-frontend lint-app \
        format-backend format-frontend format-app

# ── Backend + MCP ─────────────────────────────────────────────────────────────

lint-backend:
	cd backend && poetry run ruff check .
	cd mcp-server && poetry run ruff check .

format-backend:
	cd backend && poetry run ruff format .
	cd mcp-server && poetry run ruff format .

fix-backend:
	cd backend && poetry run ruff check . --fix
	cd mcp-server && poetry run ruff check . --fix

# ── Frontend (React) ──────────────────────────────────────────────────────────

lint-frontend:
	cd frontend && npm run lint
	cd frontend && npx tsc --noEmit

format-frontend:
	cd frontend && npx prettier --write "src/**/*.{ts,tsx}"

# ── App (Flutter) ─────────────────────────────────────────────────────────────

lint-app:
	cd app && flutter analyze

format-app:
	cd app && dart format lib/

# ── Atalhos globais ───────────────────────────────────────────────────────────

lint: lint-backend lint-frontend lint-app

format: format-backend format-frontend format-app

# Roda format + lint em tudo (ideal antes do commit)
check: format lint
