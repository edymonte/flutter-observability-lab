#!/usr/bin/env bash
set -euo pipefail

PROFILE="flutter-observability-lab"
DELETE_CLUSTER=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --delete) DELETE_CLUSTER=true; shift ;;
    *) echo "Argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done

export PATH="$HOME/.local/bin:$PATH"
if [[ "$DELETE_CLUSTER" == true ]]; then
  minikube delete --profile "$PROFILE"
else
  minikube stop --profile "$PROFILE"
fi
