# PRumo: Etapa 9 (GitLab) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Acompanhar MRs de contas GitLab (gitlab.com ou instância própria) nas mesmas abas, regras, notificações e ações dos PRs do GitHub.

**Architecture:** O GitLab entra como segundo `ProviderKind` na estrutura de contas da etapa 8. Um `GitLabClient` faz uma query GraphQL por refresh por conta e um `MergeRequestMapper` converte os MRs em `PullRequest`, com id que inclui o host. As diferenças de provedor ficam em poucos pontos: referência (`!iid`), chave de repositório com host, regra de saída de Revisar, prontidão para merge vinda do servidor, refspec da worktree, templates e variáveis de ambiente do Claude e comando de checkout.

**Tech Stack:** Swift 6.4, SwiftUI, Swift Testing, GitLab GraphQL API (`/api/graphql`) e REST v4, `glab` CLI.

**Spec:** `docs/superpowers/specs/2026-11-05-prumo-contas-gitlab-design.md` (etapa 2 da "Ordem de entrega", "Como o GitLab mapeia nas regras de hoje", "Casos decididos depois da revisão do design", "Fica para o builder"). Mockup: `docs/mockups/contas.html`, partes 1 (opção A), 2 e 3.

**Base:** `main`, depois da etapa 8 (usa `Account`, `AccountList`, `AccountLabel`, `AccountClient`, `AccountTokenResolver`, `AccountSession`, `SessionEnvironment`, `CheckoutWarning`, `AddAccountSheet`). Commits direto na `main`.

## Global Constraints

- macOS 26 mínimo, Swift 6.4. Pacote SwiftPM `PRumoKit` + app `PRumo` gerado pelo XcodeGen (`project.yml`).
- Sem comentários no código.
- Kit: um tipo por arquivo. App: textos, medidas e símbolos em enums `XxxText`/`XxxMetrics`/`XxxSymbol` no `XxxConstants.swift` da pasta; nada de constante ou type solto dentro de view.
- Copy da interface em PT-BR, exatamente como escrita neste plano.
- Decode tolerante: todo campo novo de tipo persistido usa os helpers `decodeLossy`/`decodeLossyArray`/`decodeLossyDictionary` de `Organization/KeyedDecodingContainer+Lossy.swift` (ou `decodeIfPresent` com default nos tipos que já usam esse padrão), com teste de JSON antigo sem o campo. Respostas do GitLab decodificam com campos opcionais: campo ausente na versão da instância não derruba o refresh.
- Testes nunca rodam `git`, `gh`, `glab` ou `osascript` reais nem chamam rede: `ProcessRunner` e `HTTPTransport` fakes, leitura de arquivo injetada, respostas do GitLab em `PRumoKit/Tests/PRumoKitTests/Fixtures/`.
- Tokens só no Keychain, um item por conta; na sessão do Claude, `GITLAB_TOKEN` e `GITLAB_HOST` entram no script temporário (0700, apagado na primeira linha), nunca na linha de comando.
- Id de MR estável e único entre instâncias: `gitlab:<host>:<projectID>:<iid>`. Ids do GitHub não mudam.
- Texto vindo do GitLab (título, branch, nome de job, caminho de projeto) só entra no script aspado por `ShellQuote.single`, como hoje.
- Escopos do token GitLab: `read_api` basta para ler; re-rodar pipeline exige `api`.
- Com uma conta configurada, nada muda na tela.
- Nenhum nome de empresa real em código, testes ou docs. Usar `acme`, `globex`, `contoso` e `gitlab.empresa.com`; projeto de exemplo `vendas/api`, login `adriano`.
- Commits direto na `main`, Conventional Commits em PT-BR (minúsculas, imperativo, sem ponto final), sem `Co-Authored-By` e sem menção a IA.
- Kit em TDD com Swift Testing (`@Test`, `#expect`): `cd PRumoKit && swift test`.
- Build do app: `xcodegen generate && xcodebuild -project PRumo.xcodeproj -scheme PRumo -destination 'platform=macOS' build` → `** BUILD SUCCEEDED **`, zero warnings do projeto.

## Review Focus

1. **Instância sem estado de reviewer** (versão antiga): o MR sai de Revisar quando você aprova ou comenta depois do pedido, e volta se pedirem de novo depois do seu comentário. Testes `withoutStateLeavesOnCommentAfterRequest` e `withoutStateReRequestAfterCommentReturns` na Task 4.
2. **Pipeline com job `allow_failure` falhado e pipeline verde**: CI aparece verde, sem badge de falha nem "corrigir". Teste `allowedFailureJobDoesNotFailCI` na Task 5.
3. **Nota de sistema com login parecido** (`requested review from @adriano.silva` quando você é `adriano`): a hora do pedido não é tirada dessa nota. Teste `requestedAtIgnoresSimilarUsername` na Task 4.
4. **Título, branch ou job com `$(...)`, crase ou aspas**: o script da sessão mantém tudo aspado e nada vira comando. Teste `gitlabPromptWithShellTextStaysQuoted` na Task 10.
5. **Token só com `read_api`**: "Re-rodar job que falhou" aparece desabilitado com a dica, e a notificação de CI falhou não oferece "Re-rodar". Testes `rerunDisabledWithoutApiScope` e `ciFailedEventLosesRerunWithoutApi` na Task 8.

---

### Task 1: Spike contra a API do GitLab

**Files:**
- Modify: `docs/superpowers/specs/2026-11-05-prumo-contas-gitlab-design.md` (nova seção `## Spike do GitLab (2026-11-05)` no fim, no formato do spike do widget na spec base)

Sem código no repositório. Usar um token pessoal `read_api` da instância do usuário, lido com `read -rs GL_TOKEN` (fora do histórico do shell), e uma pasta temporária fora do repositório para os arquivos de query. Cada chamada vai com `-H "Authorization: Bearer $GL_TOKEN"`; o passo 1 confirma que o `Bearer` vale para token pessoal.

Query que as Tasks 4 e 5 implementam (fragmento `mr`; `detailedMergeStatus` e `mergeRequestInteraction { reviewState }` entram só quando a instância tem):

