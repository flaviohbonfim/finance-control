# Finance Control

Aplicação web de controle financeiro pessoal com dashboard, gestão de transações, contas, categorias, recorrências e assistente de IA integrado.

---

## Funcionalidades

- **Dashboard** — saldo total, receitas e despesas do mês, gráficos de evolução e distribuição por categoria
- **Transações** — lançamento manual de receitas e despesas com categorização e filtros avançados
- **Contas** — múltiplas contas (corrente, poupança, cartão de crédito, etc.) com saldo em tempo real
- **Categorias** — categorias personalizadas com ícone e cor para receitas e despesas
- **Recorrências** — transações recorrentes mensais com lançamento em um clique
- **Relatórios** — resumo mensal anual e detalhamento por categoria
- **Assistente de IA** — chat com Groq (Llama 3.3 70B) que consulta e cria transações por linguagem natural
- **Temas** — múltiplos temas visuais com cor de destaque personalizável

---

## Stack

### Frontend
| Tecnologia | Uso |
|---|---|
| React 18 + TypeScript | UI |
| Vite | Build & dev server |
| Tailwind CSS | Estilização |
| TanStack Query | Cache e fetching de dados |
| React Router v6 | Roteamento |
| Zustand | Estado global (auth, tema) |
| React Hook Form | Formulários |
| Recharts | Gráficos |
| Lucide React | Ícones |
| React Markdown | Renderização de markdown no chat |

### Backend
| Tecnologia | Uso |
|---|---|
| FastAPI | API REST + SSE (streaming) |
| SQLAlchemy (async) | ORM |
| MySQL + aiomysql | Banco de dados |
| Alembic | Migrações |
| Pydantic v2 | Validação e schemas |
| Python-JOSE + bcrypt | Autenticação JWT |
| Groq (Llama 3.3 70B) | Chat da IA (tool calling + streaming) |
| Google Gemini | Auto-categorização de transações |

### Infra
| Tecnologia | Uso |
|---|---|
| Docker + Docker Compose | Containers |
| Oracle Cloud ARM64 | Servidor de produção |
| Cloudflare | DNS + SSL |
| nginx | Reverse proxy + SSE buffering |
| GitHub Actions | CI (lint + build) e release automatizado |

---

## Rodando localmente

### Pré-requisitos

- Node.js 20+
- Python 3.11+
- Poetry
- MySQL 8+ (ou Docker)

### 1. Clone o repositório

```bash
git clone <repo-url>
cd finance-control
```

### 2. Backend

```bash
cd backend
cp .env.example .env
# Edite .env com suas credenciais (DATABASE_URL, SECRET_KEY, GROQ_API_KEY, GEMINI_API_KEY)

poetry install
poetry run alembic upgrade head
poetry run uvicorn app.main:app --reload --port 8000
```

### 3. Frontend

```bash
cd frontend
npm install
npm run dev
# Acesse http://localhost:5173
```

> O frontend usa proxy Vite: chamadas para `/api` são redirecionadas para `http://localhost:8000`.

### 4. Com Docker (alternativa)

```bash
# Na raiz do projeto
docker compose up --build
# API em :8000, frontend em :5173
```

---

## Variáveis de ambiente

Arquivo `backend/.env` (baseado em `.env.example`):

```env
DATABASE_URL=mysql+aiomysql://user:pass@localhost:3306/finance_control
SECRET_KEY=sua-chave-secreta
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080
CORS_ORIGINS=http://localhost:5173
GROQ_API_KEY=          # https://console.groq.com
GEMINI_API_KEY=        # https://aistudio.google.com (opcional, para auto-categorização)
```

---

## Deploy em produção

O deploy usa Docker Compose com imagens buildadas localmente e push para o servidor via SSH. O pipeline do GitHub Actions:

1. **CI** (`ci.yml`) — roda `ruff` (lint) e `npm run build` (TypeScript + Vite) em cada push
2. **Release** (`release.yml`) — executado apenas após o CI passar; faz bump de versão via `standard-version`, gera tag e release no GitHub

Para deploy manual:

```bash
# No servidor
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d --force-recreate
```

---

## Estrutura do projeto

```
finance-control/
├── backend/
│   ├── app/
│   │   ├── api/v1/endpoints/   # Rotas (auth, accounts, transactions, ai, ...)
│   │   ├── core/               # Config, database, segurança
│   │   ├── models/             # SQLAlchemy models
│   │   └── schemas/            # Pydantic schemas
│   ├── alembic/                # Migrações de banco
│   └── pyproject.toml
├── frontend/
│   ├── src/
│   │   ├── components/         # Componentes reutilizáveis (ui/, chat/, layout/)
│   │   ├── pages/              # Páginas (Dashboard, Transactions, Settings, ...)
│   │   ├── hooks/              # React Query hooks
│   │   ├── store/              # Zustand stores (auth, theme)
│   │   └── types/              # TypeScript types
│   └── package.json
├── deploy/                     # nginx config
└── docker-compose.yml
```
