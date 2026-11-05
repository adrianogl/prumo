# PRumo: Etapa 8 (Várias contas do GitHub) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Acompanhar várias contas do GitHub numa lista só, com token por conta no Keychain, refresh em paralelo, aviso por conta e a conta na linha quando há mais de uma, sem perder nada de quem hoje usa uma conta.

**Architecture:** Cada conta tem a própria sessão (cliente, `RefreshCoordinator` e snapshot em disco), e o `TransitionEngine` continua rodando por conta contra a linha de base dela. O kit ganha a lista de contas, a combinação dos snapshots com a regra de dedupe da spec, o refresh em paralelo e a linha de base de lembretes por conta. O app troca o par token/coordinator único por um mapa de sessões e passa a trabalhar com o snapshot combinado, que carrega o login de cada conta (`accountViewers`) para as regras que dependem de "quem sou eu".

**Tech Stack:** Swift 6.4, SwiftUI, Swift Testing, Security (Keychain), `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-11-05-prumo-contas-gitlab-design.md` (etapa 1 da "Ordem de entrega", "Casos decididos depois da revisão do design", "Telas"), sobre `docs/superpowers/specs/2026-11-05-prumo-design.md`. Mockup: `docs/mockups/contas.html`, partes 1 (opção A), 2 e 3.

**Base:** `main`, depois da etapa 7. Commits direto na `main`.

## Global Constraints

- macOS 26 mínimo, Swift 6.4. Pacote SwiftPM `PRumoKit` + app `PRumo` gerado pelo XcodeGen (`project.yml`).
- Sem comentários no código.
- Kit: um tipo por arquivo. App: textos, medidas e símbolos em enums `XxxText`/`XxxMetrics`/`XxxSymbol` no `XxxConstants.swift` da pasta; nada de constante ou type solto dentro de view.
- Copy da interface em PT-BR, exatamente como escrita neste plano.
- Decode tolerante: todo campo novo de tipo persistido (UserDefaults, `snapshot.json`, `reminders.json`, `worktrees.json`) usa os helpers `decodeLossy`/`decodeLossyArray`/`decodeLossyDictionary` de `Organization/KeyedDecodingContainer+Lossy.swift` (ou `decodeIfPresent` com default nos tipos que já usam esse padrão), com teste de JSON antigo sem o campo.
- Testes nunca rodam `git`, `gh`, `glab` ou `osascript` reais nem chamam rede: `ProcessRunner` e `HTTPTransport` fakes, leitura de arquivo injetada.
- Tokens só no Keychain, um item por conta. A única exceção é o script temporário da sessão do Claude (0700, em `~/Library/Caches/PRumo/sessions/`), apagado na primeira linha do próprio script.
- Ids de PR do GitHub continuam o node id. Nada que hoje é chaveado por id (fixados, silenciados, atividade nova, worktrees, lembretes) muda de chave.
- Com uma conta configurada, nenhuma tela muda: sem conta na linha, sem subtítulo na notificação, sem agrupamento por conta no filtro, banner de conexão como hoje.
- Nenhum nome de empresa real em código, testes ou docs. Usar `acme`, `globex`, `contoso` e `gitlab.empresa.com`; logins de exemplo `adrianogl` e `adriano-globex`.
- Commits direto na `main`, Conventional Commits em PT-BR (minúsculas, imperativo, sem ponto final), sem `Co-Authored-By` e sem menção a IA.
- Kit em TDD com Swift Testing (`@Test`, `#expect`): `cd PRumoKit && swift test`.
- Build do app: `xcodegen generate && xcodebuild -project PRumo.xcodeproj -scheme PRumo -destination 'platform=macOS' build` → `** BUILD SUCCEEDED **`, zero warnings do projeto.

## Review Focus

1. **Atualizar o app com uma conta já em uso**: a primeira leitura depois da atualização não notifica nada, não dispara lembrete, mantém fixados, silenciados, worktrees e a lista igual. Testes `migratedFirstRefreshProducesNoEvents` e `remindersBaselinedForMigratedAccount` na Task 6.
2. **PR seu numa conta e com review pedido a você na outra**: uma linha só, em Meus PRs, sem notificação de review pedido. Testes `prAuthoredInOneAndRequestedInOtherStaysInMine` e `reviewRequestedEventFromNonOwnerDropped` na Task 3.
3. **Adicionar uma conta que já tem reviews parados e PRs com CI vermelha**: nada é notificado, nem lembrete. Testes `newAccountFirstRefreshHasNoEvents` na Task 4 e `newAccountStaleReviewsBaselinedSilently` na Task 5.
4. **Uma conta perde o acesso (`gh auth logout` daquele usuário, VPN, token revogado)**: só ela fica com aviso e itens esmaecidos; as outras continuam atualizando e notificando, e o polling não para. Testes `oneAccountFailingKeepsOthersFresh` e `unauthorizedAccountNotRefreshed` na Task 4, `ghAccountWithoutTokenIsNil` na Task 8.
5. **Terminal não abre (Ghostty ausente, AppleScript negado)**: o script com o token não pode ficar em disco. Testes `scriptRemovedWhenTerminalFails` e `scriptRemovedWhenRunnerThrows` na Task 14.

---