```graphql
query($mergedAfter: Time!) {
  currentUser {
    username
    authored: authoredMergeRequests(state: opened, first: 50, sort: UPDATED_DESC) { nodes { ...mr } }
    review: reviewRequestedMergeRequests(state: opened, first: 50, sort: UPDATED_DESC) { nodes { ...mr } }
    merged: authoredMergeRequests(state: merged, mergedAfter: $mergedAfter, first: 50) {
      nodes { iid title webUrl mergedAt project { id fullPath } }
    }
  }
}
fragment mr on MergeRequest {
  iid title webUrl draft createdAt updatedAt
  sourceBranch targetBranch sourceProjectId targetProjectId diffHeadSha
  conflicts detailedMergeStatus userNotesCount
  diffStatsSummary { additions deletions }
  project { id fullPath }
  author { username }
  approvedBy { nodes { username } }
  reviewers { nodes { username mergeRequestInteraction { reviewState } } }
  headPipeline { id status jobs(first: 100) { count nodes { id name status allowFailure } } }
  notes(last: 50) { nodes { id body system createdAt url author { username bot } } }
}
```

Introspecção usada pelo `GitLabCapabilities`:

```graphql
{ mr: __type(name: "MergeRequest") { fields { name } }
  interaction: __type(name: "MergeRequestInteraction") { fields { name } }
  reviewState: __type(name: "MergeRequestReviewState") { enumValues { name } } }
```

- [ ] **Step 1: Versão e autenticação.** `GET https://<host>/api/v4/version` e `GET /api/v4/user` com `Bearer`. Anotar a versão e se `Bearer` funcionou (senão, o cliente usa `PRIVATE-TOKEN` para token pessoal).
- [ ] **Step 2: Introspecção.** Rodar a query acima. Anotar: `detailedMergeStatus` em `MergeRequest`; `reviewState` em `MergeRequestInteraction`; `REQUESTED_CHANGES` e `UNREVIEWED` em `MergeRequestReviewState`. Introspecção desligada → anotar; o cliente usa as capacidades mínimas.
- [ ] **Step 3: Query principal.** Rodar a query com `mergedAfter` = meia-noite local em ISO 8601. Confirmar que volta sem `errors`, com os MRs abertos seus e os de review, e medir o tempo de resposta. Campo recusado pela instância → anotar, tirar da query e repetir.
- [ ] **Step 4: Nota de sistema do pedido.** Num MR em que você foi chamado para revisar, listar `notes` e copiar o texto exato da nota de sistema do pedido (esperado `requested review from @<você>`, com variantes `... and @<outro>` e `assigned to @x and requested review from @<você>`). Confirmar que `system: true` e que a nota está entre as 50 últimas. Repetir para "approved this merge request" e, se houver estado, "requested changes".
- [ ] **Step 5: Escopos.** `GET /api/v4/personal_access_tokens/self` com o token pessoal (esperado `scopes: ["read_api"]`). `POST /api/graphql` com `mutation { pipelineRetry(input: {id: "gid://gitlab/Ci::Pipeline/<id>"}) { errors } }` com esse token: anotar o status HTTP e o corpo do erro.
- [ ] **Step 6: glab.** `glab --version`; onde fica o `config.yml` (`$GLAB_CONFIG_DIR`, `~/.config/glab-cli`, `~/Library/Application Support/glab-cli`); se `hosts:` tem `user:` por host; saída de `glab config get token --host <host>` e de `glab auth status --hostname <host> --show-token`; se `glab ci trace <job-id>`, `glab ci get --pipeline-id <id>`, `glab mr diff <iid>`, `glab mr view <iid> --comments` e `glab mr checkout <iid>` funcionam num clone, e se `GITLAB_TOKEN` e `GITLAB_HOST=https://<host>` no ambiente bastam para o `glab` usar outro token sem mexer no login.
- [ ] **Step 7: Registrar o resultado na spec** com o que foi medido em cada passo e a decisão abaixo que se aplica:

| Resultado | O que o plano faz |
| --- | --- |
| Query principal funciona | Tasks 5 e 6 como escritas: uma requisição por refresh por conta |
| Sem `reviewState` | `GitLabReviewRule` usa a regra sem estado: sai ao aprovar ou comentar depois do pedido (spec) |
| Sem `REQUESTED_CHANGES` no enum | "Alterações pedidas" não existe para essa conta (spec) |
| Nota do pedido com outro texto ou fora das 50 últimas | `ReviewRequestNote` usa o texto anotado; sem nota, a hora vem da criação do MR e a aba Notificações avisa (spec, Task 7) |
| Sem `detailedMergeStatus` | `mergeReady = nil` e vale a regra de hoje: aprovado + CI verde + sem conflito |
| `personal_access_tokens/self` indisponível ou token do `glab` | escopos desconhecidos: re-rodar fica habilitado e um 403 mostra a dica do escopo |
| `glab config get token` vazio | o token vem de `glab auth status --show-token` |
| Query principal falha por campo essencial (`authoredMergeRequests`, `reviewRequestedMergeRequests`, `headPipeline`) | parar a etapa e revisar o plano: a alternativa é REST, com uma requisição por MR para pipeline, aprovações e notas |

- [ ] **Step 8: Commit** `docs: registra o spike da api do gitlab`

---

