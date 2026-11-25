# Testes do backend

A suíte é Hspec e combina exemplos puros, um exemplo de integração PostgreSQL e três exemplos HTTP com `yesod-test`. Os números abaixo são o resultado **registrado na revisão pré-commit 02**; a etapa de documentação do commit 03 não reexecutou a suíte.

## Comando e banco isolado

Os testes SQL/HTTP exigem um banco separado. Crie-o uma única vez, se ainda não existir, e nunca aponte a suíte para `monadex_db`:

```bash
docker compose exec -T db psql -U monadex -d postgres -c 'CREATE DATABASE monadex_test_db'
set -a; . ./.env; set +a
export MONADEX_TEST_DATABASE_URL="host=127.0.0.1 port=$MONADEX_DB_PORT user=monadex password=$MONADEX_DB_PASSWORD dbname=monadex_test_db"
stack test --fast
```

Se o banco já existir, **não repita** o `CREATE`. `test/Integration.hs` exige `dbname=monadex_test_db` na URL e confere `SELECT current_database()` antes de criar qualquer tabela. `test/HttpSpec.hs` faz a mesma verificação antes de migrations e usa a fábrica de site de teste com o middleware de sessão/SameSite da aplicação. O fixture `test-only-*` é fictício e só existe no banco isolado.

## Resultado observado com o banco isolado

**27 exemplos aprovados, 0 falhas, 0 pendências** na execução da revisão pré-commit 02:

| Grupo | Exemplos | Conteúdo principal |
| --- | --- | --- |
| Domínio, serviços e parsing | 23 | Sorteio/transição de booster, recompensa diária, raridades, TCGdex offline, hash/validação de cadastro, progresso e fuso São Paulo |
| Integração PostgreSQL | 1 | Migrations repetidas, quatro CHECKs, rollback, fixture idempotente, concorrência de recompensa/abertura, novo dia e isolamento entre contas |
| HTTP/Yesod | 3 | Cadastro/login/logout, CSRF, GET sem recompensa, POST diário idempotente, abertura, último resultado, erros e isolamento de sessões |

Os exemplos de integração e HTTP possuem **muitas assertions cada um**; a contagem de 27 é de exemplos Hspec, não de assertions nem de percentual de cobertura de código. Não há relatório de cobertura percentual nesta entrega.

## Comportamento sem `MONADEX_TEST_DATABASE_URL`

Sem a variável, a suíte executa **25 exemplos: 23 aprovados, 2 pendentes e 0 falhas**. Os 23 exemplos de domínio/serviços passam; o exemplo SQL e um exemplo substituto para o grupo HTTP ficam pendentes (os três testes HTTP reais não são executados). Pendente não é aprovado e não deve ser contabilizado como validação do banco. Uma URL que não contenha `dbname=monadex_test_db` não equivale à ausência da variável: a integração a rejeita com falha; a fábrica HTTP também recusa bancos diferentes antes de aplicar migrations.

## O que os testes cobrem

- `test/Spec.hs`: 101 sementes fixas verificam seis cartas e sexta não Common; catálogo incompleto; pesos inválidos; consumo/agregação; erros sem estado parcial; primeira recompensa, repetição no dia, novo dia e data anterior; parsing TCGdex obrigatório/opcional; raridades desconhecidas; validação do lote; timeout/HTTP 503/JSON inválido com transporte injetado; PBKDF2, salts e hash malformado; progresso e fuso em torno da meia-noite UTC.
- `test/Integration.hs`: um exemplo com múltiplas etapas verifica `current_database()`, migrations idempotentes, os quatro CHECKs, tentativa de inventário negativo com rollback, fixture idempotente, duas recompensas concorrentes, duas aberturas concorrentes com um único booster, seis cartas/um histórico, isolamento de coleção e concessão em novo dia com relógio controlado.
- `test/HttpSpec.hs`: três exemplos verificam autenticação, CSRF, cookies `_SESSION` `HttpOnly`/`SameSite=Strict`, GET sem crédito, POST inicial/repetido, seis cartas, saldo insuficiente, último resultado, erros de JSON/login e isolamento entre sessões.

## Limitações ainda abertas

- Concorrência de serviços é automatizada em SQL; **não há teste HTTP concorrente**.
- HTTPS real, cookie `Secure` e reconhecimento de TLS atrás de proxy não foram validados ponta a ponta.
- Indisponibilidade prolongada da TCGdex e retry/backoff não são testados; apenas timeout, status HTTP e JSON inválido via transporte injetado.
- O banco `monadex_test_db` é compartilhado e não é truncado entre execuções; contas aleatórias e fixtures se acumulam. Para CI, recomenda-se schema/banco efêmero por execução ou limpeza transacional.
- CORS foi verificado manualmente (preflight da origem configurada com HTTP 200 e credenciais; outra origem com HTTP 400), não por um exemplo Hspec dedicado.

## Histórico resumido

As fases registraram 12 exemplos (Fase 2), 17 (Fase 3), 19 (Fase 4), 22 com integração SQL (Fase 5) e 27 na revisão pré-commit 02. Esses números são históricos; o resultado atual é o da tabela acima.
