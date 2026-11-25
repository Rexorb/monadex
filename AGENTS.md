# Instruções para agentes — Monadex

## Política obrigatória de Git

Antes de qualquer operação de versionamento, leia **integralmente** [`GIT_WORKFLOW.md`](GIT_WORKFLOW.md) e siga todas as suas regras. Elas são obrigatórias durante todo o desenvolvimento deste projeto.

- Trabalhe exclusivamente no backend; o frontend pertence à outra integrante do projeto.
- Preserve Haskell, Yesod, Persistent e PostgreSQL como tecnologias principais do backend. Contratos JSON são a interface principal de integração com o frontend.
- A outra integrante define e implementa o frontend separadamente; não imponha Hamlet, Lucius, Julius nem qualquer framework de interface.
- Commits e pushes exigem autorizações explícitas e **separadas** do usuário, após a revisão das alterações e da mensagem completa de commit (título e corpo no padrão Conventional Commits).
- Commits e pushes são permitidos somente na branch `monadex-backend`; não altere o histórico nem trabalhe em branches de outros colaboradores.
- Se não houver repositório Git local, remote `origin` correto ou branch confirmada, informe o usuário e não escolha uma base nem configure o remote por conta própria.

As demais regras e o procedimento completo estão em `GIT_WORKFLOW.md`; este resumo não os substitui.