### Task 2: GitLab no modelo

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/GitLab/GitLabID.swift`
- Modify: `Accounts/ProviderKind.swift`, `Accounts/Account.swift`, `Auth/TokenSource.swift`, `Model/PullRequest.swift`, `Model/MergedPullRequest.swift`, `Presentation/MergeReadiness.swift`, `Presentation/RowPresentation.swift`, `Transitions/TransitionEngine.swift`, `Reminders/StaleReviewTracker.swift`, `Keyboard/SearchMatcher.swift`; `GitHub/GitHubError.swift` → `Accounts/ProviderError.swift` (`git mv` e troca do nome em todo o kit, app e testes)
- Test: `AccountListTests.swift`, `TransitionEngineTests.swift`, `MergeReadinessTests.swift`, `RowPresentationTests.swift`, `SearchMatcherTests.swift`, `SnapshotStoreTests.swift`

**Interfaces:**
- Produces:
  - `ProviderKind` ganha `gitlab`. `TokenOrigin` ganha `glabCLI`.
  - `Account.scopes: [String]?` (`decodeLossy`, default `nil` = desconhecido).
  - `GitHubError` passa a se chamar `ProviderError`, com os mesmos casos.
  - `PullRequest` ganha, no fim do `init` e com default: `provider: ProviderKind = .github`, `mergeReady: Bool? = nil`, `failedJobID: Int? = nil` (decode tolerante). Derivados: `reference: String` (`#<n>` ou `!<n>`), `checksURL: URL` (GitHub `url/checks`, GitLab `url/pipelines`), `repositoryKey: String` (GitHub `repository`; GitLab `<url.host>/<repository>`).
  - `MergedPullRequest` ganha `provider` (default `.github`) e os mesmos `reference` e `repositoryKey`.
  - `public enum GitLabID { public static func make(host: String, projectID: Int, iid: Int) -> String; public static func parse(_ id: String) -> (host: String, projectID: Int, iid: Int)? }`, formato `gitlab:<host>:<projectID>:<iid>`, host em minúsculas.
  - `MergeReadiness.isReady`: com `pr.mergeReady` não nil, devolve `mergeReady && !pr.isDraft`; senão, a regra de hoje.
  - Títulos de notificação, lembrete, subtítulo e linha compacta usam `pr.reference` no lugar de `#\(pr.number)`; o evento de CI usa `checksURL`.
  - `SearchMatcher` tira `#` e `!` do começo do termo.

- [ ] **Step 1: Testes** `providerDefaultsToGitHubInOldJSON`, `accountWithGlabOriginAndScopesDecodes`, `labelShowsCustomHost` (conta GitLab `adriano` em `gitlab.empresa.com` → `"adriano · gitlab.empresa.com"`), `labelHidesGitlabCom`, `referenceUsesBangForGitLab` (`"!341"`), `repositoryKeyForGitLabIncludesHost` (`"gitlab.empresa.com/vendas/api"`), `gitLabIDRoundTrip`, `gitLabIDDiffersBetweenHosts`, `mergeReadyOverridesRule` (`mergeReady: false` com aprovação e CI verde → não pronto; `true` sem aprovação → pronto; draft → não pronto), `transitionTitlesUseReference` (`"!341 aprovado"`, `"CI falhou em !341"`), `gitlabCIURLIsPipelinesTab`, `searchAcceptsBang` (`"!341"` acha o MR 341), `subtitleUsesReference` (`"vendas/api !341 · 5h"`).
- [ ] **Step 2:** `swift test` → FAIL nos testes novos.
- [ ] **Step 3:** Implementar, incluindo a troca de `GitHubError` por `ProviderError` no app.
- [ ] **Step 4:** `swift test` → PASS; build do app → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat(kit): adiciona o gitlab como provedor no modelo`

---

### Task 3: Chave de repositório com host nos filtros

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Organization/RowFiltering.swift`, `Organization/RepositoryCatalog.swift`, `Organization/RepositoryEntry.swift`, `Organization/RowOrdering.swift`, `PRumo/Services/OrganizationStore.swift`, `PRumo/Views/Popover/PopoverView.swift`, `PRumo/Views/Popover/Filters/RepositoryPicker.swift`, `PRumo/Views/Settings/SettingsView.swift`
- Test: `RowFilteringTests.swift`, `RepositoryCatalogTests.swift`, `RowOrderingTests.swift`

**Interfaces:**
- Consumes: `repositoryKey` (Task 2)
- Produces:
  - `RepositoryEntry.displayName: String` (init com default = `name`): o caminho sem o host para entradas de conta GitLab.
  - Filtro de repositórios, favoritos, `knownRepositories`, `repositoryAccounts`, contagem do catálogo, agrupamento por repositório do `RowOrdering` e o filtro dos mergeados de hoje passam a usar `repositoryKey`. Chaves do GitHub não mudam, então filtros e visões salvos continuam valendo.
  - No catálogo, a org de uma chave GitLab é o primeiro segmento do caminho depois do host (`gitlab.empresa.com/vendas/api` → `VENDAS`).

- [ ] **Step 1: Testes** `filterMatchesGitLabByKey` (`gitlab.empresa.com/vendas/api` não casa com `globex/vendas`), `sameProjectPathOnTwoHostsAreDistinct`, `catalogGroupsGitLabByFirstPathSegment`, `displayNameDropsHost`, `githubKeysUnchanged`.
- [ ] **Step 2:** `swift test --filter "RowFilteringTests|RepositoryCatalogTests|RowOrderingTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS; build → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat: usa o host na chave de repositório do gitlab`

---

