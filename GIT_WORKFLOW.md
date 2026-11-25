# Monadex — Política de commits e integração Git

> Instruções obrigatórias para agentes de desenvolvimento (OpenCode e equivalentes) que atuem no backend do Monadex.

## 1. Repositório e escopo

| Configuração | Valor |
| --- | --- |
| Projeto | Monadex — A Functional Card Collection |
| Repositório | https://github.com/Rexorb/monadex |
| Remote esperado | `origin` |
| Branch exclusiva de trabalho | `monadex-backend` |
| Escopo | Backend: Haskell, Yesod, PostgreSQL, Persistent, regras de negócio, testes e documentação técnica relacionada |
| Responsável pela aprovação | Usuário responsável pelo backend |

O frontend é responsabilidade da outra desenvolvedora. Não altere sua implementação, suas branches ou seus commits. Alterações em contratos compartilhados devem ser apresentadas ao responsável antes de serem incluídas.

## 2. Regras obrigatórias de autorização

1. O agente pode analisar, editar, compilar e testar o código local dentro do escopo de desenvolvimento autorizado.
2. **Nenhum commit pode ser criado antes de o usuário revisar as alterações e autorizar explicitamente o commit.** Isso inclui o primeiro commit, correções pequenas, documentação e commits automáticos de ferramentas.
3. **Nenhum push pode ser executado antes de o usuário autorizar explicitamente o envio ao GitHub.** Autorizar um commit não autoriza um push.
4. As duas autorizações podem ser dadas juntas somente quando o usuário aprovar expressamente o commit revisado e seu envio. Caso contrário, solicite cada autorização separadamente.
5. Aprovações valem apenas para o conjunto de alterações, mensagem e destino apresentados. Se o conteúdo mudar após a revisão, apresente-o novamente e obtenha nova autorização antes de commitar. Se o conjunto de commits a enviar mudar, obtenha nova autorização de push.
6. Silêncio, ausência de objeção, solicitação de desenvolvimento, aprovação de testes ou instruções de finalizar uma tarefa não constituem permissão para commit ou push.
7. Não execute `git commit --amend`, rebase, reset destrutivo, merge, cherry-pick, revert, exclusão de branches, force push ou operações equivalentes sem autorização específica. Nunca utilize tais operações para contornar esta política.
8. Não configure automações que criem commits ou enviem código sem a aprovação humana exigida aqui.

## 3. Branch exclusiva: `monadex-backend`

Todo commit produzido pelo agente e todo push deverão ocorrer exclusivamente na branch `monadex-backend`. É proibido commitar ou enviar alterações diretamente para `main`, `master`, branches de frontend ou quaisquer outras branches.

Antes de iniciar o trabalho, verifique o estado do repositório:

```bash
git status --short --branch
git branch --show-current
git remote -v
git branch --list monadex-backend
git branch -r --list origin/monadex-backend
```

Confirme que `origin` aponta para o repositório correto (URL HTTPS indicada ou equivalente SSH). Se o repositório não existir localmente, o remote estiver incorreto, a branch estiver ausente ou o histórico ainda não tiver sido inicializado, informe o usuário. Não altere o remote nem escolha uma base arbitrária sem confirmação.

Após confirmar o remote, `git fetch origin` pode ser usado para atualizar as referências remotas; isso não envia alterações ao GitHub.

Se a branch local existir e a troca for segura:

```bash
git switch monadex-backend
```

Se existir apenas remotamente (após atualizar as referências), e a troca for segura:

```bash
git switch --track -c monadex-backend origin/monadex-backend
```

Se a branch não existir local ou remotamente, solicite ao usuário a definição da base e a autorização para criá-la. Em um repositório recém-inicializado sem commits, confirme a configuração da branch inicial antes de preparar o primeiro commit. Criar uma branch local não autoriza publicar a branch nem criar um commit.

Não descarte, mova, faça stash ou misture alterações de outros colaboradores para trocar de branch. Se houver risco, interrompa a operação Git e informe o usuário.

Antes de cada commit e push, confirme novamente que a branch atual é exatamente `monadex-backend`.

## 4. Fluxo de desenvolvimento e revisão

### Etapa A — Desenvolver e validar localmente

- Inspecionar a estrutura existente e o estado do Git.
- Implementar apenas a tarefa de backend solicitada.
- Manter mudanças relacionadas em conjuntos coerentes.
- Executar os comandos de compilação e testes adequados ao projeto (por exemplo, `stack build` e `stack test`, se Stack estiver configurado).
- Registrar falhas, testes não executados e limitações sem declarar resultados que não foram verificados.
- Verificar que não foram incluídos segredos, credenciais ou artefatos desnecessários.

### Etapa B — Apresentar alterações para revisão

Antes de solicitar autorização, apresente:

