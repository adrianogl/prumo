# PRumo: várias contas e GitLab

Spec base: `2026-11-05-prumo-design.md`. Mockup: `docs/mockups/contas.html`.

## Por que

O usuário trabalha com mais de uma conta do GitHub (pessoal e trabalho) e com o GitLab da empresa, numa instância própria. Hoje o PRumo só lê uma conta do GitHub. Ele quer ver tudo o que pede ação numa lista só, sem trocar de app nem de conta.

## O que o usuário decidiu

- Várias contas, de qualquer tipo e em qualquer quantidade: mais de uma do GitHub e mais de uma do GitLab, cada GitLab no seu endereço (gitlab.com ou instância própria).
- Tudo misturado nas mesmas abas (Meus PRs, Revisar, Merge). Não há separação por conta.
- A linha mostra de qual conta é o PR ou MR **só quando houver mais de uma conta configurada**. Com uma conta, o app fica como hoje.
- Forma de mostrar: opção **A** do mockup. No subtítulo entram o ícone do provedor (GitHub ou GitLab), o usuário da conta, o endereço quando não é `github.com` nem `gitlab.com`, e depois o repositório e o número. Exemplo: `[gitlab] adriano · gitlab.empresa.com · vendas/api !341 · 5h`.
- Formas de entrar: "suporte para várias formas". O app detecta contas já logadas no `gh` e no `glab` e oferece usar, e também aceita token pessoal colado.
- Todas as ações valem para o GitLab: as quatro do Claude (revisar, corrigir CI, resolver conflito, resolver comentários), re-rodar job que falhou, Jira e copiar o comando de checkout.
- Ajustes › Contas (mockup, parte 2) e o aviso de conta com problema no popover (mockup, parte 3) foram aprovados como estão.

## Objetivos

- Uma lista de contas persistida, com: tipo (GitHub/GitLab), endereço, usuário (descoberto pelo token), apelido opcional, origem do token (`gh`, `glab`, token pessoal no Keychain) e estado da conexão.
- Os MRs do GitLab aparecem com as mesmas informações e regras dos PRs: CI, aprovação, alterações pedidas, comentários, conflito, draft, pronto para merge, review pedido, review parado, mergeados hoje.
- Notificações, contador da barra de menu, filtros, ordem, visões, fixar/silenciar, marcador de novo, busca, teclado e widget passam a somar todas as contas, com as mesmas regras de hoje.
- Uma conta com problema (token inválido, sem rede, VPN desligada, rate limit) mostra aviso só para ela. As outras seguem atualizando, e os itens dela ficam esmaecidos com o último dado e o tempo desde a última atualização (mockup, parte 3).

## Não objetivos

- Login pelo navegador (OAuth/SSO) dentro do app. Quem usa SSO entra pelo `glab auth login` ou cria um token pessoal depois de entrar pelo navegador. (Decisão minha: OAuth exigiria registrar um app em cada instância do GitLab.)
- Bitbucket, Azure DevOps e GitHub Enterprise Server. A estrutura de contas não deve impedir provedores ou endereços novos depois. (Decisão minha.)
- Pedidos de review a grupos do GitLab (regras de aprovação e code owners). No GitLab, "review pedido a você" é estar na lista de reviewers do MR. Grupos e regras de aprovação variam por plano e instância. (Decisão minha.)
- Separar a lista por conta, ou trocar de conta ativa.

## Anti-objetivos

- Uma conta fora do ar derrubar a lista ou as notificações das outras.
- Adicionar uma conta, ou reconectar, disparar uma rajada de notificações com o estado que já existia. A primeira leitura de cada conta é linha de base silenciosa, como na primeira execução de hoje.
- Perder marcações (fixados, silenciados, visões, worktrees, lembretes) de quem hoje usa uma conta só, ao atualizar o app.
- Mostrar a conta na linha quando só há uma configurada.
- Texto vindo do GitLab (título, branch, nome de job) virar comando de shell. A regra de hoje do script de sessão vale igual.

