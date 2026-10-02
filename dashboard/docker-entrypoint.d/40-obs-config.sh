#!/bin/sh
# Gera o config.js do dashboard a partir das variáveis de ambiente do container.
set -e
cat > /usr/share/nginx/html/config.js <<CFG
window.OBS_CONFIG = {
  rumApplicationId: "${DD_RUM_APPLICATION_ID:-}",
  rumClientToken: "${DD_RUM_CLIENT_TOKEN:-}",
  site: "${DD_SITE:-datadoghq.com}",
  env: "${DD_ENV:-lab}",
  version: "${DD_VERSION:-0.1.0}",
  rumService: "${DD_RUM_SERVICE:-loja-app-pagamento-web}"
};
CFG
if [ -n "${DD_RUM_CLIENT_TOKEN:-}" ]; then
  echo "[obs-config] RUM habilitado (site=${DD_SITE:-datadoghq.com}, env=${DD_ENV:-lab})"
else
  echo "[obs-config] RUM desabilitado (DD_RUM_CLIENT_TOKEN vazio) - modo local"
fi
