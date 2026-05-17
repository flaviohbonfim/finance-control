#!/usr/bin/env bash
# =============================================================================
# auto-deploy.sh — Finance Control auto-deploy via cron
#
# Roda no servidor Oracle Cloud ARM64. Verifica se há nova release no GitHub
# e faz o deploy automaticamente usando Docker Compose.
#
# Cron recomendado (a cada 5 minutos):
#   */5 * * * * /opt/finance-control/deploy/auto-deploy.sh >> /var/log/finance-deploy.log 2>&1
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuração — ajuste conforme seu ambiente
# ---------------------------------------------------------------------------
GITHUB_REPO="${GITHUB_REPO:-seu-usuario/finance-control}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/finance-control}"
COMPOSE_FILE="${DEPLOY_DIR}/docker-compose.prod.yml"
ENV_FILE="${DEPLOY_DIR}/.env.prod"
VERSION_FILE="${DEPLOY_DIR}/.current_version"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"          # opcional: aumenta rate limit da API
REGISTRY="ghcr.io"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# ---------------------------------------------------------------------------
log() { echo "${LOG_PREFIX} $*"; }
die() { log "ERRO: $*"; exit 1; }

# ---------------------------------------------------------------------------
# Busca a última release publicada no GitHub
# ---------------------------------------------------------------------------
fetch_latest_release() {
  local url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
  local headers=(-H "Accept: application/vnd.github+json")
  [ -n "${GITHUB_TOKEN}" ] && headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

  curl -fsSL "${headers[@]}" "${url}" 2>/dev/null \
    | grep '"tag_name"' \
    | head -n1 \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

# ---------------------------------------------------------------------------
# Versão atualmente em execução (salva em arquivo após cada deploy)
# ---------------------------------------------------------------------------
current_version() {
  [ -f "${VERSION_FILE}" ] && cat "${VERSION_FILE}" || echo "none"
}

# ---------------------------------------------------------------------------
# Faz login no GHCR e puxa as imagens da nova release
# ---------------------------------------------------------------------------
pull_images() {
  local tag="$1"
  log "Baixando imagens da release ${tag}..."

  if [ -n "${GITHUB_TOKEN}" ]; then
    echo "${GITHUB_TOKEN}" | docker login "${REGISTRY}" -u "${GITHUB_REPO%%/*}" --password-stdin
  fi

  docker pull "${REGISTRY}/${GITHUB_REPO}/backend:${tag}"
  docker pull "${REGISTRY}/${GITHUB_REPO}/frontend:${tag}"
}

# ---------------------------------------------------------------------------
# Executa as migrations do Alembic antes de subir a nova versão
# ---------------------------------------------------------------------------
run_migrations() {
  local tag="$1"
  log "Executando migrations..."
  docker run --rm \
    --env-file "${ENV_FILE}" \
    --network host \
    "${REGISTRY}/${GITHUB_REPO}/backend:${tag}" \
    sh -c "cd /app && alembic upgrade head"
}

# ---------------------------------------------------------------------------
# Reinicia os serviços com a nova tag
# ---------------------------------------------------------------------------
restart_services() {
  local tag="$1"
  log "Reiniciando serviços com tag ${tag}..."
  export RELEASE_TAG="${tag}"
  export GITHUB_REPOSITORY="${GITHUB_REPO}"

  docker compose -f "${COMPOSE_FILE}" pull  2>/dev/null || true
  docker compose -f "${COMPOSE_FILE}" up -d --remove-orphans
  docker image prune -f --filter "until=24h" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Healthcheck pós-deploy
# ---------------------------------------------------------------------------
healthcheck() {
  local retries=12
  log "Aguardando healthcheck..."
  for i in $(seq 1 ${retries}); do
    if curl -fsSL http://localhost:8000/health >/dev/null 2>&1; then
      log "Healthcheck OK após ${i}x5s"
      return 0
    fi
    sleep 5
  done
  log "AVISO: healthcheck não respondeu em tempo hábil"
  return 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  log "Verificando novas releases em ${GITHUB_REPO}..."

  [ -f "${COMPOSE_FILE}" ] || die "docker-compose.prod.yml não encontrado em ${DEPLOY_DIR}"
  [ -f "${ENV_FILE}" ]     || die ".env.prod não encontrado em ${DEPLOY_DIR}"

  LATEST="$(fetch_latest_release)"
  CURRENT="$(current_version)"

  if [ -z "${LATEST}" ]; then
    log "Não foi possível obter a versão mais recente. Abortando."
    exit 0
  fi

  if [ "${LATEST}" = "${CURRENT}" ]; then
    log "Já na versão ${CURRENT}. Nada a fazer."
    exit 0
  fi

  log "Nova versão disponível: ${CURRENT} → ${LATEST}"

  pull_images "${LATEST}"
  run_migrations "${LATEST}"
  restart_services "${LATEST}"

  if healthcheck; then
    echo "${LATEST}" > "${VERSION_FILE}"
    log "Deploy da versão ${LATEST} concluído com sucesso!"
  else
    log "AVISO: Deploy realizado mas healthcheck falhou. Verifique os logs."
    log "  docker compose -f ${COMPOSE_FILE} logs --tail=50"
  fi
}

main "$@"