### Task 1: Modelo de conta e lista persistida

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Accounts/ProviderKind.swift`, `Accounts/Account.swift`, `Accounts/AccountList.swift`, `Accounts/AccountLabel.swift`, `Accounts/AccountConstants.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/AccountListTests.swift`

**Interfaces:**
- Consumes: `TokenOrigin` (`Auth/TokenSource.swift`)
- Produces:
  ```swift
  public enum ProviderKind: String, Codable, Sendable { case github }
  public struct Account: Codable, Equatable, Identifiable, Sendable {
      public let id: String
      public var provider: ProviderKind
      public var host: String
      public var login: String
      public var nickname: String
      public var origin: TokenOrigin
      public init(id: String, provider: ProviderKind = .github, host: String = AccountConstants.githubHost,
                  login: String, nickname: String = "", origin: TokenOrigin)
      public var displayName: String
      public func isSameIdentity(as other: Account) -> Bool
  }
  public struct AccountList: Codable, Equatable, Sendable {
      public var accounts: [Account]
      public init(accounts: [Account] = [])
      public static func decode(_ data: Data?) -> AccountList?
      public func encoded() -> Data
      @discardableResult public mutating func add(_ account: Account) -> Bool
      public mutating func remove(id: String)
      public mutating func rename(id: String, nickname: String)
      public mutating func updateLogin(id: String, login: String)
      public func account(id: String) -> Account?
  }
  public struct AccountLabel: Equatable, Sendable {
      public let provider: ProviderKind
      public let text: String
      public static func make(_ account: Account) -> AccountLabel
      public static func forRow(accountID: String, accounts: [Account]) -> AccountLabel?
  }
  enum AccountConstants { static let githubHost = "github.com"; static let gitlabHost = "gitlab.com"; static let publicHosts: Set<String> }
  ```
  - `displayName`: `nickname` vazio → `@<login>`; senão `<nickname> · @<login>`.
  - `isSameIdentity`: mesmo `provider`, `host` igual sem diferenciar maiúsculas, `login` igual sem diferenciar maiúsculas.
  - `add` devolve `false` e não muda a lista quando já existe conta com a mesma identidade.
  - `Account.init(from:)` com `decodeLossy`: `host` ausente → `github.com`, `nickname` → `""`, `origin` ausente ou desconhecido → `.pasted`. `provider` desconhecido faz o decode da conta falhar, e `AccountList` usa `decodeLossyArray`, então só aquela conta some.
  - `AccountList.decode(nil)` → `nil` (lista ainda não existe, usado pela migração). Dado inválido → `AccountList()`.
  - `AccountLabel.text`: `login`, mais ` · <host>` quando o host não está em `publicHosts` (`github.com`, `gitlab.com`). `forRow` devolve `nil` com `accounts.count <= 1` ou id desconhecido.

- [ ] **Step 1: Testes** `accountListRoundTrip`, `unknownProviderDropsOnlyThatAccount` (`[{"id":"a1","provider":"bitbucket","login":"x"},{"id":"a2","provider":"github","login":"adrianogl"}]` → só `a2`), `missingFieldsUseDefaults` (`{"accounts":[{"id":"a1","provider":"github","login":"adrianogl"}]}` → host `github.com`, nickname `""`, origin `.pasted`), `decodeNilMeansNoList`, `addRejectsSameIdentityIgnoringCase` (`AdrianoGL` depois de `adrianogl` → `false`, `count == 1`), `renameAndUpdateLogin`, `displayNameUsesNickname` (`"pessoal · @adrianogl"`; sem apelido `"@adrianogl"`), `labelNilWithOneAccount`, `labelOmitsPublicHost` (`"adriano-globex"`).
- [ ] **Step 2:** `swift test --filter AccountListTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): adiciona o modelo de conta e a lista de contas`

---

### Task 2: Conta nos PRs, eventos e worktrees

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Model/PullRequest.swift`, `Model/MergedPullRequest.swift`, `Model/Snapshot.swift`, `Transitions/NotificationEvent.swift`, `Transitions/TransitionEngine.swift`, `Reminders/StaleReviewTracker.swift`, `Polling/RefreshCoordinator.swift`, `Presentation/Counters.swift`, `Widget/WidgetSummary.swift`, `Organization/FilterContext.swift`, `Organization/RowFiltering.swift`, `Organization/RowOrdering.swift`, `Claude/WorktreeRecord.swift`, `PRumo/Views/Popover/PopoverView.swift`, `PRumo/Views/Popover/Filters/FilterPicker.swift`
- Test: `SnapshotStoreTests.swift`, `RefreshCoordinatorTests.swift`, `CountersTests.swift`, `WidgetSummaryTests.swift`, `RowOrderingTests.swift`, `WorktreeRegistryTests.swift`; `Support/PullRequest+Fixture.swift` ganha `accountID: String = ""`

**Interfaces:**
- Consumes: Task 1 (nada além do id de conta como `String`)
- Produces:
  - `PullRequest.accountID: String` (último parâmetro do `init`, default `""`; decode com `decodeIfPresent ?? ""`); `PullRequest.with(accountID: String) -> PullRequest`.
  - `MergedPullRequest.accountID: String` (default `""`, decode tolerante).
  - `NotificationEvent.accountID: String` (último parâmetro do `init`, default `""`). `TransitionEngine` e `StaleReviewTracker` passam `pr.accountID` em todo evento.
  - `Snapshot.accountViewers: [String: String]` (id da conta → login; `decodeLossyDictionary`, default `[:]`), parâmetro do `init` com default `[:]`.
  - `Snapshot.viewer(for pr: PullRequest) -> String`: `accountViewers[pr.accountID] ?? viewer`.
  - `Snapshot.stamped(accountID: String) -> Snapshot`: todos os PRs e mergeados com `accountID`, `accountViewers == [accountID: viewer]`.
  - `RefreshCoordinator.init(accountID: String = "", fetch:store:)`: carimba o snapshot novo com `stamped(accountID:)` antes do `keepingKnownMergeable` e do `TransitionEngine`. `public func lastSnapshot() async -> Snapshot?` (`lastKnown ?? store.load()`).
  - `Counters.readyToMerge` e `WidgetSummary.make` usam `snapshot.viewer(for:)`.
  - `FilterContext.init(viewer:viewers: [String: String] = [:], ...)`, `func viewer(for pr: PullRequest) -> String`; `RowFiltering` usa `context.viewer(for:)`.
  - `RowOrdering.sections(_:tab:ordering:marks:viewer: (PullRequest) -> String)`.
  - `WorktreeRecord.accountID: String?` (`decodeIfPresent`, nil em registros antigos); `registrable(pr:...)` grava `pr.accountID` quando não vazio.
  - App: `PopoverView` passa `snapshot.viewer(for:)` para `RowPresenter`, `MergeReadiness` e `RowOrdering`, e `viewers: snapshot.accountViewers` para o `FilterContext`. `FilterPicker` tira da lista de autores todos os logins de `accountViewers.values` e o `viewer`.

