# Decisao de MVP

## Resumo

O repositorio atual deve ser a base do MVP. Ele ja entrega uma jornada executavel,
falhas controladas, logs estruturados, correlacao, traces, validacao automatizada e
um dashboard Flutter Web. A suite de backend passou nos 9 cenarios e o dashboard
foi compilado em Docker.

O plano original continua valido como roteiro de aprendizado e governanca, mas nao
como especificacao literal da implementacao. Ele propoe OpenTelemetry + Elastic;
o codigo atual usa `dd-trace` + Datadog. Misturar as duas stacks agora aumentaria a
complexidade sem melhorar a validacao inicial do contrato de observabilidade.

## Comparacao

| Criterio | Plano original | Repositorio atual | Decisao |
|---|---|---|---|
| Evolucao | Milestones pequenos | Entrega varios niveis de uma vez | Adotar milestones daqui em diante |
| Jornada | Flutter + mock API simples | Flutter + BFF + payment + adquirente | Manter a jornada atual |
| Cenarios | Success, error e timeout no MVP | 9 cenarios, incluindo falhas de observabilidade | Manter os 9 como regressao |
| Telemetria | OpenTelemetry + Elastic | `dd-trace`, logs JSON e Datadog opcional | Manter Datadog no MVP |
| Validacao | Principalmente manual | Suite automatizada de contrato | Manter e expandir testes |
| Aprendizado | Troubleshooting por incidentes e evidencias | Dashboard revela validacoes e causa esperada | Adicionar labs sem resposta pronta depois |
| Documentacao | Arquitetura, labs e evidencias | README e guia Datadog | Completar de forma incremental |

## Escopo aprovado

### Milestone 1 - Baseline executavel (concluido)

- Flutter Web servido por Nginx.
- BFF, payment-service e adquirente em Docker Compose.
- Cenarios reproduziveis e logs JSON.
- Suite automatizada com resultado esperado em 9/9 cenarios.
- Build do dashboard validado em Docker.
- Execucao local sem conta Datadog.

### Milestone 2 - Consolidacao (proximo)

1. Adicionar testes unitarios do validador, principalmente para campos ausentes,
   correlacao, classificacao e dados sensiveis.
2. Criar `docs/architecture/` com fluxo de requisicao e fluxo de telemetria.
3. Criar o primeiro lab de troubleshooting sem exibir a causa raiz na interface.
4. Registrar evidencias reproduziveis da suite e do diagnostico.
5. Validar APM e logs em uma conta Datadog de laboratorio, sem credenciais no Git.

### Fora do escopo imediato

- Adicionar Elasticsearch, Kibana ou OpenTelemetry Collector.
- Substituir `dd-trace` antes de validar a integracao Datadog existente.
- Conectar dados, URLs, configuracoes ou credenciais corporativas.
- Tratar o dashboard local como substituto de uma plataforma de observabilidade.

## Criterio para rever a stack

OpenTelemetry deve ser avaliado em um milestone separado somente se houver uma
necessidade concreta de portabilidade entre backends, padronizacao OTLP ou estudo
comparativo. Nesse caso, deve entrar como experimento isolado e manter a suite atual
como criterio de regressao.