## Restrições

- macOS 26, Swift 6.4, SwiftUI, `PRumoKit` com testes Swift Testing. As regras de código do projeto continuam as mesmas: sem comentários, um tipo por arquivo no kit, constantes em enums, decode tolerante com teste de JSON antigo.
- Os tokens ficam no Keychain, um item por conta. A única exceção é o script temporário da sessão do Claude, descrito abaixo.
- O app fala direto com cada servidor, sem backend.
- Ids estáveis e únicos entre contas. Os PRs do GitHub mantêm o node id de hoje, para que marcações e worktrees já salvos continuem valendo sem migração. Os MRs do GitLab usam um id que inclui o endereço da instância, porque ids do GitLab só são únicos dentro dela.
- Migração: na primeira abertura depois da atualização, a conta atual vira a primeira conta da lista, com a mesma origem de token e a mesma linha de base. Não pode haver evento nem lembrete novo por causa disso.
- Escopo do token do GitLab: `read_api` basta para ler. Re-rodar job precisa de `api`. Com token só de leitura, o item "Re-rodar job que falhou" aparece desabilitado com a dica do escopo que falta. (Decisão minha.)

## Como o GitLab mapeia nas regras de hoje

Decisões minhas, para o builder confirmar contra a API da instância:

| Conceito no PRumo | No GitLab |
| --- | --- |
| PR, número `#n` | MR, `!iid` na linha e nas notificações |
| Meus PRs | MRs abertos com você como autor, em todos os projetos da instância |
| Revisar | MRs abertos com você em `reviewers` |
| CI e job que falhou | pipeline do head do MR e o primeiro job falho dele |
| Re-rodar job | `retry` do pipeline, que re-roda os jobs que falharam |
| Aprovado | aprovações do MR (`approved_by`) |
| Alterações pedidas | estado "requested changes" do reviewer, nas versões que têm. Nas outras, não existe |
| Comentários | notas que não são de sistema, excluindo bots e os autores ignorados |
| Conflito, pronto para merge | `has_conflicts` e `detailed_merge_status` |
| Draft | `draft` |
| Mergeados hoje | MRs seus com `merged_at` de hoje |
| Copiar checkout | `glab mr checkout <iid>` |
| Fetch da worktree | `refs/merge-requests/<iid>/head` |
| Clone local | achado pelo `remote` com o host da instância, como no GitHub |
| Prompt de CI do Claude | job e pipeline com `glab ci view` / `glab ci trace` no lugar de `gh run view` |
| Prompt de revisão | template próprio por provedor em Ajustes › IA. O padrão do GitLab pede a revisão do MR pelo `glab mr diff` |

## Casos decididos depois da revisão do design

- **CLI dentro das sessões do Claude** (o usuário decidiu): o app passa o token da conta dona do PR só para aquela sessão, por `GH_TOKEN` no GitHub e por `GITLAB_TOKEN` e `GITLAB_HOST` no GitLab. A conta ativa do `gh`/`glab` do usuário não muda.
  - O script temporário da sessão (0700, em `~/Library/Caches/PRumo/sessions/`) passa a ter o token e é apagado assim que a sessão começa.
  - O token entra no script como variável de ambiente aspada e nunca aparece na linha de comando do terminal.
  - Isso faz as ações funcionarem também em conta GitLab adicionada só por token.
  - O comando de checkout copiado continua sem token, porque vai para o clipboard. Quando a conta não é a ativa da CLI, o item do menu avisa na dica. (Decisão minha.)
- **Mesmo PR visível por duas contas do GitHub** (decisão minha): uma linha só, sem notificação duplicada.
  - O PR pertence à conta em que ele é seu (autor). Se não for seu em nenhuma conta, pertence à primeira conta da lista em que ele aparece em Revisar.
  - Essa conta aparece no subtítulo e o token dela é usado nas ações.
  - Quem é autor numa conta e foi chamado para revisar na outra fica em Meus PRs, como hoje acontece com quem é autor.
  - O id continua o node id do GitHub, que já é global.