### Task 4: Regra de saída de Revisar e hora do pedido

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/GitLab/GitLabUser.swift`, `GitLab/GitLabNote.swift`, `GitLab/GitLabCapabilities.swift`, `GitLab/ReviewRequestNote.swift`, `GitLab/GitLabReviewRule.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/GitLabReviewRuleTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct GitLabUser: Decodable, Equatable, Sendable { let username: String; let bot: Bool? }
  struct GitLabNote: Decodable, Equatable, Sendable { let id: String; let body: String; let system: Bool; let createdAt: Date; let url: URL?; let author: GitLabUser? }
  public struct GitLabCapabilities: Codable, Equatable, Sendable {
      public var hasReviewState: Bool; public var hasRequestedChanges: Bool; public var hasDetailedMergeStatus: Bool
      public static let minimal: GitLabCapabilities
  }
  enum ReviewRequestNote {
      static func requestedAt(notes: [GitLabNote], username: String) -> Date?
      static func approvedAt(notes: [GitLabNote], username: String) -> Date?
      static func changesRequestedAt(notes: [GitLabNote], username: String) -> Date?
  }
  enum GitLabReviewRule {
      static func isPending(reviewState: String?, approvedByMe: Bool, myLastCommentAt: Date?, requestedAt: Date,
                            capabilities: GitLabCapabilities) -> Bool
  }
  ```
  - `requestedAt`: a última nota com `system == true`, corpo contendo `requested review from` e `@<username>` como token inteiro (o caractere seguinte não é letra, dígito, `.`, `_` nem `-`), comparado sem diferenciar maiúsculas. Sem nota → `nil` (o mapper usa `createdAt`).
  - `approvedAt` e `changesRequestedAt`: última nota de sistema do autor `username` com corpo começando em `approved this merge request` e `requested changes`, respectivamente. O texto exato é o anotado no spike.
  - `isPending` com `hasReviewState`: `!approvedByMe && reviewState == "UNREVIEWED"`. Sem estado: `!approvedByMe && !(myLastCommentAt.map { $0 > requestedAt } ?? false)`.

- [ ] **Step 1: Testes** `pendingWhileUnreviewed`, `leavesWhenApproved`, `leavesWhenStateNotUnreviewed` (`REVIEWED`, `REQUESTED_CHANGES`), `returnsWhenReRequested` (estado volta a `UNREVIEWED`), `withoutStateLeavesOnCommentAfterRequest`, `withoutStateCommentBeforeRequestKeeps`, `withoutStateReRequestAfterCommentReturns`, `requestedAtFromSystemNote` (`"requested review from @maria and @adriano"`), `requestedAtUsesLatestRequest`, `requestedAtIgnoresSimilarUsername` (`@adriano.silva` e `@adriano2` não contam para `adriano`), `requestedAtIgnoresUserNotes` (nota comum com o mesmo texto), `requestedAtNilWithoutNote`.
- [ ] **Step 2:** `swift test --filter GitLabReviewRuleTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): decide quando o mr sai de revisar e a hora do pedido`

---

### Task 5: Cliente GitLab e mapeamento da tabela da spec

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/GitLab/GitLabClient.swift`, `GitLab/GitLabQueries.swift`, `GitLab/GitLabResponse.swift`, `GitLab/MergeRequestMapper.swift`, `GitLab/GitLabCapabilityCache.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/GitLabClientTests.swift`, `MergeRequestMapperTests.swift`, `Fixtures/gitlab-snapshot.json`, `Fixtures/gitlab-snapshot-old.json` (sem `detailedMergeStatus` nem `mergeRequestInteraction`), `Fixtures/gitlab-introspection.json`

**Interfaces:**
- Consumes: Tasks 2 e 4, `AccountClient` (etapa 8)
- Produces:
  ```swift
  public struct GitLabClient: AccountClient {
      public init(host: String, token: String, transport: HTTPTransport = URLSessionTransport(), now: @escaping @Sendable () -> Date = Date.init)
      public func currentUsername() async throws(ProviderError) -> String
      public func capabilities() async -> GitLabCapabilities
      public func tokenScopes() async -> [String]?
      public func fetchSnapshot() async throws(ProviderError) -> Snapshot
      public func pullRequestStates(ids: [String]) async throws(ProviderError) -> [String: PRState]
      public func rerunFailedJobs(pr: PullRequest) async throws(ProviderError)
  }
  enum GitLabQueries { static func snapshot(_ capabilities: GitLabCapabilities) -> String; static let introspection: String; static let currentUser: String }
  enum MergeRequestMapper { static func snapshot(_ data: Data, host: String, capabilities: GitLabCapabilities, now: Date) throws -> Snapshot }
  ```
  - Endpoint `https://<host>/api/graphql`; header `Authorization: Bearer <token>` (ou o que o spike anotou). `capabilities()` roda a introspecção uma vez por cliente (cache no actor `GitLabCapabilityCache`); erro → `.minimal`. `tokenScopes()`: `GET /api/v4/personal_access_tokens/self`, erro → `nil`.
  - Erros: transport lança → `.network`; 401 → `.unauthorized`; 429 → `.rateLimited` com `Retry-After` (segundos) ou `RateLimit-Reset` (epoch); outro não-2xx → `.server(status:)`; `errors` sem `data` → `.graphQL`; JSON fora do esperado → `.unexpectedResponse`.
  - `pullRequestStates`: para cada id que `GitLabID.parse` reconhece e cujo host é o do cliente, `GET /api/v4/projects/<projectID>/merge_requests/<iid>`; `state` `opened`/`closed`/`merged` → `PRState`. Até 20 ids por chamada; falha num id não derruba os outros.

Mapeamento (spec, "Como o GitLab mapeia nas regras de hoje"):

| Campo do `PullRequest` | Vem de |
| --- | --- |
| `id` | `GitLabID.make(host:, projectID: project.id numérico do gid, iid:)` |
| `number`, `url`, `title`, `isDraft`, `createdAt`, `updatedAt` | `iid`, `webUrl`, `title`, `draft`, `createdAt`, `updatedAt` |
| `repository` | `project.fullPath` |
| `author` | `author.username` |
| `headSHA`, `headRefName`, `baseRefName` | `diffHeadSha`, `sourceBranch`, `targetBranch` |
| `isCrossRepository` | `sourceProjectId != targetProjectId` |
| `additions`, `deletions` | `diffStatsSummary` |
| `mergeable` | `conflicts == true` → `.conflicting`; senão `.mergeable` |
| `mergeReady` | com `hasDetailedMergeStatus`: `detailedMergeStatus == "MERGEABLE"`; senão `nil` |
| `ci` | sem `headPipeline` → `.none`. `SUCCESS` e `MANUAL` → `.success(total: jobs.count)`. `FAILED` e `CANCELED` → `.failure(failedChecks:` nomes dos jobs `FAILED` sem `allowFailure`, ou `["pipeline"]` se não houver`, total:)`. `SKIPPED` → `.none`. Outros → `.pending(done:` jobs em estado terminal`, total:)` |
| `failedRunID`, `failedRunName`, `failedJobID` | id numérico do pipeline, nome e id do primeiro job falho sem `allowFailure` (só com CI em falha) |
| `reviews` | um `.approved` por `approvedBy` (fora você), data de `ReviewRequestNote.approvedAt` ou `updatedAt`, id `approval:<username>@<data>`; com `hasRequestedChanges`, um `.changesRequested` por reviewer com `reviewState == "REQUESTED_CHANGES"`, data de `changesRequestedAt` ou `updatedAt` |
| `comments`, `commentCount` | notas com `system == false` e autor sem `bot`; `commentCount = userNotesCount`. Os autores ignorados e você continuam fora pelo `CommentAuthorFilter` e pelo `TransitionEngine`, como no GitHub |
| `reviewRequestedAt` | `ReviewRequestNote.requestedAt` ou `createdAt` |
| `reviewTarget`, `reviewDecision`, `provider` | `.you`, `nil`, `.gitlab` |
| Meus PRs / Revisar | `authored` / `review` filtrado por `GitLabReviewRule.isPending` (MR seu nunca entra em Revisar) |
| `mergedToday` | `merged`, com o mesmo id |