- Branch atual e objetivo da alteração.
- Arquivos criados, modificados e removidos, incluindo arquivos não rastreados relevantes.
- Resumo técnico do que mudou e por quê.
- Diff ou indicação clara de como inspecionar todas as alterações propostas.
- Comandos de validação executados e seus resultados reais.
- Pendências, riscos e impacto sobre contratos do frontend ou banco de dados.
- Mensagem completa de commit proposta (título e corpo).

Comandos úteis para revisão local:

```bash
git status --short
git diff --stat
git diff
git diff --cached
git ls-files --others --exclude-standard
```

Inspecione também o conteúdo dos arquivos novos selecionados; `git diff` não os inclui automaticamente. Não misture alterações preexistentes ou de terceiros com as da tarefa.

Encerre esta etapa solicitando autorização explícita:

> Você revisou as alterações apresentadas e autoriza a criação deste commit na branch `monadex-backend` com a mensagem proposta?

Aguarde a resposta. Não execute o commit nesta mesma etapa sem aprovação explícita já recebida.

### Etapa C — Criar o commit autorizado

Somente após a aprovação:

1. Confirme a branch, o estado do repositório e a correspondência do conteúdo com o que foi revisado.
2. Adicione somente os arquivos ou trechos aprovados ao staging (`git add -- <arquivos aprovados>`). Evite `git add .` e `git add -A` indiscriminadamente.
3. Confira o conteúdo final do staging com `git diff --cached` e `git diff --cached --check`.
4. Se houver alterações não aprovadas no staging, interrompa o commit e informe o usuário.
5. Crie o commit utilizando exatamente a mensagem aprovada.
6. Informe o hash, a mensagem e o estado do repositório após a operação.

Exemplo de comando (apenas ilustrativo, não constitui autorização):

```bash
git commit -m "feat(backend): implementa persistencia da colecao" \
  -m "Adiciona restricao de unicidade por usuario e carta, e contabiliza copias repetidas."
git log -1 --oneline
git status --short --branch
```

O commit permanece local até que o envio seja autorizado.

### Etapa D — Solicitar autorização de push

Antes de enviar, confirme a branch e o remote e liste **todos** os commits que seriam publicados, inclusive commits locais anteriores. Atualize as referências remotas quando necessário.

Se `origin/monadex-backend` existir:

```bash
git log --oneline origin/monadex-backend..monadex-backend
git diff --stat origin/monadex-backend...monadex-backend
```

Verifique também se a branch local está atrás ou divergiu da remota. Se estiver, não faça pull, merge, rebase ou force push automaticamente; apresente o problema e peça orientação.

Se for a primeira publicação da branch, identifique os commits e o histórico que ainda não estão no remoto; confirme a base e informe que a branch será criada no GitHub.

Apresente o destino (`origin/monadex-backend`), os hashes e as mensagens dos commits a enviar. Se algum commit não estiver aprovado para publicação, não o envie.

Solicite explicitamente:

> Você autoriza o push dos commits listados para `https://github.com/Rexorb/monadex`, exclusivamente na branch `monadex-backend`?

### Etapa E — Enviar ao GitHub

Somente após autorização explícita de push e nova verificação do conteúdo, branch e remote:

```bash
git push origin monadex-backend:monadex-backend
```

Na primeira publicação, caso necessário:

```bash
git push --set-upstream origin monadex-backend:monadex-backend
```

Nunca utilize `--force`, `--force-with-lease`, `--all`, `--mirror` ou push de tags. Não envie outras branches.

Se o push falhar por autenticação, divergência, proteção de branch ou rede, informe o erro. Não tente contornar proteções ou modificar o histórico automaticamente. Não solicite senhas ou tokens em texto no chat; utilize o mecanismo seguro de autenticação Git já configurado pelo usuário.

Após sucesso, confirme o resultado retornado pelo Git e, quando possível, verifique a referência remota (`git ls-remote --heads origin monadex-backend`). Informe o hash publicado e o endereço da branch:

https://github.com/Rexorb/monadex/tree/monadex-backend

Não declare o push concluído sem confirmação do comando.

## 5. Padrão obrigatório de mensagens de commit

Utilize o formato inspirado em Conventional Commits, com descrições em português e tipos/escopos técnicos padronizados:

```text
<tipo>(<escopo>): <descrição objetiva da alteração>

<corpo descrevendo o que mudou, por que mudou e impactos relevantes>

<referências ou observações adicionais, quando aplicável>
```

O título deve ser específico, preferencialmente com até 72 caracteres, e utilizar um verbo de ação. O corpo é obrigatório nesta política: deve explicar a alteração concreta e sua motivação, sem inventar funcionalidades ou testes. Quando relevante, mencione migrations, mudanças de contrato HTTP, compatibilidade e validações executadas.

### Tipos

