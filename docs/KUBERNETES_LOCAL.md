# Kubernetes local com Minikube

Este ambiente executa quatro pods em um unico node local, sem usar um provedor:

```text
Minikube (1 node)
├── dashboard (Flutter Web + Nginx)
├── bff
├── payment
└── acquirer
```

Os manifests incluem namespace dedicado, Services ClusterIP, readiness/liveness
probes, requests/limits e security context nos containers Node.js. As imagens sao
construidas diretamente no cache do Minikube e nao precisam de registry externo.

## Pre-requisitos

- Docker Desktop com integracao WSL em execucao.
- Minikube e kubectl instalados no WSL em `~/.local/bin`.
- Pelo menos 6 GB de memoria disponivel para o cluster.

Instalacao dos binarios no WSL, caso ainda nao existam:

```bash
mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/minikube https://storage.googleapis.com/minikube/releases/v1.38.1/minikube-linux-amd64
curl -fsSL -o ~/.local/bin/kubectl https://dl.k8s.io/release/v1.36.2/bin/linux/amd64/kubectl
chmod +x ~/.local/bin/minikube ~/.local/bin/kubectl
```

## Criar e publicar o laboratorio

No PowerShell, na raiz do repositorio:

```powershell
.\scripts\k8s-up.ps1
```

O script cria o perfil `flutter-observability-lab`, constroi as duas imagens,
aplica `k8s/`, espera os quatro deployments, aquece a primeira transacao e exige
que a suite completa passe 9/9 antes de mostrar em qual node cada pod esta.

Para acessar o dashboard, mantenha este comando aberto em outro terminal:

```powershell
wsl.exe -e sh -lc '~/.local/bin/kubectl port-forward service/dashboard 3001:80 -n flutter-observability-lab'
```

Abra http://localhost:3001. A porta 3001 evita conflito com outros dashboards
locais que ja possam usar a porta 3000.

## Operacao e troubleshooting

```powershell
wsl.exe -e sh -lc '~/.local/bin/kubectl get nodes'
wsl.exe -e sh -lc '~/.local/bin/kubectl get pods -n flutter-observability-lab -o wide'
wsl.exe -e sh -lc '~/.local/bin/kubectl get services -n flutter-observability-lab'
wsl.exe -e sh -lc '~/.local/bin/kubectl logs deployment/bff -n flutter-observability-lab'
```

Falhas controladas de infraestrutura:

```powershell
wsl.exe -e sh -lc '~/.local/bin/kubectl delete pod -n flutter-observability-lab -l app.kubernetes.io/name=acquirer'
wsl.exe -e sh -lc '~/.local/bin/kubectl scale deployment/acquirer --replicas=0 -n flutter-observability-lab'
wsl.exe -e sh -lc '~/.local/bin/kubectl scale deployment/acquirer --replicas=1 -n flutter-observability-lab'
wsl.exe -e sh -lc '~/.local/bin/kubectl rollout restart deployment/payment -n flutter-observability-lab'
```

O Kubernetes recria um pod deletado. Escalar o adquirente para zero permite
observar indisponibilidade de dependencia e depois validar a recuperacao.

## Por que uma replica por servico

O payment-service e o BFF mantem dados da execucao em memoria. Varias replicas
sem armazenamento compartilhado ou afinidade podem separar a criacao, autorizacao
e validacao entre pods diferentes. O MVP simula a topologia corporativa com quatro
pods no mesmo node; escalabilidade horizontal deve ser um milestone posterior,
depois de externalizar o estado.

## Parar ou remover

```powershell
.\scripts\k8s-down.ps1
.\scripts\k8s-down.ps1 -DeleteCluster
```

O primeiro comando preserva o cluster. O segundo remove o perfil e suas imagens.