- [ ] **Step 1: Testes** `mapsAuthoredToMine`, `mapsReviewRequestedToReview`, `idIncludesHostAndProject`, `pipelineSuccessIsCISuccess` (`.success(total: 7)`), `pipelineFailedNamesFirstFailedJob` (com `failedRunID`, `failedJobID`), `allowedFailureJobDoesNotFailCI` (pipeline `SUCCESS` com job `allowFailure` falhado → `.success`), `pipelineRunningIsPending` (`.pending(done: 3, total: 7)`), `canceledPipelineIsFailure`, `noPipelineIsNone`, `approvedByBecomesApprovedReviewsExceptMe`, `requestedChangesFromReviewerState`, `noRequestedChangesWithoutCapability`, `commentsExcludeSystemAndBots`, `conflictsAndDetailedMergeStatus` (`MERGEABLE` → `true`; `NOT_APPROVED` → `false`; fixture antiga → `nil`), `crossProjectIsCrossRepository`, `requestedAtFallsBackToCreatedAt`, `mergedTodayMapped`, `queryOmitsMissingCapabilities` (`.minimal` → query sem `detailedMergeStatus` nem `mergeRequestInteraction`), `capabilitiesFromIntrospection`, `introspectionFailureIsMinimal`, `unauthorized401`, `rateLimited429UsesRetryAfter`, `graphQLErrorsWithoutData`, `transportErrorIsNetwork`, `statesFromRESTSkipOtherHosts`, `tokenScopesNilOnError`.
- [ ] **Step 2:** `swift test --filter "GitLabClientTests|MergeRequestMapperTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): lê os mrs do gitlab com o mapeamento da spec`

---

### Task 6: Detecção do `glab` e token

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Auth/GlabAccount.swift`, `Auth/GlabConfigFile.swift`, `Auth/GlabAccountDiscovery.swift`
- Modify: `PRumoKit/Sources/PRumoKit/Accounts/AccountTokenResolver.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/GlabAccountDiscoveryTests.swift`, `Fixtures/glab-config.yml`, `AccountTokenResolverTests.swift`

**Interfaces:**
- Consumes: `ProcessRunner`
- Produces:
  ```swift
  public struct GlabAccount: Equatable, Sendable { public let host: String; public let login: String? }
  public enum GlabConfigFile { public static func accounts(fromYAML text: String) -> [GlabAccount] }
  public struct GlabAccountDiscovery: Sendable {
      public init(runner: ProcessRunner, environment: [String: String], home: URL,
                  readFile: @escaping @Sendable (URL) -> String?,
                  candidatePaths: [String] = ["/opt/homebrew/bin/glab", "/usr/local/bin/glab"],
                  fileExists: @escaping @Sendable (String) -> Bool)
      public func accounts() async -> [GlabAccount]
      public func token(host: String) async -> String?
  }
  ```
  `AccountTokenResolver.init(tokenStore:gh:glab: GlabAccountDiscovery)`; `.glabCLI` → `glab.token(host: account.host)`.
  - Config: primeiro `config.yml` que existir em `$GLAB_CONFIG_DIR`, `$XDG_CONFIG_HOME/glab-cli`, `~/.config/glab-cli`, `~/Library/Application Support/glab-cli` (ordem confirmada no spike). Hosts são as chaves do bloco `hosts:`; `user:` dentro do host, quando existe, vira `login`.
  - Host aceito só com `^[A-Za-z0-9.-]+(:[0-9]+)?$`; outro valor → ignorado, sem rodar nada.
  - `token(host:)`: `glab config get token --host <host>`; saída vazia → `glab auth status --hostname <host> --show-token` e a linha `Token: <valor>` da saída de erro ou padrão; nada → `nil`.

- [ ] **Step 1: Testes** `parsesHostsAndUsers` (`gitlab.com` e `gitlab.empresa.com` com `user: adriano`), `hostWithoutUserHasNilLogin`, `configDirOrder`, `tokenFromConfigGet` (runner confere `["config", "get", "token", "--host", "gitlab.empresa.com"]`), `tokenFallsBackToAuthStatus`, `unsafeHostNeverRuns`, `noGlabBinaryReturnsNoToken`, `glabAccountAsksGlabForHost` (resolver).
- [ ] **Step 2:** `swift test --filter "GlabAccountDiscoveryTests|AccountTokenResolverTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): detecta as contas do glab e lê o token`

---

### Task 7: Contas GitLab no app

**Files:**
- Create: `PRumo/Resources/Assets.xcassets/ProviderGitLab.imageset/` (SVG `gitlab` do Simple Icons, CC0, template)
- Modify: `PRumo/AppModel.swift`, `PRumo/Services/AccountSession.swift`, `PRumo/Views/Settings/AddAccountSheet.swift`, `AddAccountModel.swift`, `AccountRowView.swift`, `AccountsSettingsConstants.swift`, `NotificationsSettingsView.swift`, `NotificationsSettingsConstants.swift`, `PRumo/Views/Popover/PRRowView.swift`

