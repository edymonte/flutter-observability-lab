#!/usr/bin/env bash
# Espera o BFF subir e roda a suíte de cenários. Usado localmente e no CI.
set -euo pipefail
BFF_URL="${BFF_URL:-http://localhost:8080}"
for i in $(seq 1 30); do
  if curl -fsS "$BFF_URL/health" >/dev/null 2>&1; then break; fi
  echo "aguardando BFF ($i)..."; sleep 2
done
docker compose exec -T bff node scripts/run-suite.js http://127.0.0.1:8080