- **Quando um MR sai de Revisar no GitLab** (decisão minha): sai quando você aprova ou quando o seu estado de reviewer deixa de ser "não revisado". Nas versões sem esse estado, sai quando você aprova ou comenta depois de ser chamado. Fica de novo se pedirem outra revisão.
- **Hora do pedido de review no GitLab** (decisão minha): vem da nota de sistema "requested review from @você" quando dá para ler na mesma consulta. Quando não dá, vem da criação do MR. Nesse caso "review parado" e a ordem por espera ficam aproximados, e isso tem de estar escrito na aba Notificações.

## Telas

- **Ajustes › Contas** substitui a aba Conta (mockup, parte 2).
  - Lista de contas, cada uma com ícone, apelido e usuário, endereço, origem do token e estado.
  - Menu `⋯` com Reconectar, Renomear e Remover.
  - Botão "Adicionar conta…" abre uma janela com GitHub ou GitLab:
    - primeiro, as contas detectadas no `gh` e no `glab` ainda não adicionadas, com o botão "Usar";
    - depois, endereço (só GitLab), token pessoal e apelido.
  - Remover uma conta tira os itens dela da lista e apaga o token do Keychain. As marcações dela somem quando os PRs saírem da lista, pelas regras de hoje.
- **Linha**: opção A, só com mais de uma conta.
- **Notificações**: com mais de uma conta, o subtítulo da notificação leva o usuário da conta. (Decisão minha.)
- **Filtro de repositórios**: agrupa por conta e depois por org ou grupo quando há mais de uma conta. (Decisão minha.)
- **Onboarding**: continua com uma conta. Ao terminar, avisa que dá para adicionar outras em Ajustes › Contas. (Decisão minha.)
- **Widget**: soma todas as contas. Os links dos itens aceitam `https://github.com` e os endereços das contas GitLab configuradas. Nada além disso.

## Ordem de entrega

1. **Contas** (só GitHub): modelo de conta, Keychain por conta, migração, várias contas do GitHub, aba Contas, conta na linha, refresh em paralelo com estado por conta, aviso por conta.
2. **GitLab**: cliente da API, mapeamento, detecção do `glab`, ações do Claude e de CI, checkout e worktree para MR.

Cada etapa termina com o app usável.

## Fica para o builder

- REST ou GraphQL no GitLab. Restrição: poucas requisições por refresh por conta, e funcionar na versão da instância do usuário. Os detalhes da versão ficam para conferir no spike da etapa 2.
- Como ler o token do `glab` (comando ou arquivo de configuração), e como listar várias contas do `gh` por host.
- Intervalo de refresh por conta e tratamento de rate limit do GitLab.
- Formato exato do id dos MRs, desde que seja estável e único entre instâncias.

## Spike do GitLab (2026-11-05)

Medido no gitlab.com (versão 19.6.0-pre), conta `adrianogl`, projeto privado de teste com um MR, um job que passa e um que falha. A instância própria do usuário não foi testada. Os pontos que dependem de versão estão marcados.

**Autenticação.** `Authorization: Bearer` funciona em REST e GraphQL. O `glab` logado pelo navegador guarda um token OAuth que expira em cerca de 2 h (`is_oauth2: "true"` e `oauth2_expiry_date` no config), e o `glab` renova esse token quando roda algum comando. Token OAuth não funciona com `PRIVATE-TOKEN`. Token pessoal com `Bearer` não foi medido; a documentação do GitLab diz que funciona.

**Introspecção.** O gitlab.com responde a qualquer query de introspecção com o `__schema` inteiro (8,6 MB), sem respeitar `__type` nem aliases. No schema: `detailedMergeStatus` existe; o estado do reviewer fica em `reviewers.nodes.mergeRequestInteraction.reviewState`, do tipo `UserMergeRequestInteraction`; `MergeRequestReviewState` tem `UNREVIEWED`, `REVIEWED`, `REQUESTED_CHANGES`, `APPROVED`, `UNAPPROVED` e `REVIEW_STARTED`.