**Interfaces:**
- Consumes: `GitLabClient` (Task 5), `GlabAccountDiscovery` (Task 6), `ProviderKind.gitlab`, `Account.scopes` (Task 2)
- Produces: `AddAccountModel.provider: ProviderKind`, `address: String`, `detectedGlab: [GlabAccount]`; `AppModel` cria `GitLabClient(host:token:)` para conta `.gitlab`.

Folha `Adicionar conta` (mockup parte 2):
- Seletor `GitHub` / `GitLab` no topo.
- GitLab: contas do `glab` ainda não adicionadas, `Encontrei no glab: @<login> em <host>` e o botão `Usar` (sem `user:` no config, o login vem de `currentUsername()` antes de mostrar). Depois `ou com um token pessoal:`, campos `Endereço` (placeholder `gitlab.com`), `Token pessoal (escopo read_api)`, `Apelido`, e o link `Criar token no GitLab` para `https://<host>/-/user_settings/personal_access_tokens?name=PRumo&scopes=read_api`.
- Endereço: tira `https://` e `/` do fim, minúsculas; `http://` → erro `Use um endereço https.`; host inválido → `Endereço inválido.`.
- `Conectar`: `currentUsername()` valida, `tokenScopes()` grava `scopes`. Erros: 401 `Token inválido ou sem o escopo read_api.`; rede `Sem acesso a <host>. Confira a VPN.`; repetida `Essa conta já está na lista.`.

Aba Contas: origem `.glabCLI` → `token do glab`; ícone `ProviderGitLab`. Linha do popover: ícone `ProviderGitLab` para `accountProvider == .gitlab`.

Aba Notificações: com alguma conta GitLab, nota em texto secundário abaixo de "Lembrar review parado após": `No GitLab, quando a hora do pedido de review não aparece no histórico do MR, o PRumo conta a espera a partir da criação do MR. Nesses casos, o lembrete de review parado e a ordem por espera ficam aproximados.`

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Rodar o app: adicionar a conta de `gitlab.empresa.com` pelo `glab` e uma do `gitlab.com` por token; MRs aparecem misturados nas abas com `adriano · gitlab.empresa.com · vendas/api !341 · 5h`; desligar a VPN mostra o banner só da conta da instância.
- [ ] **Step 4: Commit** `feat(app): adiciona contas do gitlab`

---

### Task 8: Re-rodar pipeline e o escopo `api`

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Accounts/RerunAvailability.swift`
- Modify: `PRumoKit/Sources/PRumoKit/Presentation/RowMenuEntry.swift`, `Presentation/RowMenuPlan.swift`, `Transitions/NotificationEvent.swift`, `PRumo/AppModel.swift`, `PRumo/Views/Popover/RowMenuItems.swift`, `RowMenuNSMenu.swift`, `RowMenuEntry+Presentation.swift`, `RowMenuConstants.swift`
- Test: `RowMenuPlanTests.swift`, `GitLabClientTests.swift`, `PRumoKit/Tests/PRumoKitTests/RerunAvailabilityTests.swift`

**Interfaces:**
- Consumes: `Account.scopes` (Task 2), `GitLabClient.rerunFailedJobs(pr:)` (Task 5)
- Produces:
  - `public enum RerunAvailability { public static func disabledReason(provider: ProviderKind, scopes: [String]?) -> String? }`: GitLab com escopos conhecidos sem `api` → `Precisa de um token com escopo api. O desta conta só lê (read_api).`; o resto → `nil`.
  - `RowMenuEntry.rerunFailedJobs(jobName: String, runID: Int, disabledReason: String?)`; `RowMenuPlan.entries(..., rerunDisabledReason: String? = nil)`. O app desabilita o item e mostra a razão em `.help`/`toolTip`.
  - `NotificationEvent.withoutRerun() -> NotificationEvent` (cópia com `failedRunID = nil`). O `AppModel` aplica nos eventos de contas com razão não nil, e a notificação usa a categoria sem "Re-rodar".
  - `GitLabClient.rerunFailedJobs(pr:)`: mutation `pipelineRetry(input: {id: "gid://gitlab/Ci::Pipeline/<failedRunID>"}) { errors }`; `errors` não vazio → `.graphQL(messages:)`; 403 → `.server(status: 403)`, e o alerta do app mostra `O token desta conta não tem o escopo api.`.

- [ ] **Step 1: Testes** `rerunDisabledWithoutApiScope`, `rerunEnabledWhenScopesUnknown`, `rerunEnabledWithApiScope`, `githubRerunUnaffected`, `planCarriesDisabledReason`, `ciFailedEventLosesRerunWithoutApi`, `retryMutationSendsPipelineGID` (corpo com `gid://gitlab/Ci::Pipeline/987`), `retry403MapsToServer403`, `retryErrorsMapToGraphQL`.
- [ ] **Step 2:** `swift test --filter "RowMenuPlanTests|GitLabClientTests|RerunAvailabilityTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS; build → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat: re-roda a pipeline do gitlab quando o token tem escopo api`

---

### Task 9: Worktree, clone e fetch do MR

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Claude/WorktreeManager.swift`, `Claude/RemoteURL.swift`, `Claude/CloneLocator.swift`, `Claude/CloneValidator.swift`, `Claude/ClaudeLauncher.swift`, `PRumo/Services/ClaudeSettingsStore.swift`, `PRumo/AppModel.swift`
- Test: `WorktreeManagerTests.swift`, `CloneLocatorTests.swift`, `CloneValidatorTests.swift`, `ClaudeLauncherTests.swift`

**Interfaces:**
- Consumes: `repositoryKey`, `provider` (Task 2)
- Produces:
  - `RemoteURL.repositoryKey(from url: String, gitlabHosts: Set<String>) -> String?`: GitHub → `org/repo` como hoje; host em `gitlabHosts` → `<host>/<caminho>` em minúsculas, com subgrupos, aceitando `git@host:grupo/sub/repo.git`, `https://host/grupo/repo(.git)` e `ssh://git@host[:porta]/grupo/repo.git`; outro host → `nil`. `repository(from:)` vira `repositoryKey(from:gitlabHosts: [])`.
  - `CloneLocator.init(root:fileSystem:runner:gitlabHosts: Set<String> = [])`; `CloneValidator.isClone(of:directory:runner:gitlabHosts: Set<String> = [])`. O app passa os hosts das contas GitLab.
  - `ClaudeLauncher` procura o clone por `pr.repositoryKey`, e `cloneNotFound(repository:)` leva a chave.
  - `WorktreeManager`: o fetch do ref do PR passa a depender do provedor. GitHub `+pull/<n>/head:refs/prumo/pull/<n>` como hoje; GitLab `+refs/merge-requests/<iid>/head:refs/prumo/pull/<iid>`. O resto (branch própria quando não é fork, `HEAD` solto em fork e revisão, limpeza) não muda.

