# Roadmap

| Fase | Situação |
| --- | --- |
| 0 — Auditoria do ambiente e plano | Verificada (inspeção e documentação) |
| 1 — Fundação Yesod/PostgreSQL | Implementada e verificada (build, migrations, HTTP) |
| 2 — Domínio funcional e testes | Implementada e verificada (12 exemplos Hspec) |
| 3 — Persistência e catálogo real | Implementada e verificada (215 cartas reais, reimportação idempotente) |
| 4 — Autenticação | Implementada; verificada com testes e smoke HTTP/PostgreSQL |
| 5 — Regras integradas e concorrência | Implementada e verificada; POST idempotente de recompensa e testes HTTP na revisão pré-commit 02 (27 exemplos) |
| 6 — Interface/frontend | Delegada à outra integrante; fora do escopo deste backend e sem tecnologia de UI imposta |
| 7 — Validação e documentação final | Documentação em preparação para o commit 03; commit e push dependem de autorização explícita |

Cada fase só começará após autorização explícita e terminará com relatório de alterações, build, testes e pendências.