| Tipo | Uso |
| --- | --- |
| `feat` | Nova funcionalidade |
| `fix` | Correção de comportamento incorreto |
| `refactor` | Reorganização sem mudança intencional de comportamento |
| `test` | Criação ou manutenção de testes |
| `docs` | Documentação |
| `chore` | Manutenção e configuração auxiliar |
| `build` | Dependências e compilação |
| `ci` | Configuração de integração contínua |
| `perf` | Melhoria de desempenho |
| `style` | Formatação de código sem alteração funcional |

Escopos sugeridos: `backend`, `auth`, `db`, `domain`, `cards`, `boosters`, `collection`, `rewards`, `expansions`, `api`, `docker`, `tests`, `docs` e `git`. Utilize o escopo que melhor identifica a mudança.

### Exemplos ilustrativos de títulos

```text
chore(backend): inicializa estrutura do projeto Yesod
build(docker): configura ambiente PostgreSQL para desenvolvimento
feat(db): adiciona entidades de cartas e colecoes
feat(auth): implementa cadastro com hash seguro de senhas
fix(collection): impede registros duplicados de cartas por usuario
refactor(domain): separa regras de negocio dos handlers
feat(api): adiciona importacao idempotente do catalogo TCGdex
test(rewards): valida concessao unica por dia
docs(domain): documenta aplicacao das monadas no backend
docs(git): define politica de revisao e publicacao do backend
```

Os exemplos não representam alterações já realizadas nem uma autorização para executá-las.

### Exemplo de mensagem completa

```text
fix(collection): impede duplicacao de registros por usuario e carta

Adiciona uma restricao de unicidade para a combinacao de usuario e carta.
Atualiza a persistencia para contabilizar copias no registro existente.

Motivacao: preservar a consistencia da colecao e evitar registros redundantes.
Validacao: informar aqui somente os testes realmente executados e seus resultados.
```

Evite mensagens genéricas como `update`, `fix`, `commit inicial`, `ajustes`, `finalizado`, `mudanças` ou `wip` sem explicação. Um commit deve representar uma unidade lógica de trabalho. Não agrupe tarefas independentes apenas para reduzir o número de commits.

## 6. Proteção do repositório e dos colaboradores

Não versione credenciais, tokens, chaves privadas, arquivos `.env` com dados reais, chaves de sessão, dumps com dados pessoais ou artefatos de compilação. Revise o `.gitignore` existente; considere `.stack-work/`, `dist-newstyle/`, arquivos locais de configuração sensível e logs. Arquivos de exemplo sem segredos, como `.env.example`, podem ser versionados após revisão.

Não altere arquivos do frontend, histórico de outros colaboradores ou configurações globais do Git. Não crie pull requests, faça merges, publique releases ou altere permissões do GitHub sem solicitação explícita do usuário. A branch `monadex-backend` não deve ser integrada à branch principal automaticamente.

## 7. Modelo de relatório para aprovação

```text
REVISÃO DE ALTERAÇÕES — MONADEX BACKEND

Branch: monadex-backend
Tarefa:
Arquivos incluídos:
Resumo técnico:
Motivação:
Impactos e riscos:
Compilação:
Testes:
Pendências:

Mensagem proposta:
<tipo>(<escopo>): <descrição>

<corpo>

Status: aguardando autorização de commit.
```

Após o commit:

```text
COMMIT LOCAL — AGUARDANDO AUTORIZAÇÃO DE PUSH

Branch: monadex-backend
Remote: origin
Commits que serão enviados:
- <hash> — <mensagem>
Destino: origin/monadex-backend
Status: nenhum push executado nesta etapa.
```

## 8. Checklist obrigatório

- [ ] Branch atual confirmada como `monadex-backend`.
- [ ] Remote confirmado como `Rexorb/monadex`.
- [ ] Alterações restritas ao escopo autorizado do backend.
- [ ] Diff completo, incluindo arquivos novos, apresentado para revisão.
- [ ] Compilação e testes reportados com resultados reais.
- [ ] Ausência de segredos e alterações indevidas verificada.
- [ ] Mensagem descritiva (título e corpo) apresentada.
- [ ] Autorização explícita do usuário para o commit recebida.
- [ ] Staging conferido contra o conteúdo aprovado.
- [ ] Commit criado e hash informado.
- [ ] Todos os commits a publicar apresentados e aprovados.
- [ ] Autorização explícita do usuário para o push recebida.
- [ ] Push restrito a `origin/monadex-backend` confirmado.

## 9. Instrução permanente ao agente

Leia este arquivo antes de qualquer operação Git que possa alterar o histórico ou publicar conteúdo. Na ausência de autorização inequívoca, permaneça apenas no trabalho local e solicite aprovação. Esta política não é substituída por uma instrução genérica para implementar ou finalizar tarefas.

**Fluxo obrigatório:** desenvolver → validar → apresentar para revisão → obter autorização de commit → criar commit local → apresentar commits para envio → obter autorização de push → publicar exclusivamente na branch `monadex-backend`.

Este documento estabelece um procedimento de trabalho; não cria o repositório, a branch ou permissões técnicas no GitHub por si só.