- [ ] **Step 1: Testes** `oldSnapshotJSONWithoutAccountDecodes` (JSON da etapa 7 → `accountID == ""`, `accountViewers == [:]`), `stampedSetsAccountOnEveryItem`, `viewerForUsesAccountMap` e `viewerForFallsBackToViewer`, `coordinatorStampsAccountOnPullRequestsAndEvents` (fetch fake devolve PR com CI terminando; evento sai com `accountID == "a2"`), `readyToMergeIgnoresOwnApprovalPerAccount` (snapshot com `accountViewers ["a1": "adrianogl", "a2": "adriano-globex"]`, PR de `a2` aprovado só por `adriano-globex` → `readyToMerge == 0`), `widgetSummaryUsesViewerOfEachAccount` (mesmo caso, `readyToMerge == 0`), `orderingNeedsActionUsesViewerClosure`, `worktreeRecordWithoutAccountDecodes`.
- [ ] **Step 2:** `swift test` → FAIL nos testes novos.
- [ ] **Step 3:** Implementar no kit e ajustar os call sites do app.
- [ ] **Step 4:** `swift test` → PASS; build do app → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat(kit): leva a conta nos prs, eventos e worktrees`

---

### Task 3: Combinar contas e dedupe

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Accounts/AccountPart.swift`, `Accounts/AccountMerge.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/AccountMergeTests.swift`

**Interfaces:**
- Consumes: `Snapshot.stamped`, `accountViewers`, `NotificationEvent.accountID` (Task 2)
- Produces:
  ```swift
  public struct AccountPart: Equatable, Sendable { public let accountID: String; public let snapshot: Snapshot; public init(accountID: String, snapshot: Snapshot) }
  public enum AccountMerge {
      public static func combine(_ parts: [AccountPart]) -> Snapshot?
      public static func events(_ perAccount: [(accountID: String, events: [NotificationEvent])], combined: Snapshot) -> [NotificationEvent]
  }
  ```
  `parts` vem na ordem da lista de contas. Regras do `combine` (spec, "Mesmo PR visível por duas contas"):
  1. `parts` vazio → `nil`.
  2. `mine`: concatena na ordem das contas e fica a primeira ocorrência de cada id.
  3. `toReview`: tira os ids que estão em `mine` (quem é autor numa conta fica em Meus PRs) e fica a primeira ocorrência na ordem das contas.
  4. `mergedToday`: primeira ocorrência por id.
  5. `viewer` = viewer da primeira parte; `accountViewers` = união dos mapas; `fetchedAt` = maior `fetchedAt`.

  `events`: mantém o evento quando o PR está no combinado e `event.accountID` é o `accountID` do PR que ficou; depois remove repetidos por `(kind, pullRequestID)`. Ordem: a das contas.

- [ ] **Step 1: Testes** `prAuthoredInOneAndRequestedInOtherStaysInMine` (A `mine [X]`, B `toReview [X]` → `mine.map(\.accountID) == ["A"]`, `toReview.isEmpty`), `reviewSeenByTwoAccountsBelongsToFirstInList` (A e B com `toReview [Y]`, ordem `[B, A]` → dono `B`), `reviewRequestedEventFromNonOwnerDropped` (B gera `.reviewRequested` para X → fora), `sameEventFromTwoAccountsDeliveredOnce`, `mergedTodayDeduplicated`, `singleAccountCombineKeepsContent`, `emptyPartsIsNil`, `widgetAndCounterSumCombined` (A com 1 review e 1 CI falhando, B com 2 reviews, um deles igual ao de A → `Counters.reviewBadge == 2`, `WidgetSummary.make(...).toReview == 2`, `ciFailing == 1`).
- [ ] **Step 2:** `swift test --filter AccountMergeTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): combina as contas sem duplicar pr nem notificação`

---

### Task 4: Refresh em paralelo e estado por conta

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Accounts/AccountStatus.swift`, `Accounts/AccountRefreshResult.swift`, `Accounts/AccountSchedule.swift`, `Polling/ParallelRefresh.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/ParallelRefreshTests.swift`

**Interfaces:**
- Consumes: `RefreshCoordinator(accountID:fetch:store:)`, `lastSnapshot()` (Task 2)
- Produces:
  ```swift
  public struct AccountStatus: Equatable, Sendable {
      public var state: ConnectionState?
      public var lastSuccess: Date?
      public var isProblem: Bool { get }
      public init(state: ConnectionState? = nil, lastSuccess: Date? = nil)
  }
  public struct AccountRefreshResult: Sendable { public let accountID: String; public let snapshot: Snapshot?; public let events: [NotificationEvent]; public let state: ConnectionState }
  public enum AccountSchedule { public static func shouldRefresh(_ state: ConnectionState?, now: Date) -> Bool }
  public enum ParallelRefresh {
      public static func run(_ sessions: [(accountID: String, coordinator: RefreshCoordinator)],
                             previous: [String: ConnectionState], options: TransitionOptions, now: Date) async -> [AccountRefreshResult]
  }
  ```
  - `isProblem`: `state` não nil e diferente de `.ok`.
  - `shouldRefresh`: `.unauthorized` → `false`; `.rateLimited(resetAt)` com `resetAt > now` → `false`; o resto → `true`. Intervalo é o global de hoje para todas as contas.
  - `run`: um `withTaskGroup` com uma tarefa por conta que deve atualizar; conta pulada devolve `lastSnapshot()`, eventos vazios e o estado anterior. Resultado na ordem de `sessions`.

- [ ] **Step 1: Testes** `oneAccountFailingKeepsOthersFresh` (A ok, B lança `.network` com snapshot salvo de 10:40 → A `.ok` com o snapshot novo; B `.offline(lastSuccess: 10:40)` com o snapshot salvo), `resultsKeepAccountOrder` (fetch de A mais lento que o de B), `runsConcurrently` (cada fetch espera o outro começar por um actor contador; sem paralelismo o teste trava e cai no timeout de 1 s), `rateLimitedAccountSkippedUntilReset` (fetch não é chamado antes do reset e é chamado depois), `unauthorizedAccountNotRefreshed`, `newAccountFirstRefreshHasNoEvents` (store vazio, snapshot com CI falhando e review pedido → `events.isEmpty`).
- [ ] **Step 2:** `swift test --filter ParallelRefreshTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): atualiza as contas em paralelo com estado por conta`

---

### Task 5: Linha de base de lembretes por conta

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Reminders/ReminderState.swift`, `Notifications/NotificationPipeline.swift`
- Test: `NotificationPipelineTests.swift`

