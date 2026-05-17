#!/usr/bin/env bash
# =============================================================================
# setup-server.sh — Configuração inicial do servidor Oracle Cloud ARM64
#
# Execute UMA VEZ como root (ou com sudo) após provisionar a VM.
# Testado em: Oracle Linux 8 / Ubuntu 22.04 ARM64
# =============================================================================
set -euo pipefail

GITHUB_REPO="${1:-seu-usuario/finance-control}"
DEPLOY_DIR="/opt/finance-control"

log() { echo "[SETUP] $*"; }

# ---------------------------------------------------------------------------
# 1. Atualiza o sistema e instala dependências
# ---------------------------------------------------------------------------
log "Atualizando pacotes..."
if command -v dnf &>/dev/null; then
  dnf update -y
  dnf install -y curl git vim
elif command -v apt-get &>/dev/null; then
  apt-get update -y
  apt-get install -y curl git vim
fi

# ---------------------------------------------------------------------------
# 2. Instala Docker Engine (ARM64)
# ---------------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
  log "Instalando Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  usermod -aG docker "${SUDO_USER:-$(logname)}"
  log "Docker instalado. Re-login necessário para usar sem sudo."
else
  log "Docker já instalado."
fi

# ---------------------------------------------------------------------------
# 3. Instala Docker Compose plugin
# ---------------------------------------------------------------------------
if ! docker compose version &>/dev/null 2>&1; then
  log "Instalando Docker Compose plugin..."
  ARCH="$(uname -m)"
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

# ---------------------------------------------------------------------------
# 4. Cria estrutura de diretórios
# ---------------------------------------------------------------------------
log "Criando diretório de deploy em ${DEPLOY_DIR}..."
mkdir -p "${DEPLOY_DIR}/deploy"
mkdir -p /var/log

# ---------------------------------------------------------------------------
# 5. Copia arquivos de configuração
# ---------------------------------------------------------------------------
log "Copiando docker-compose.prod.yml e script de deploy..."
cp "$(dirname "$0")/../docker-compose.prod.yml" "${DEPLOY_DIR}/"
cp "$(dirname "$0")/auto-deploy.sh" "${DEPLOY_DIR}/deploy/"
chmod +x "${DEPLOY_DIR}/deploy/auto-deploy.sh"

# ---------------------------------------------------------------------------
# 6. Cria .env.prod (template — edite com valores reais)
# ---------------------------------------------------------------------------
if [ ! -f "${DEPLOY_DIR}/.env.prod" ]; then
  log "Criando .env.prod (EDITE com suas credenciais reais)..."
  cat > "${DEPLOY_DIR}/.env.prod" << 'ENVEOF'
# Backend
DATABASE_URL=mysql+aiomysql://finance_user:CHANGE_ME@SEU_IP_MYSQL:3306/finance_control
SECRET_KEY=GERE_UMA_CHAVE_SEGURA_AQUI
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080
CORS_ORIGINS=https://seu-dominio.com

# Registry / Deploy
GITHUB_REPOSITORY=seu-usuario/finance-control
RELEASE_TAG=latest

# Opcional: token para evitar rate limit da GitHub API
GITHUB_TOKEN=
ENVEOF
  log "IMPORTANTE: edite ${DEPLOY_DIR}/.env.prod antes de rodar o deploy!"
fi

# ---------------------------------------------------------------------------
# 7. Configura cron para auto-deploy a cada 5 minutos
# ---------------------------------------------------------------------------
log "Configurando cron de auto-deploy..."
CRON_CMD="*/5 * * * * GITHUB_REPO=${GITHUB_REPO} DEPLOY_DIR=${DEPLOY_DIR} /bin/bash ${DEPLOY_DIR}/deploy/auto-deploy.sh >> /var/log/finance-deploy.log 2>&1"
(crontab -l 2>/dev/null | grep -v "auto-deploy.sh"; echo "${CRON_CMD}") | crontab -
log "Cron configurado: verifica novas releases a cada 5 minutos."

# ---------------------------------------------------------------------------
# 8. Configura logrotate
# ---------------------------------------------------------------------------
cat > /etc/logrotate.d/finance-deploy << 'EOF'
/var/log/finance-deploy.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
EOF

# ---------------------------------------------------------------------------
# 9. Abre portas no firewall (Oracle Cloud usa iptables + security lists)
# ---------------------------------------------------------------------------
if command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --add-port=80/tcp
  firewall-cmd --permanent --add-port=443/tcp
  firewall-cmd --permanent --add-port=8000/tcp
  firewall-cmd --reload
fi

# Oracle Cloud também exige liberar via iptables (instâncias ARM)
iptables -I INPUT -p tcp --dport 80 -j ACCEPT   2>/dev/null || true
iptables -I INPUT -p tcp --dport 443 -j ACCEPT  2>/dev/null || true
iptables -I INPUT -p tcp --dport 8000 -j ACCEPT 2>/dev/null || true

log ""
log "=================================================="
log "Servidor configurado com sucesso!"
log ""
log "Próximos passos:"
log "  1. Edite ${DEPLOY_DIR}/.env.prod com as credenciais reais"
log "  2. Configure o MySQL na Oracle Cloud"
log "  3. Adicione GITHUB_TOKEN ao cron para evitar rate limit:"
log "     crontab -e"
log "  4. O primeiro deploy ocorrerá automaticamente em até 5 minutos"
log "     após o próximo push na branch main."
log ""
log "Para forçar deploy manual:"
log "  GITHUB_REPO=${GITHUB_REPO} DEPLOY_DIR=${DEPLOY_DIR} ${DEPLOY_DIR}/deploy/auto-deploy.sh"
log "=================================================="
