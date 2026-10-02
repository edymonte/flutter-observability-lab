#!/usr/bin/env bash
set -euo pipefail

PROFILE="flutter-observability-lab"
CPUS=4
MEMORY_MB=6144
NAMESPACE="flutter-observability-lab"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --cpus) CPUS="$2"; shift 2 ;;
    --memory) MEMORY_MB="$2"; shift 2 ;;
    *) echo "Argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"

for command_name in docker minikube kubectl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name nao encontrado no WSL." >&2
    exit 1
  fi
done

cd "$ROOT"
minikube start --profile "$PROFILE" --driver docker --nodes 1 --cpus "$CPUS" --memory "$MEMORY_MB"
minikube --profile "$PROFILE" image build --tag flutter-observability-lab-services:local ./services
minikube --profile "$PROFILE" image build --tag flutter-observability-lab-dashboard:local ./dashboard

kubectl config use-context "$PROFILE" >/dev/null
kubectl apply --kustomize ./k8s
kubectl rollout status deployment/acquirer --namespace "$NAMESPACE" --timeout 180s
kubectl rollout status deployment/payment --namespace "$NAMESPACE" --timeout 180s
kubectl rollout status deployment/bff --namespace "$NAMESPACE" --timeout 180s
kubectl rollout status deployment/dashboard --namespace "$NAMESPACE" --timeout 180s

# A primeira chamada inclui aquecimento de DNS/runtime e nao deve contaminar o SLO.
kubectl exec --namespace "$NAMESPACE" deployment/bff -- node -e '
fetch("http://127.0.0.1:8080/api/v1/suite/executar", {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ scenarios: ["aprovado"] })
}).then((response) => {
  if (!response.ok) process.exit(1);
}).catch(() => process.exit(1));'
kubectl exec --namespace "$NAMESPACE" deployment/bff -- node scripts/run-suite.js http://127.0.0.1:8080

kubectl get nodes
kubectl get pods --namespace "$NAMESPACE" --output wide
printf '\nCluster pronto. Em outro terminal, execute:\n'
printf 'wsl.exe -e sh -lc '\''~/.local/bin/kubectl port-forward service/dashboard 3001:80 -n %s'\''\n' "$NAMESPACE"
printf 'Depois abra http://localhost:3001\n'