**Interfaces:**
- Consumes: `snapshot.accountViewers`, `NotificationEvent.accountID` (Task 2)
- Produces: `ReminderState.baselined: [String]` (`decodeLossy`, default `[]`; `viewer` continua sendo lido, só para a migração da Task 6).

Nova regra 3 do `NotificationPipeline.run`, no lugar da comparação de `viewer`:
- contas = chaves de `snapshot.accountViewers`, ou `[""]` quando vazio;
- lembretes devidos de PR cuja conta não está em `baselined` são marcados em `reminded` e não entregues, mesmo fora do silêncio;
- `baselined` passa a ser exatamente as contas do snapshot (conta removida sai; se voltar, ganha linha de base de novo) e `initialized` vira `true`.
As regras 4 e 5 (silêncio adia, tipo desligado marca sem entregar) valem só para contas já em `baselined`. Os testes da etapa 5 que trocavam `viewer` passam a trocar o `accountID`.

- [ ] **Step 1: Testes** `newAccountStaleReviewsBaselinedSilently` (`baselined ["A"]`; snapshot com A e B, os dois com review parado → só o de A entregue, as duas chaves marcadas, `baselined == ["A", "B"]`), `removedAccountLeavesBaseline` (B some do snapshot → sai de `baselined`; volta → silencioso de novo), `legacyStateWithoutBaselinedDecodes` (`{"initialized":true,"reminded":["x"],"viewer":"adrianogl"}` → `baselined == []`, `reminded == ["x"]`), `quietStillPostponesForBaselinedAccounts`.
- [ ] **Step 2:** `swift test --filter NotificationPipelineTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): faz a linha de base dos lembretes por conta`

---

### Task 6: Migração da conta atual

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Accounts/LegacyAccountState.swift`, `Accounts/AccountMigration.swift`, `Accounts/AccountStorage.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/AccountMigrationTests.swift`

**Interfaces:**
- Consumes: `AccountList` (Task 1), `ReminderState.baselined` (Task 5), `RefreshCoordinator(accountID:)` (Task 2)
- Produces:
  ```swift
  public struct LegacyAccountState: Equatable, Sendable { public let login: String?; public let origin: TokenOrigin?; public let onboardingDone: Bool }
  public enum AccountMigration {
      public static let legacyAccountID = "github-legacy"
      public static func account(from legacy: LegacyAccountState, existing: AccountList?) -> Account?
      public static func reminders(_ state: ReminderState, migrated: Account) -> ReminderState
  }
  public enum AccountStorage {
      public static func keychainAccount(for accountID: String) -> String
      public static func snapshotURL(for accountID: String) -> URL
  }
  ```
  - A conta migrada usa o id fixo `github-legacy`, e o `AccountStorage` mapeia esse id para os nomes de hoje: item do Keychain `github-token` e arquivo `~/Library/Application Support/PRumo/snapshot.json`. A migração não copia token nem move arquivo; só grava a lista. Contas novas: Keychain `token-<id>` e `Application Support/PRumo/snapshots/<id>.json`, com `id` = `UUID().uuidString`.
  - `account(from:existing:)`: `nil` quando `existing != nil` ou `onboardingDone == false`. Senão `Account(id: "github-legacy", login: legacy.login ?? "", origin: legacy.origin ?? .pasted)`. Login vazio é preenchido no primeiro refresh (`AccountList.updateLogin`).
  - `reminders`: `initialized && (viewer == nil || viewer == login)` → `baselined = ["github-legacy"]`; senão devolve o estado sem mudar (a Task 5 refaz a base em silêncio).

- [ ] **Step 1: Testes** `migratesOnboardedLegacyAccount` (login `adrianogl`, origin `.ghCLI` → conta `github-legacy`, `github.com`, `.ghCLI`), `noMigrationWhenListExists`, `noMigrationBeforeOnboarding`, `legacyAccountKeepsLegacyStorageNames` (`keychainAccount(for: "github-legacy") == "github-token"`, `snapshotURL(for: "github-legacy") == SnapshotStore.defaultURL()`; outro id → `token-<id>` e `snapshots/<id>.json`), `remindersBaselinedForMigratedAccount`, `migratedFirstRefreshProducesNoEvents` (snapshot salvo da etapa 7, sem `accountID`; coordinator `accountID: "github-legacy"` com fetch devolvendo o mesmo conteúdo → `events.isEmpty` e PRs com `accountID == "github-legacy"`).
- [ ] **Step 2:** `swift test --filter AccountMigrationTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): migra a conta atual sem mexer no token nem no snapshot`

---

### Task 7: Detecção de várias contas do `gh`

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Auth/GhAccount.swift`, `Auth/GhHostsFile.swift`, `Auth/GhAccountDiscovery.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/GhAccountDiscoveryTests.swift`, `Fixtures/gh-hosts-multi.yml`, `Fixtures/gh-hosts-legacy.yml`

**Interfaces:**
- Consumes: `ProcessRunner`
- Produces:
  ```swift
  public struct GhAccount: Equatable, Sendable { public let host: String; public let login: String; public let isActive: Bool }
  public enum GhHostsFile { public static func accounts(fromYAML text: String) -> [GhAccount] }
  public struct GhAccountDiscovery: Sendable {
      public init(runner: ProcessRunner, environment: [String: String], home: URL,
                  readFile: @escaping @Sendable (URL) -> String?,
                  candidatePaths: [String] = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"],
                  fileExists: @escaping @Sendable (String) -> Bool)
      public func accounts() async -> [GhAccount]
      public func activeLogin() async -> String?
      public func token(for login: String) async -> String?
  }
  ```
  - Arquivo: `$GH_CONFIG_DIR/hosts.yml`, senão `$XDG_CONFIG_HOME/gh/hosts.yml`, senão `~/.config/gh/hosts.yml`.
  - Parser mínimo de YAML: chave de host sem indentação; dentro dela, `user: <login>` é a conta ativa e o bloco `users:` lista as contas (cada login é uma chave um nível abaixo). Formato antigo sem `users:` → uma conta, a de `user:`. Só o host `github.com` entra.
  - `token(for:)`: login fora de `^[A-Za-z0-9-]+$` → `nil` sem rodar nada. Roda `gh auth token --hostname github.com --user <login>`; status ≠ 0 e `login` é o ativo → `gh auth token --hostname github.com`; senão `nil`. Saída vazia → `nil`.
  - Sem binário do `gh` → `accounts()` lê só o arquivo e `token(for:)` devolve `nil`.