- [ ] **Step 1: Testes** `gitlabFetchUsesMergeRequestRef` (runner confere `["-C", clone, "fetch", "origin", "+refs/merge-requests/341/head:refs/prumo/pull/341"]`), `githubFetchUnchanged`, `remoteKeyForGitLabSSH`, `remoteKeyForNestedGroupHTTPS` (`https://gitlab.empresa.com/vendas/core/api.git` → `gitlab.empresa.com/vendas/core/api`), `remoteKeyWithPort`, `remoteKeyIgnoresUnconfiguredHost`, `scanFindsGitLabClone`, `validatorAcceptsGitLabClone`, `launcherLooksUpCloneByKey`.
- [ ] **Step 2:** `swift test --filter "WorktreeManagerTests|CloneLocatorTests|CloneValidatorTests|ClaudeLauncherTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS; build → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat(kit): prepara worktree e clone para mr do gitlab`

---

### Task 10: Prompts do Claude por provedor e ambiente do `glab`

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Claude/ClaudeSettings.swift`, `Claude/ClaudeDefaults.swift`, `Claude/PromptValues.swift`, `Claude/ClaudeLauncher.swift`, `Accounts/SessionEnvironment.swift`, `PRumo/Views/Settings/ClaudeSettingsView.swift`, `ClaudeSettingsConstants.swift`
- Test: `ClaudeSettingsTests.swift`, `PromptTemplateTests.swift`, `ClaudeLauncherTests.swift`, `TerminalCommandTests.swift`

**Interfaces:**
- Consumes: `pr.provider`, `failedJobID` (Task 2), `SessionEnvironment` (etapa 8)
- Produces:
  - `ClaudeSettings` ganha `gitlabReviewTemplate`, `gitlabCiTemplate`, `gitlabConflictTemplate`, `gitlabCommentsTemplate` (`decodeIfPresent ?? ClaudeDefaults.gitlab...`) e `func templates(for provider: ProviderKind) -> (review: String, ci: String, conflict: String, comments: String)`. O launcher escolhe pelo `pr.provider`.
  - `PromptValues.ci` ganha `jobid` (`failedJobID` ou `""`).
  - `SessionEnvironment.variables(provider: .gitlab, host:, token:)` → `["GITLAB_TOKEN": token, "GITLAB_HOST": "https://<host>"]`.
  - Defaults (`glab ci view` é interativo, por isso o template de CI usa `glab ci get` e `glab ci trace`, conferidos no spike):
    - revisão: `Revise o MR !{numero} ({repo}). Leia a descrição com glab mr view {numero} e o diff com glab mr diff {numero}, e aponte problemas de correção, segurança e contrato. Não comente no GitLab; mostre o resultado aqui.`
    - CI: `A pipeline {run} do MR !{numero} ({repo}) falhou no job {job}. Leia o log com glab ci trace {jobid} e o estado da pipeline com glab ci get --pipeline-id {run}, encontre a causa e corrija.`
    - conflito: `O MR !{numero} ({repo}) está em conflito com {base}. Atualize a branch com git fetch origin {base} e git merge origin/{base}, resolva os conflitos mantendo a intenção das duas partes, rode os testes e faça commit do merge.`
    - comentários: `O MR !{numero} ({repo}) recebeu comentários de review. Leia os comentários com glab mr view {numero} --comments, aplique as alterações pedidas que fizerem sentido, rode os testes e faça commit. Não responda nem resolva as discussões no GitLab; me mostre um resumo do que mudou e do que você não aplicou.`
  - Ajustes › IA: seletor `GitHub` / `GitLab` acima dos templates; cada lado edita os seus quatro, com `Restaurar padrão` como hoje.

- [ ] **Step 1: Testes** `oldClaudeSettingsJSONGetsGitLabDefaults`, `gitlabReviewDefaultUsesGlabMrDiff`, `gitlabCITemplateRendersJobAndPipeline` (`{jobid}` 555 e `{run}` 987), `launcherUsesGitLabTemplateForMR`, `launcherKeepsGitHubTemplateForPR`, `gitlabEnvironmentHasTokenAndHost`, `gitlabPromptWithShellTextStaysQuoted` (título `` `id` $(rm -rf ~) 'x' `` e branch `feat/$(whoami)` → a única ocorrência no script está dentro do argumento aspado do prompt, e nenhuma linha começa com esses textos).
- [ ] **Step 2:** `swift test --filter "ClaudeSettingsTests|PromptTemplateTests|ClaudeLauncherTests|TerminalCommandTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS; build → `BUILD SUCCEEDED`.
- [ ] **Step 5:** Rodar "Corrigir CI com Claude" num MR com pipeline falha: no terminal, `glab api user` mostra a conta do MR, `glab auth status` continua com o login de antes e o script já não está em `~/Library/Caches/PRumo/sessions/`.
- [ ] **Step 6: Commit** `feat: usa templates e token do gitlab nas sessões do claude`

---

