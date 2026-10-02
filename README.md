# flutter-observability-lab

Laboratório local para **validar o contrato de observabilidade de uma jornada de pagamento** antes de aplicar no ambiente real com Datadog.

Sobe em Docker (WSL ou Linux) um BFF, um payment-service e um adquirente simulados, instrumentados com `dd-trace`, e um **dashboard Flutter Web** no navegador para disparar cenários e ver, para cada execução, se as regras de observabilidade passaram.

Funciona **sem conta Datadog** (modo local). Com `DD_API_KEY` e/ou um client token de RUM, os mesmos traces, logs e sessões chegam ao Datadog.

```
Navegador (Flutter Web + RUM opcional)
        │  /api/v1/pagamento/*   (nginx, mesmo domínio)
        ▼
loja-bff-pagamento ──► loja-payment-service ──► adquirente-mock
   :8080                   :8081                    :8082
        │                      │                       │
        └──────── logs JSON (journey.step) + traces dd-trace ────────► Datadog Agent (opcional)
```

## Subir

No WSL, dentro da pasta do repositório:

```bash
cp .env.example .env
docker compose up -d --build
```

Abra **http://localhost:3000** no navegador do Windows.

O primeiro build do dashboard baixa a imagem do Flutter (≈ 2 GB) e leva alguns minutos. Os seguintes usam cache.

Para rodar a suíte pelo terminal (mesmo teste do CI):

```bash
./scripts/smoke.sh
```

## O que o dashboard faz

| Aba | Para quê |
|---|---|
| **Cenários** | Executa um cenário, a suíte completa (pelo navegador ou pelo backend) ou um volume misto de jornadas. |
| **Validações** | Para cada execução: etapas, outcome técnico/negócio, as 8 validações, trace_id por serviço e os logs coletados. |
| **Saúde por etapa** | Sucesso técnico com semáforo (<80 / 80–90 / ≥90), volume, p50/p95 vs. limite e funil. É o que o dashboard do Datadog vai mostrar. |
| **Contrato** | Campos obrigatórios, limites e qual recurso do Datadog implementa cada regra. |

### Validações

| ID | Regra |
|---|---|
| `tags.unificadas` | Todo log tem `env`, `service`, `version` |
| `contrato.campos` | Todo `journey.step` tem `journey.stage`, `session.id`, `order.id`, `payment.id`, `payment.method`, `correlation.id`, `http.status_code`, `duration_ms`, `technical.outcome`, `business.outcome` |
| `correlacao.trace` | Mesmo `dd.trace_id` no BFF, payment e adquirente em cada etapa |
| `correlacao.id` | Mesmo `correlation.id` em todos os serviços |
| `correlacao.app_backend` | Headers de trace do RUM chegam ao BFF (só com RUM ligado) |
| `classificacao` | Etapas e outcomes conforme o cenário; **recusa não é erro técnico** |
| `dados_sensiveis` | Nenhum PAN (Luhn), CVV ou CPF nos logs |
| `latencia` | Duração de cada etapa no BFF dentro do limite (`SLO_*_MS`) |

### Cenários

Cada cenário declara quais validações **devem falhar**. Um cenário fica verde quando o validador se comporta como esperado, inclusive detectando as falhas plantadas.

| Cenário | Deve falhar | O que prova |
|---|---|---|
| Cartão aprovado | — | Linha de base |
| PIX pendente | — | Pendente ≠ erro |
| Cartão recusado | — | Recusa é negócio, não falha técnica |
| Timeout no adquirente | `latencia` | Timeout classificado como `timeout` |
| Erro 5xx no adquirente | — | `dependency_error`, não recusa |
| Lentidão na autorização | `latencia` | Sucesso lento é sinalizado |
| Quebra de correlação | `correlacao.trace`, `correlacao.id` | Detecta onde o trace se perde |
| Vazamento de PAN | `dados_sensiveis` | Logger inseguro é pego |
| Contrato incompleto | `contrato.campos` | Campo obrigatório ausente é pego |

## Ligar o Datadog

### APM + logs (Agent)

No `.env`, preencha `DD_API_KEY` e `DD_SITE`, depois:

```bash
docker compose --profile datadog up -d
```

O chip **Agent conectado** aparece no topo do dashboard. Os serviços aparecem no APM como `loja-bff-pagamento`, `loja-payment-service` e `adquirente-mock`, com `env:lab`.

### RUM (navegador)

Crie uma aplicação **Browser** em *Digital Experience → RUM*, preencha `DD_RUM_APPLICATION_ID` e `DD_RUM_CLIENT_TOKEN` no `.env` e recrie o dashboard:

```bash
docker compose up -d dashboard
```

Com RUM ativo, as chamadas a `/api/v1/pagamento/*` levam headers `x-datadog-*` e `traceparent`, e a validação `correlacao.app_backend` passa a valer.

No app mobile real, o equivalente é o `datadog_flutter_plugin` com `firstPartyHosts` apontando para o domínio do BFF.

### Dashboard no Datadog

Veja [`datadog/README.md`](datadog/README.md): facets necessárias e importação de `dashboard-jornada-pagamento.json`.

## Do laboratório para o ambiente real

1. Rode a suíte e garanta 9/9 verdes.
2. Compare os campos de `journey.step` com o que os serviços reais já logam (Fase 0 de descoberta).
3. Implemente nos serviços reais apenas o que faltou: tags, log injection, headers propagados, campos do contrato.
4. Aplique no Datadog: pipeline com remappers e category processor, Sensitive Data Scanner, facets, dashboard.
5. Só depois do baseline, crie monitores e SLOs de latência e sucesso.

## Estrutura

```
services/        Node.js (express + dd-trace + pino): bff, payment, acquirer (ROLE)
  src/validator.js   regras de validação
  src/scenarios.js   catálogo de cenários (fonte única)
dashboard/       Flutter Web + nginx (proxy /api → bff) + ponte RUM (web/obs-bridge.js)
datadog/         dashboard JSON e mapeamento das regras
scripts/smoke.sh suíte via terminal / CI
```

## Cuidados

- Mantenha o repositório **privado** e sem nome de cliente, chaves ou dados reais.
- O `.env` está no `.gitignore`. Nunca commite `DD_API_KEY`.
- O único cartão usado é o de teste `4111 1111 1111 1111`.