- [ ] **Step 1: Testes** `parsesMultipleUsersAndActive` (`adrianogl` ativo, `adriano-globex` não), `parsesLegacySingleUserFormat`, `ignoresOtherHosts` (`github.acme.com` fora), `configDirRespectsGhConfigDir`, `tokenUsesUserFlag` (runner fake confere `["auth", "token", "--hostname", "github.com", "--user", "adriano-globex"]`), `tokenFallsBackToActiveWhenUserFlagUnsupported`, `tokenNilForInactiveWhenUserFlagFails`, `unsafeLoginNeverRuns` (`"x; rm -rf ~"` → `nil`, runner sem chamadas), `noGhBinaryReturnsNoToken`.
- [ ] **Step 2:** `swift test --filter GhAccountDiscoveryTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): detecta as contas logadas no gh`

---

### Task 8: Token e cliente por conta

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Accounts/AccountClient.swift`, `Accounts/AccountTokenResolver.swift`, `GitHub/GitHubClient+AccountClient.swift`
- Modify: `PRumoKit/Sources/PRumoKit/GitHub/GitHubClient.swift`, `GitHub/Queries.swift`
- Test: `GitHubClientTests.swift`, `PRumoKit/Tests/PRumoKitTests/AccountTokenResolverTests.swift`

**Interfaces:**
- Consumes: `GhAccountDiscovery.token(for:)` (Task 7), `TokenStore`, `Account` (Task 1)
- Produces:
  ```swift
  public protocol AccountClient: Sendable {
      func fetchSnapshot() async throws(GitHubError) -> Snapshot
      func pullRequestStates(ids: [String]) async throws(GitHubError) -> [String: PRState]
      func rerunFailedJobs(pr: PullRequest) async throws(GitHubError)
  }
  extension GitHubClient: AccountClient
  public func viewerLogin() async throws(GitHubError) -> String
  public struct AccountTokenResolver: Sendable {
      public init(tokenStore: @escaping @Sendable (String) -> TokenStore, gh: GhAccountDiscovery)
      public func token(for account: Account) async -> String?
  }
  ```
  - `Queries.viewer = "query { viewer { login } }"`. `viewerLogin` valida o token em "Adicionar conta" sem buscar o snapshot inteiro.
  - `rerunFailedJobs(pr:)`: `pr.failedRunID` nil → `.unexpectedResponse`; senão chama o `rerunFailedJobs(repository:runID:)` de hoje.
  - `token(for:)`: `.pasted` → `tokenStore(account.id).read()`; `.ghCLI` → `gh.token(for: account.login)`. Vazio → `nil`.

- [ ] **Step 1: Testes** `viewerLoginParsesLogin`, `viewerLogin401IsUnauthorized`, `rerunUsesFailedRunOfPR` (transport fake confere a URL `.../repos/acme/loja/actions/runs/42/rerun-failed-jobs`), `rerunWithoutRunIsUnexpected`, `pastedAccountReadsOwnKeychainItem` (factory fake recebe `"a2"`), `ghAccountAsksGhForThatUser`, `ghAccountWithoutTokenIsNil`.
- [ ] **Step 2:** `swift test --filter "GitHubClientTests|AccountTokenResolverTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): resolve token e cliente por conta`

---

### Task 9: Sessões por conta no app

**Files:**
- Create: `PRumo/Services/AccountsStore.swift`, `PRumo/Services/AccountSession.swift`
- Modify: `PRumo/AppModel.swift`, `PRumo/AppConstants.swift`, `PRumo/Services/KeychainTokenStore.swift`, `PRumo/Views/Onboarding/OnboardingModel.swift`, `PRumo/Views/MenuBarLabel.swift`

**Interfaces:**
- Consumes: Tasks 1 a 8
- Produces:
  - `KeychainTokenStore.init(account: String = AppConstants.keychainAccount)`; o app cria por conta com `KeychainTokenStore(account: AccountStorage.keychainAccount(for: id))`.
  - `@Observable @MainActor final class AccountsStore { var list: AccountList; var statuses: [String: AccountStatus]; init(defaults: UserDefaults); func save() }`, persistido em `AppConstants.accountsKey = "accounts"`.
  - `struct AccountSession: Sendable { let account: Account; let token: String; let client: any AccountClient; let coordinator: RefreshCoordinator }`.
  - `AppModel`: `let accounts: AccountsStore`; `snapshot` vira o combinado; `func addAccount(_ account: Account, token: String) throws`, `func removeAccount(id: String)`, `func reconnect(id: String)`, `func renameAccount(id: String, nickname: String)`, `func session(for pr: PullRequest) -> AccountSession?`, `func accountLabel(for pr: PullRequest) -> AccountLabel?`.

Comportamento:
- `start()`: aplica a migração da Task 6 uma vez (`AccountMigration.account` com `accountLogin`, `tokenOrigin` e `onboardingDone` do UserDefaults; grava a lista e o `ReminderState` migrado); lista vazia → onboarding. Para cada conta: token pelo `AccountTokenResolver` (com as 3 tentativas de hoje para `.ghCLI`), `GitHubClient`, `RefreshCoordinator(accountID:fetch:store: SnapshotStore(fileURL: AccountStorage.snapshotURL(for:)))`. Conta sem token entra com `AccountStatus(state: .unauthorized)` e sem sessão.
- `runRefresh`: `ParallelRefresh.run` → `accounts.statuses`; `AccountMerge.combine` das partes com snapshot → `snapshot`; `AccountMerge.events` → eventos; login de cada conta atualizado quando o `viewer` muda. O resto (atividade, repositórios, worktrees, marcas, widget, pipeline de notificações) segue igual com o combinado. O polling para só quando todas as contas estão `.unauthorized`.
- `connection`: com uma conta, o estado dela (banner e onboarding de hoje); com mais de uma, `.ok` (o aviso é por conta, Task 11).
- `connect(token:origin:login:)` do onboarding cria a primeira conta com id novo e grava o token em `token-<id>` quando `.pasted`.
- `removeAccount`: apaga o item do Keychain e o snapshot da conta, tira a sessão e recombina; última conta removida → caminho do `signOut` de hoje.
- `rerunFailedJobs`, limpeza de worktrees e poda de marcas usam o cliente da conta: worktree pelo `record.accountID ?? <primeira conta GitHub>`; marcas consultam todas as sessões e unem os estados.
- `signOut` apaga os tokens e snapshots de todas as contas e a lista.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Com o app da etapa 7 instalado e uma conta em uso, rodar o build novo: a lista é a mesma, nenhuma notificação, fixados e silenciados no lugar, `defaults read dev.aglv.prumo accounts` mostra a conta `github-legacy`.
- [ ] **Step 4: Commit** `feat(app): atualiza várias contas em paralelo`