### Task 11: `glab mr checkout` e aviso de conta

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Presentation/RowMenuPlan.swift`, `Accounts/CheckoutWarning.swift`, `PRumo/AppModel.swift`, `PRumo/Views/Popover/RowMenuConstants.swift`
- Test: `RowMenuPlanTests.swift`, `CheckoutWarningTests.swift`

**Interfaces:**
- Consumes: `GlabAccountDiscovery.accounts()` (Task 6), `CheckoutWarning` (etapa 8)
- Produces:
  - Comando copiado por provedor: GitHub `gh pr checkout <n>`; GitLab `glab mr checkout <iid>`. Título do item: `Copiar <comando>`.
  - `CheckoutWarning.text(account:activeLogin:accountCount:)` para GitLab, com `activeLogin` = login do `glab` naquele host:
    - não logado → `O glab não está logado em <host>. Rode glab auth login --hostname <host> antes de colar o comando.`;
    - outro login → `O glab está logado em <host> como @<ativo>. Rode glab auth login --hostname <host> com o token de @<login> antes de colar o comando.`.
  - `AppModel.glabLogins: [String: String]` (host → login), lido junto com `ghActiveLogin`; host sem `user:` no config usa `currentUsername()` com o token do `glab`, uma vez por execução.

- [ ] **Step 1: Testes** `gitlabCheckoutCommand` (`"glab mr checkout 341"`), `githubCheckoutUnchanged`, `gitlabWarningWhenGlabNotLogged`, `gitlabWarningWhenOtherLogin`, `noGitlabWarningWhenSameLogin`.
- [ ] **Step 2:** `swift test --filter "RowMenuPlanTests|CheckoutWarningTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS; build → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat: copia glab mr checkout com aviso de conta`

---

### Task 12: Links do widget para os hosts configurados

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Widget/WidgetLink.swift`, `Widget/WidgetItem.swift`, `Widget/WidgetSummary.swift`, `PRumo/Services/AppDelegate.swift`, `PRumoWidget/MediumWidgetView.swift`
- Test: `WidgetSharedStoreTests.swift`, `WidgetSummaryTests.swift`

**Interfaces:**
- Consumes: `AccountList` (etapa 8), `reference` (Task 2)
- Produces:
  - `WidgetLink.target(from: URL, allowedHosts: Set<String> = ["github.com"]) -> URL?`: só `https`, host igual a um dos permitidos sem diferenciar maiúsculas, sem subdomínio nem sufixo.
  - `AppDelegate` monta `allowedHosts` = `github.com` mais os hosts das contas GitLab de `AccountList.decode(UserDefaults.standard.data(forKey: AppConstants.accountsKey))`.
  - `WidgetItem.reference: String` (`decodeLossy`, default `""`); `WidgetSummary` preenche com `pr.reference`; o widget mostra `reference`, ou `#<n>` quando vazio.

- [ ] **Step 1: Testes** `allowsConfiguredGitLabHost`, `rejectsUnconfiguredHost`, `rejectsLookalikeHost` (`gitlab.empresa.com.evil.io` e `evilgitlab.empresa.com`), `rejectsHttp`, `githubStillAllowedByDefault`, `oldWidgetItemJSONWithoutReferenceDecodes`, `summaryCarriesBangReference`.
- [ ] **Step 2:** `swift test --filter "WidgetSharedStoreTests|WidgetSummaryTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS; build → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat(widget): abre mrs dos hosts gitlab configurados`

---

### Task 13: Verificação ponta a ponta

- [ ] **Step 1:** `swift test` → todos PASS. `xcodegen generate && xcodebuild clean build` → `BUILD SUCCEEDED`, zero warnings do projeto.
- [ ] **Step 2 (usuário):** adicionar a conta de `gitlab.empresa.com`: nada notifica na primeira leitura; MRs em Meus PRs e Revisar com CI, aprovações, comentários, conflito e draft como no GitLab.
- [ ] **Step 3 (usuário):** pedir sua revisão num MR → notificação `Review pedido: !<iid>` com o login no subtítulo; aprovar → o MR sai de Revisar no refresh seguinte.
- [ ] **Step 4 (usuário):** pipeline falhando → `CI falhou em !<iid>`, abre a aba de pipelines; com token `read_api`, o item de re-rodar fica desabilitado com a dica.
- [ ] **Step 5 (usuário):** as quatro ações do Claude num MR abrem a worktree certa e o `glab` dentro da sessão usa a conta do MR.
- [ ] **Step 6 (usuário):** `Copiar glab mr checkout <iid>` cola e funciona no clone; widget abre o MR no navegador.

---

## Self-review

1. **Cobertura da spec (etapa 2):** spike de REST ou GraphQL, versão, estado do reviewer e nota do pedido, com os fallbacks da spec (Task 1); cliente e tabela de mapeamento (Tasks 2 e 5); regra de saída de Revisar (Task 4); hora do pedido e o aviso na aba Notificações (Tasks 4 e 7); `glab` e token (Tasks 6 e 7); re-rodar com escopo `api` (Task 8); worktree, fetch `refs/merge-requests/<iid>/head` e clone pelo `remote` (Task 9); prompts por provedor com `GITLAB_TOKEN`/`GITLAB_HOST` (Task 10); `glab mr checkout` (Task 11); widget com os hosts configurados (Task 12); id com host (Tasks 2 e 5); `!iid` na linha e nas notificações (Task 2); Jira, copiar link e as outras ações já são genéricas. Grupos e regras de aprovação ficam fora, como manda a spec.
2. **Passos:** testes com nomes e valores; código com assinatura, arquivo e regra; o mapeamento fica numa tabela, sem corpo de função.
3. **Tipos:** `ProviderError` (Task 2) usado nas Tasks 5 e 8; `GitLabCapabilities` (Task 4) usado na Task 5; `GitLabNote` (Task 4) reaproveitado no decode da Task 5; `RowMenuEntry.rerunFailedJobs(jobName:runID:disabledReason:)` igual nas Tasks 8 e no app; `repositoryKey` (Task 2) nas Tasks 3 e 9.
4. **Review Focus:** os cinco itens têm teste na task dona (Tasks 4, 5, 8 e 10).
5. **Proporção:** as únicas peças longas são a query GraphQL e a tabela de mapeamento, que são decisões que o implementador não teria como tomar sozinho.