**Query principal.** A query do plano volta sem `errors` em 0,7 s, numa requisição. `iid` vem como string; `project.id`, `headPipeline.id` e `jobs.id` vêm como gid (`gid://gitlab/Project/88571921`, `gid://gitlab/Ci::Pipeline/…`, `gid://gitlab/Ci::Build/…`). O MR seu em que você também é reviewer aparece nas duas listas. `detailedMergeStatus` dá `MERGEABLE` com a pipeline falhando quando o projeto não exige pipeline verde.

**Estado do reviewer e notas.** Pedido: `UNREVIEWED`, nota de sistema `requested review from @adrianogl`. Depois de aprovar: `APPROVED`, nota `approved this merge request`. Depois de desaprovar e pedir de novo: `UNREVIEWED`, notas `unapproved this merge request` e um novo `requested review from @adrianogl`. Comentário comum: `system: false`. "Alterações pedidas" só sai pela review enviada na interface e não foi medido.

**Escopos.** `GET /api/v4/personal_access_tokens/self` com token OAuth responde 400 (`requires token type to be a personal access token`). `GET /oauth/token/info` devolve `scope`; o OAuth do `glab` tem `api`. `pipelineRetry` com esse token: 200, `errors: []`, pipeline volta a `RUNNING`.

**glab 1.128.** O config fica em `~/Library/Application Support/glab-cli/config.yml` quando não há `GLAB_CONFIG_DIR`/`XDG_CONFIG_HOME`. O arquivo tem comentários e valores aspados, com `user:` por host e o token no keyring (`use_keyring: "true"`). `glab config get token --host gitlab.com` devolve o token do keyring. Funcionam no clone: `glab ci get --pipeline-id`, `glab ci trace <job-id>`, `glab mr diff`, `glab mr view --comments` e `glab mr checkout`. O fetch de `+refs/merge-requests/1/head:refs/prumo/pull/1` funciona. No ambiente, o `glab` usa `GITLAB_TOKEN` como token pessoal (`PRIVATE-TOKEN`), e o token OAuth só funciona em `OAUTH_TOKEN`; com valor inválido em qualquer um dos dois, dá 401 em vez de cair no login.

### Decisões que mudam o plano da etapa 9

- **Capacidades sem introspecção.** O cliente não usa introspecção. Ele roda a query completa; se vier erro de campo inexistente (`detailedMergeStatus` ou `mergeRequestInteraction`), tira o campo, guarda a capacidade no cache do cliente e repete uma vez. `hasRequestedChanges` deixa de existir: `REQUESTED_CHANGES` vira alteração pedida sempre que aparece.
- **Ids.** O mapper converte `iid` de string e tira o número dos gids.
- **Pronto para merge no GitLab.** `detailedMergeStatus == "MERGEABLE"`, sem draft e com CI que não está falhando nem rodando. Sem isso, a linha diria "pronto" com a pipeline vermelha.
- **Token do glab.** O config passa a ler `is_oauth2` e `oauth2_expiry_date`. Token OAuth com menos de 5 min de validade → rodar `glab api user --hostname <host>` antes de `glab config get token`, para o `glab` renovar. O token é lido de novo a cada refresh.
- **Escopos.** `tokenScopes()` tenta `personal_access_tokens/self` e, se der 400, `/oauth/token/info`.
- **Sessão do Claude.** Token pessoal vai em `GITLAB_TOKEN` e token OAuth do `glab` vai em `OAUTH_TOKEN`, sempre com `GITLAB_HOST`. Numa sessão com mais de 2 h, o token OAuth pode expirar.
- **Nota do pedido.** O texto anotado confere com o do plano. "Alterações pedidas" fica só pelo `reviewState`, sem data da nota (usa `updatedAt`).