---

### Task 10: Aba Contas e janela "Adicionar conta"

**Files:**
- Create: `PRumo/Views/Settings/AccountsSettingsView.swift`, `AccountRowView.swift`, `AddAccountSheet.swift`, `AddAccountModel.swift`, `AccountsSettingsConstants.swift`
- Modify: `PRumo/Views/Settings/SettingsView.swift`, `SettingsConstants.swift` (sai `account` e os textos da aba Conta; `SettingsTab.accounts`), `PRumo/Views/Onboarding/OnboardingView.swift`, `OnboardingConstants.swift`

**Interfaces:**
- Consumes: `AppModel.addAccount/removeAccount/reconnect/renameAccount`, `AccountsStore` (Task 9), `GhAccountDiscovery` (Task 7), `GitHubClient.viewerLogin()` (Task 8)
- Produces: `@Observable @MainActor final class AddAccountModel { var detected: [GhAccount]; var tokenInput: String; var nickname: String; var errorMessage: String?; var isValidating: Bool; func detect() async; func use(_ account: GhAccount) async; func connectPasted() async -> Bool }`

Aba `Contas` (primeira aba, símbolo `person.2`), mockup parte 2:
- Uma linha por conta: ícone do provedor, `displayName` em negrito, embaixo `<host> · <origem>` (`token do GitHub CLI` / `token pessoal no Keychain`), estado à direita e menu `⋯`.
- Estado: `conectada` (bolinha verde); `conectando…` (cinza, sem estado ainda); `sem acesso` (laranja; `sem acesso (VPN?)` quando o host não é público) com botão `Tentar de novo`; `token inválido` (vermelho) com botão `Reconectar`; `limite da API até HH:mm` (laranja); `resposta inesperada` (laranja).
- Menu `⋯`: `Reconectar`, `Renomear…` (alerta com campo `Apelido`), `Remover…` (alerta `Remover <displayName>?`, texto `Os PRs dessa conta saem da lista e o token é apagado do Keychain.`, botões `Remover` destrutivo e `Cancelar`).
- Botão `Adicionar conta…` abre a folha.

Folha `Adicionar conta` (mockup parte 2, só GitHub nesta etapa, sem o seletor de provedor):
- Contas do `gh` ainda não adicionadas (`isSameIdentity`): `Encontrei no gh: @<login> em github.com` com botão `Usar`.
- `ou com um token pessoal:`; campo seguro `Token pessoal (escopos repo e read:org)`; link `Criar token no GitHub` (`AppConstants.tokenCreationURL`); campo `Apelido` opcional.
- Botões `Cancelar` e `Conectar` (padrão; desabilitado com token vazio ou validando).
- `Conectar` valida com `viewerLogin()`. Erros: conta repetida `Essa conta já está na lista.`; 401 `Token inválido ou sem os escopos repo e read:org.`; rede `Sem conexão com o GitHub.`; Keychain `Não deu para guardar o token no Keychain.`.
- `Reconectar` em conta `.pasted` abre a folha só com o campo de token; token de outro login → `Esse token é de @<x>, não de @<y>.`. Em conta `.ghCLI`, pede o token ao `gh` de novo e reinicia a sessão.

Onboarding: a tela "Tudo pronto" ganha a linha `Para acompanhar outras contas, use Ajustes › Contas.`.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Rodar o app: adicionar a segunda conta pelo `gh` (com `gh auth login` de outra conta antes) e uma por token; renomear; remover e conferir que os PRs dela saem e `security find-generic-password -s dev.aglv.prumo -a token-<id>` não acha mais o item.
- [ ] **Step 4: Commit** `feat(app): adiciona a aba contas e a janela de adicionar conta`

---

### Task 11: Conta na linha e aviso por conta no popover

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Presentation/RowPresentation.swift`, `Presentation/PresentationConstants.swift`, `PRumo/Views/Popover/PRRowView.swift`, `PopoverView.swift`, `PopoverConstants.swift`, `MergedRowView.swift`
- Create: `PRumo/Views/Popover/AccountProblemBanner.swift`, `PRumo/Resources/Assets.xcassets/ProviderGitHub.imageset/` (SVG `github` do Simple Icons, CC0, "Render As: Template")
- Test: `RowPresentationTests.swift`

**Interfaces:**
- Consumes: `AccountLabel.forRow` (Task 1), `AccountStatus` (Task 4), `AppModel.accountLabel(for:)` (Task 9)
- Produces:
  - `RowPresenter.mine/review/merge(..., account: AccountLabel? = nil, staleSince: Date? = nil)` e `compactLine(..., account: AccountLabel? = nil)`.
  - `RowPresentation.accountProvider: ProviderKind?`.
  - Subtítulo com conta: `<label.text> · <repo> #<n> · <idade>`. Com `staleSince`: a idade vira `último dado <RelativeAge> atrás`. Linha compacta com conta: o `label.text` entra como primeira parte.

App:
- A linha recebe o label só com mais de uma conta (`AccountLabel.forRow`). Com `accountProvider`, o ícone `ProviderGitHub` (11 pt, secundário) vem antes do texto do subtítulo.
- Itens de conta com `isProblem` ficam com opacidade `PopoverMetrics.staleAccountOpacity = 0.55` e recebem `staleSince: status.lastSuccess`.
- Com mais de uma conta, o `StatusBanner` dá lugar a um `AccountProblemBanner` por conta com problema, mesmo estilo laranja (mockup parte 3), com nome = `nickname` ou `@login`:
  - offline: `<nome> (<host>) sem acesso há <RelativeAge>. Os outros PRs continuam atualizando.` + botão `Ajustes`;
  - 401: `<nome> (<host>) com token inválido. Os outros PRs continuam atualizando.` + botão `Reconectar` (abre Ajustes › Contas);
  - rate limit: `<nome> (<host>) no limite da API até HH:mm.`;
  - resposta inesperada: `<nome> (<host>) respondeu de um jeito inesperado. Mostrando o último dado.`.
