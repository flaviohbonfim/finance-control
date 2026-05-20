# Finance Control

Aplicação de controle financeiro pessoal com dashboard web, app mobile nativo e assistente de IA acessível via chat e Telegram.

---

## Funcionalidades

- **Dashboard** — saldo total, receitas e despesas do mês, gráficos de evolução e distribuição por categoria
- **Transações** — lançamento manual de receitas e despesas com categorização e filtros avançados
- **Contas** — múltiplas contas (corrente, poupança, cartão de crédito, etc.) com saldo em tempo real
- **Categorias** — categorias personalizadas com cor para receitas e despesas
- **Recorrências** — transações recorrentes mensais com lançamento em um clique
- **Relatórios** — resumo mensal anual e detalhamento por categoria
- **Assistente de IA** — chat com Groq (Llama 3.3 70B) que consulta e cria transações por linguagem natural
- **Temas** — 9 temas visuais (Claro, Escuro, Dracula, Nord, Catppuccin, Tokyo Night, Rose Piné, Monokai, Solarized)
- **App mobile** — aplicativo Flutter para iOS e Android com todas as funcionalidades do web
- **Telegram Bot** — acesso ao assistente de IA diretamente pelo Telegram, vinculado à conta do usuário

---

## Stack

### Frontend (Web)
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

### Mobile (iOS & Android)
| Tecnologia | Uso |
|---|---|
| Flutter 3 + Dart | UI multiplataforma |
| Riverpod | Estado global e providers |
| GoRouter | Navegação |
| Dio | HTTP client |
| FlutterSecureStorage | Persistência do token JWT |
| fl_chart | Gráficos |
| flutter_markdown | Renderização de markdown no chat |
| url_launcher | Abertura de links externos (Telegram) |

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

### Telegram Bot
| Tecnologia | Uso |
|---|---|
| python-telegram-bot 21 | Framework do bot |
| httpx | Comunicação com o backend via HTTP interno |

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
- Flutter 3.x
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
# Edite .env com suas credenciais

poetry install
poetry run alembic upgrade head
poetry run uvicorn app.main:app --reload --port 8000
```

### 3. Frontend Web

```bash
cd frontend
npm install
npm run dev
# Acesse http://localhost:5173
```

> O frontend usa proxy Vite: chamadas para `/api` são redirecionadas para `http://localhost:8000`.

### 4. App Mobile

```bash
cd mobile
flutter pub get
flutter run          # seleciona o dispositivo interativamente
flutter run -d <id>  # dispositivo específico (use: flutter devices)
```

Para gerar APK de release:

```bash
flutter build apk --release
# Saída: build/app/outputs/flutter-apk/app-release.apk
```

### 5. Telegram Bot

```bash
cd telegram-bot
cp .env.example .env
# Edite .env com TELEGRAM_BOT_TOKEN, BACKEND_URL e TELEGRAM_INTERNAL_SECRET

poetry install
poetry run python bot.py
```

### 6. Com Docker (alternativa)

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

TELEGRAM_BOT_USERNAME= # @username do bot (sem o @)
TELEGRAM_INTERNAL_SECRET= # secret compartilhado entre backend e bot
```

Arquivo `telegram-bot/.env`:

```env
TELEGRAM_BOT_TOKEN=        # token do BotFather
BACKEND_URL=http://localhost:8000
TELEGRAM_INTERNAL_SECRET=  # mesmo valor do backend
```

---

## Vinculação ao Telegram

1. No app (web ou mobile), acesse **Configurações → Telegram → Vincular**
2. O sistema gera um link temporário (válido por 10 minutos) e redireciona para o bot
3. Confirme no Telegram — a conta fica vinculada
4. A partir daí, mensagens enviadas ao bot usam o assistente de IA da sua conta

---

## Deploy em produção

O deploy usa Docker Compose com imagens buildadas localmente e push para o servidor via SSH. O pipeline do GitHub Actions:

1. **CI** (`ci.yml`) — roda `ruff` (lint) e `npm run build` (TypeScript + Vite) em cada push
2. **Release** (`release.yml`) — executado após o CI passar; faz bump de versão, gera tag e release no GitHub e publica imagens Docker — **ignorado automaticamente se apenas o app mobile foi alterado**, pois mudanças em `mobile/` não afetam o servidor

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
│   │   ├── api/v1/endpoints/   # Rotas (auth, accounts, transactions, ai, telegram, ...)
│   │   ├── core/               # Config, database, segurança
│   │   ├── models/             # SQLAlchemy models
│   │   └── schemas/            # Pydantic schemas
│   ├── alembic/                # Migrações de banco
│   └── pyproject.toml
├── frontend/
│   ├── src/
│   │   ├── components/         # Componentes reutilizáveis
│   │   ├── pages/              # Páginas (Dashboard, Transactions, Settings, ...)
│   │   ├── hooks/              # React Query hooks
│   │   ├── store/              # Zustand stores (auth, tema)
│   │   └── types/              # TypeScript types
│   └── package.json
├── mobile/
│   ├── lib/
│   │   ├── core/               # Auth, API client, tema, router, shell
│   │   ├── features/           # Telas (dashboard, transactions, accounts, ...)
│   │   └── shared/             # Widgets reutilizáveis
│   └── pubspec.yaml
├── telegram-bot/
│   ├── bot.py                  # Bot principal (polling + handlers)
│   ├── Dockerfile
│   └── pyproject.toml
├── deploy/                     # nginx config
└── docker-compose.yml
```
