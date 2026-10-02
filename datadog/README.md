# Artefatos para o Datadog

## dashboard-jornada-pagamento.json

Importação: **Dashboards → New Dashboard → ⚙ → Import dashboard JSON**.

Antes de importar, crie no **Log Explorer** (a partir de um log `journey.step`):

| Tipo | Atributo | Observação |
|---|---|---|
| Facet | `@event` | |
| Facet | `@journey.stage` | |
| Facet | `@technical.outcome` | |
| Facet | `@business.outcome` | |
| Facet | `@test.scenario` | só existe no laboratório |
| Facet | `@correlation.id` | |
| Measure | `@duration_ms` | unidade: millisecond |

Sem a measure `@duration_ms`, o widget de p95 fica vazio.

## Mapeamento validação → recurso

| Validação local | Recurso no Datadog |
|---|---|
| `tags.unificadas` | Unified Service Tagging (`DD_ENV`, `DD_SERVICE`, `DD_VERSION`) |
| `contrato.campos` | Log Pipeline (remappers) + monitor de logs com campos ausentes |
| `correlacao.trace` | APM + `DD_LOGS_INJECTION=true` |
| `correlacao.id` | Facet `@correlation.id` |
| `correlacao.app_backend` | RUM `allowedTracingUrls` (web) / `firstPartyHosts` (Flutter mobile) |
| `classificacao` | Category Processor para `technical.outcome` / `business.outcome` |
| `dados_sensiveis` | Sensitive Data Scanner (PAN, CVV, CPF) |
| `latencia` | Monitor/SLO de p95 por etapa (após baseline) |