- Com uma conta, nada muda.

- [ ] **Step 1: Testes** `subtitleWithoutAccountUnchanged`, `subtitleWithAccountPrefix` (`"adrianogl · acme/loja #812 · 2h"`), `staleAccountShowsLastData` (`"acme/loja #812 · último dado 12min atrás"`), `compactLineWithAccount`, `providerSetOnlyWithAccount`.
- [ ] **Step 2:** `swift test --filter RowPresentationTests` → FAIL.
- [ ] **Step 3:** Implementar o kit; `swift test` → PASS.
- [ ] **Step 4:** Implementar o app; build → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 5:** Rodar o app com duas contas e trocar o token de uma por um inválido no Keychain: banner só dela, linhas dela esmaecidas, a outra conta segue atualizando.
- [ ] **Step 6: Commit** `feat: mostra a conta na linha e o aviso por conta`

---

### Task 12: Conta no subtítulo das notificações

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Accounts/NotificationSubtitles.swift`
- Modify: `PRumo/Services/NotificationService.swift`, `PRumo/AppModel.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/NotificationSubtitlesTests.swift`

**Interfaces:**
- Consumes: `AccountLabel.make` (Task 1), `NotificationEvent.accountID` (Task 2)
- Produces: `public enum NotificationSubtitles { public static func make(accounts: [Account]) -> [String: String] }`: `[:]` com uma conta; senão id → `AccountLabel.make(conta).text`. `NotificationService.post(_:grouped:subtitles: [String: String])` grava `content.subtitle = subtitles[event.accountID] ?? ""`.

- [ ] **Step 1: Testes** `subtitlesEmptyWithOneAccount`, `subtitlesUseLabel` (`["a2": "adriano-globex"]`).
- [ ] **Step 2:** `swift test --filter NotificationSubtitlesTests` → FAIL.
- [ ] **Step 3:** Implementar no kit e no app.
- [ ] **Step 4:** `swift test` → PASS; build → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat: põe a conta no subtítulo das notificações`

---

### Task 13: Filtro de repositórios por conta

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Organization/RepositoryCatalog.swift`, `Organization/RepositoryGroup.swift`, `Organization/OrganizationSettings.swift`, `PRumo/Services/OrganizationStore.swift`, `PRumo/Views/Popover/Filters/RepositoryPicker.swift`, `Filters/FiltersConstants.swift`
- Test: `RepositoryCatalogTests.swift`, `OrganizationSettingsTests.swift`

**Interfaces:**
- Consumes: `Account` (Task 1), `PullRequest.accountID` (Task 2)
- Produces:
  - `RepositoryGroup.section: String?` (init com default `nil`).
  - `OrganizationSettings.repositoryAccounts: [String: String]` (repositório → id da conta; `decodeLossyDictionary`, default `[:]`).
  - `RepositoryCatalog.groups(snapshot:known:favorites:hideEmpty:search:accounts: [Account] = [], repositoryAccounts: [String: String] = [:])`.
  - `OrganizationStore.learnRepositories(from:)` grava `repositoryAccounts[pr.repository] = pr.accountID` para PRs com conta.

Regras com `accounts.count > 1`: favoritos no topo como hoje; depois, para cada conta na ordem da lista, os grupos por org dela com `section = account.displayName`. A conta do repositório é a do primeiro PR dele no snapshot; sem PR, `repositoryAccounts[repo]`; sem nada, a primeira conta. Cada repositório aparece em um grupo só. Com uma conta, saída igual à de hoje.

App: `RepositoryPicker` mostra a `section` como cabeçalho (13 pt, semibold) quando ela muda entre grupos; `ForEach` com id `"\(section ?? "")/\(title)"`.

- [ ] **Step 1: Testes** `singleAccountGroupsUnchanged`, `groupsByAccountThenOrg` (A: `acme/web`, `acme/api`; B: `globex/portal` → seção A com `ACME`, seção B com `GLOBEX`), `knownRepoWithoutPRsUsesLearnedAccount`, `repoVisibleByTwoAccountsListedOnce`, `favoritesStayOnTop`, `oldOrganizationJSONWithoutRepositoryAccountsDecodes`.
- [ ] **Step 2:** `swift test --filter "RepositoryCatalogTests|OrganizationSettingsTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS; build → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat: agrupa o filtro de repositórios por conta`

---

### Task 14: `GH_TOKEN` na sessão do Claude

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Accounts/SessionEnvironment.swift`
- Modify: `PRumoKit/Sources/PRumoKit/Claude/TerminalCommand.swift`, `Claude/ClaudeLauncher.swift`, `PRumo/AppModel.swift`
- Test: `TerminalCommandTests.swift`, `ClaudeLauncherTests.swift`

**Interfaces:**
- Consumes: `AppModel.session(for:)` (Task 9)
- Produces:
  - `public enum SessionEnvironment { public static func variables(provider: ProviderKind, host: String, token: String) -> [String: String] }`: GitHub → `["GH_TOKEN": token]`.
  - `TerminalCommand.scriptContents(directory:prompt:extraFlags:claudeExecutable:environment: [String: String] = [:], scriptPath: URL? = nil)`. Com `scriptPath`, a primeira linha é `rm -f -- <ShellQuote.single(path)>`. Depois, uma linha `export <NOME>=<ShellQuote.single(valor)>` por variável, em ordem de nome; nome fora de `^[A-Z_][A-Z0-9_]*$` é ignorado. O resto do script não muda.
  - `ClaudeLauncher.launch(pr:purpose:environment: [String: String] = [:])`; `init` ganha `removeScript: @escaping @Sendable (URL) -> Void` (default remove o arquivo). Se o terminal sai com status ≠ 0 ou o runner lança erro depois do script gravado, o launcher chama `removeScript`.
  - `AppModel.runLaunch` passa `SessionEnvironment.variables(...)` com o token da sessão dona do PR; sem sessão, ambiente vazio.

- [ ] **Step 1: Testes** `scriptDeletesItselfFirst` (primeira linha `rm -f -- '/tmp/s/abc.zsh'`), `tokenExportedQuoted` (token `ab'c` → `export GH_TOKEN='ab'\''c'`), `invalidEnvNameSkipped` (`"GH TOKEN"`), `tokenNeverInLaunchArguments` (para `.ghostty`, `.terminal`, `.iterm` e `.custom`, nenhum argumento contém o token), `launcherWritesTokenToScript`, `scriptRemovedWhenTerminalFails`, `scriptRemovedWhenRunnerThrows`, `githubEnvironmentHasGhToken`.
- [ ] **Step 2:** `swift test --filter "TerminalCommandTests|ClaudeLauncherTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS; build → `BUILD SUCCEEDED`.
- [ ] **Step 5:** Rodar "Revisar com Claude" num PR da conta que não é a ativa do `gh`: no terminal, `gh api user -q .login` mostra a conta do PR, `gh auth status` continua com a ativa de antes e `ls ~/Library/Caches/PRumo/sessions/` não lista o script.
- [ ] **Step 6: Commit** `feat: passa o token da conta do pr para a sessão do claude`

---

### Task 15: Aviso no checkout quando a conta não é a ativa

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Accounts/CheckoutWarning.swift`
- Modify: `PRumoKit/Sources/PRumoKit/Presentation/RowMenuEntry.swift`, `Presentation/RowMenuPlan.swift`, `PRumo/Views/Popover/RowMenuItems.swift`, `RowMenuNSMenu.swift`, `RowMenuEntry+Presentation.swift`, `PRRowView.swift`, `PRumo/AppModel.swift`
- Test: `RowMenuPlanTests.swift`, `PRumoKit/Tests/PRumoKitTests/CheckoutWarningTests.swift`

**Interfaces:**
- Consumes: `GhAccountDiscovery.activeLogin()` (Task 7), `Account` (Task 1)
- Produces:
  - `RowMenuEntry.copyCheckout(command: String, warning: String?)`.
  - `RowMenuPlan.entries(pr:claudePurposes:jira:isPinned:isMuted:checkoutWarning: String? = nil)`.
  - `public enum CheckoutWarning { public static func text(account: Account?, activeLogin: String?, accountCount: Int) -> String? }`:
    - `nil` com `accountCount <= 1`, conta nil ou `activeLogin` igual ao login (sem diferenciar maiúsculas);
    - `activeLogin == nil` → `O gh não está logado. Rode gh auth login antes de colar o comando.`;
    - senão → `A conta ativa do gh é @<ativo>. Rode gh auth switch --user <login> antes de colar o comando.`.
  - `RowMenuEntry.help: String?` (app) devolve o `warning`; `RowMenuItems` aplica `.help`, `RowMenuNSMenu` grava `toolTip`. O texto do item continua `Copiar gh pr checkout <n>`.
  - `AppModel.ghActiveLogin: String?`, lido no `start()` e de novo a cada abertura do popover, no máximo uma vez por minuto.

- [ ] **Step 1: Testes** `noWarningWithOneAccount`, `noWarningWhenActive`, `warningNamesSwitchCommand`, `warningWhenGhNotLogged`, `planCarriesWarning`.
- [ ] **Step 2:** `swift test --filter "RowMenuPlanTests|CheckoutWarningTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS; build → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat: avisa no checkout quando a conta do pr não é a ativa do gh`

---

### Task 16: Verificação ponta a ponta

- [ ] **Step 1:** `swift test` → todos PASS. `xcodegen generate && xcodebuild clean build` → `BUILD SUCCEEDED`, zero warnings do projeto.
- [ ] **Step 2 (usuário):** atualizar sobre a etapa 7 com uma conta: nada notifica, a linha não mostra conta, Ajustes › Contas mostra a conta com a origem certa.
- [ ] **Step 3 (usuário):** adicionar a conta do trabalho pelo `gh`: nada notifica na primeira leitura; as linhas mostram `adrianogl` ou `adriano-globex`; o contador da barra e o widget somam as duas.
- [ ] **Step 4 (usuário):** um PR seu na conta pessoal com review pedido à conta do trabalho aparece uma vez, em Meus PRs.
- [ ] **Step 5 (usuário):** derrubar uma conta (token inválido): banner só dela, itens esmaecidos com `último dado … atrás`, a outra segue notificando.
- [ ] **Step 6 (usuário):** comentário novo num PR da segunda conta → notificação com o login no subtítulo.

---

## Self-review

1. **Cobertura da spec (etapa 1):** modelo de conta (Task 1), Keychain por conta (Tasks 6 e 9), migração (Tasks 5, 6 e 9), várias contas do GitHub com `gh` e token (Tasks 7, 8 e 10), aba Contas (Task 10), conta na linha só com mais de uma (Task 11), refresh em paralelo e estado por conta (Tasks 4 e 9), aviso por conta (Task 11), dedupe (Task 3), notificações (Task 12), filtro de repositórios (Task 13), widget e contador (Task 3, teste `widgetAndCounterSumCombined`, e Task 9), onboarding (Task 10), `GH_TOKEN` e script apagado (Task 14), aviso no checkout (Task 15). Remover conta apaga token e itens (Tasks 9 e 10). GitLab fica na etapa 9.
2. **Passos:** cada passo de teste lista nomes e valores; passos de código dão assinatura, arquivo e regra. Sem corpo de função que a assinatura e o teste já definem.
3. **Tipos:** `accountID: String` em `PullRequest`, `MergedPullRequest`, `NotificationEvent` e `WorktreeRecord?`; `AccountStatus.state: ConnectionState?` usado igual nas Tasks 4, 9, 10 e 11; `AccountLabel.forRow` (Task 1) usado nas Tasks 11 e 12; `AccountStorage` (Task 6) usado na Task 9.
4. **Review Focus:** os cinco itens têm teste na task dona (Tasks 3, 4, 5, 6, 8 e 14).
5. **Proporção:** só interfaces e regras; o único bloco de código por task é o de assinaturas.
