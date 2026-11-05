# PRumo: Etapa 4 (Organização) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Organizar o popover: aba Merge com "Mergeados hoje", barra de repositórios, filtros e ordem com visões salvas, linha compacta, fixar e silenciar, drafts e reviews do time em Revisar e o marcador de atividade nova.

**Architecture:** Regras (pronto para merge, filtros, ordem, agrupamento, catálogo de repositórios, atividade nova, inclusão de reviews) ficam no `PRumoKit` como funções puras testadas. O estado do usuário (filtros, ordem por aba, visões, favoritos, fixados, silenciados, estilo de linha) vira um `OrganizationSettings` Codable guardado pelo app no UserDefaults. A query de review passa a `review-requested:@me` e o snapshot ganha `mergedToday`.

**Tech Stack:** Swift 6.4, SwiftUI, Swift Testing, GraphQL do GitHub.

**Spec:** `docs/superpowers/specs/2026-11-05-prumo-design.md`, seções "Popover", "Linha de PR", "Como o app sabe o que mudou" (drafts, pronto para merge, reviews do time, atividade nova) e "Ajustes › Filtros". Mockups: `docs/mockups/filtros.html` (barra, repositórios, filtros, ordem, agrupado) e `docs/mockups/visao-geral.html` (aba Merge, Revisar com para você/time).

**Base:** `main`, depois da etapa 3 (usa `RowMenuEntry`, `RowMenuPlan` e `AppModel.perform(_:on:)`). Commits direto na `main`.

## Global Constraints

- macOS 26 mínimo. Pacote SwiftPM `PRumoKit` + app `PRumo` gerado pelo XcodeGen (`project.yml`).
- Sem comentários no código.
- Kit: um tipo por arquivo. App: textos, medidas e símbolos em enums `XxxText`/`XxxMetrics`/`XxxSymbol` no `XxxConstants.swift` da pasta; nada de constante ou type solto dentro de view.
- Copy da interface em PT-BR, exatamente como escrita neste plano.
- Identidade da spec: caramelo `#a5713a` (`Color.prumoCaramel`) para contadores, seleção, bolinha de "novo" e alfinete; cores de status do sistema; SF Symbols monocromáticos (fixado = `pin.fill`, silenciado = `pause.fill`); nada de emoji.
- Assinatura ad-hoc (`CODE_SIGN_IDENTITY: "-"`), app sem sandbox.
- Commits direto na `main`, Conventional Commits em PT-BR (minúsculas, imperativo, sem ponto final), sem `Co-Authored-By` e sem menção a IA.
- Kit em TDD com Swift Testing (`@Test`, `#expect`): `cd PRumoKit && swift test`.
- Build do app: `xcodegen generate && xcodebuild -project PRumo.xcodeproj -scheme PRumo -destination 'platform=macOS' build` → `** BUILD SUCCEEDED **`, zero warnings do projeto.
- Testes nunca rodam `git`, `gh` ou `osascript` reais nem chamam a API do GitHub: usar `ProcessRunner` e `HTTPTransport` fakes.
- Tudo que é persistido (snapshot em disco, JSON no UserDefaults) decodifica versões antigas: campo novo com `decodeIfPresent` e default, com teste usando JSON sem o campo.
- Pronto para merge: não é draft, `mergeable == MERGEABLE`, CI em sucesso ou sem checks, e aprovação: `reviewDecision == APPROVED`, ou `reviewDecision == null` (sem branch protection) com ao menos uma aprovação e nenhuma alteração pedida pendente.
- Padrões: "Ignorar drafts em Revisar" ligado; "Incluir reviews pedidos ao time" ligado; linha detalhada; ordem "Atividade recente" em todas as abas.
- Reviews pedidos ao time: com a opção ligada (padrão), valem como pedido a você: aparecem em Revisar com o badge do time, notificam, entram no contador da barra de menu e recebem lembrete de review parado (etapa 5). Desligada, o time some de tudo.

## Review Focus

1. **PR some da busca por SSO expirado**: fixado e silenciado não podem se perder. Esperado: marcação só sai quando `pullRequestStates` confirma `CLOSED` ou `MERGED`. Teste na Task 10.
2. **Review pedido a você e ao seu time no mesmo PR**: conta como "para você", notifica e entra no contador. Teste na Task 1.
3. **Draft em Revisar que vira pronto para review** com "Ignorar drafts" ligado: notifica uma vez, mesmo com o pedido antigo. Teste na Task 4.
4. **Popover aberto na virada do dia**: "Mergeados hoje" não mostra os de ontem, mesmo antes do próximo refresh. Teste na Task 2.
5. **`mergeable == UNKNOWN`** (GitHub ainda calculando depois de um push): o PR não entra na aba Merge. Teste na Task 3.

---

### Task 1: Reviews pedidos ao time e decisão de review

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Model/ReviewRequestTarget.swift`, `Model/ReviewDecision.swift`
- Modify: `GitHub/Queries.swift`, `GitHub/GraphQLResponse.swift`, `GitHub/PullRequestMapper.swift`, `Model/PullRequest.swift`, fixture `search-review.json` (um PR pedido só ao time `backend`, um pedido a você e ao time), `Support/PullRequest+Fixture.swift`
- Test: `PullRequestMapperTests.swift`, `SnapshotStoreTests.swift`

**Interfaces:**
- Produces:
  - `public enum ReviewRequestTarget: Codable, Equatable, Sendable { case you; case team(name: String) }`
  - `public enum ReviewDecision: String, Codable, Sendable { case approved = "APPROVED", changesRequested = "CHANGES_REQUESTED", reviewRequired = "REVIEW_REQUIRED" }`
  - Em `PullRequest`: `reviewTarget: ReviewRequestTarget` (default `.you`) e `reviewDecision: ReviewDecision?` (default `nil`), no fim do `init` e com `decodeIfPresent`.
  - `Queries.review = "is:pr is:open review-requested:@me archived:false"`.

A query pede `reviewDecision`, `reviewRequests(first: 20) { nodes { requestedReviewer { __typename ... on User { login } ... on Team { name } } } }` e, no `ReviewRequestedEvent`, `requestedReviewer { ... on User { login } ... on Team { name } }`.

Mapeamento só para a lista de review: algum pedido para `User` com login do viewer → `.you`; senão o primeiro `Team` → `.team(name:)`; sem nenhum dos dois o PR sai da lista (índice da busca atrasado). `reviewRequestedAt`: em `.you`, último evento para o viewer (como hoje); em `.team`, último evento para aquele time. Nos meus PRs, `reviewTarget` fica `.you`.

- [ ] **Step 1: Testes** `reviewRequestToViewerIsYou`, `reviewRequestOnlyToTeamIsTeamWithName` (`.team(name: "backend")`), `viewerAndTeamBothRequestedIsYou` (Review Focus 2), `reviewWithoutPendingRequestIsDropped`, `teamRequestedAtComesFromTeamEvent`, `mapsReviewDecision` (`null` → `nil`), `reviewSearchUsesReviewRequested`, `oldSnapshotDecodesTargetAndDecisionDefaults`.
- [ ] **Step 2:** `swift test --filter "PullRequestMapperTests|SnapshotStoreTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): traz reviews pedidos ao time e a decisão de review`

---

### Task 2: Mergeados hoje

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Model/MergedPullRequest.swift`, `GitHub/MergedSearchResponse.swift`, `Presentation/MergedToday.swift`, fixture `search-merged.json`
- Modify: `Model/Snapshot.swift`, `GitHub/Queries.swift`, `GitHub/PullRequestMapper.swift`, `GitHub/GitHubClient.swift`, `Support/PullRequest+Fixture.swift` (`Snapshot.fixture(mergedToday: [] )`)
- Test: `PullRequestMapperTests.swift`, `GitHubClientTests.swift`, `SnapshotStoreTests.swift`, `MergedTodayTests.swift`

**Interfaces:**
- Produces:
  - `public struct MergedPullRequest: Codable, Equatable, Identifiable, Sendable { id: String; number: Int; title: String; url: URL; repository: String; mergedAt: Date }`
  - `Snapshot.mergedToday: [MergedPullRequest]`: novo parâmetro `mergedToday: [MergedPullRequest] = []` no `init`; `init(from:)` próprio com `decodeIfPresent ?? []`.
  - `Queries.mergedSearchQuery` (só `id number title url mergedAt repository { nameWithOwner }`) e `Queries.merged(since: Date, timeZone: TimeZone) -> String`.
  - `PullRequestMapper.snapshot(mineJSON: Data, reviewJSON: Data, mergedJSON: Data?, now: Date) throws -> Snapshot`.
  - `public enum MergedToday { static func items(_ list: [MergedPullRequest], now: Date, calendar: Calendar) -> [MergedPullRequest] }`: só `mergedAt >= calendar.startOfDay(for: now)`, mais recente primeiro.

`GitHubClient.fetchSnapshot` faz a terceira busca em paralelo com `Queries.merged(since: now(), timeZone: .current)`. Formato: `is:pr author:@me is:merged merged:>=<yyyy-MM-dd>T00:00:00<±HH:MM> archived:false`, com a meia-noite local.

- [ ] **Step 1: Testes** `mergedQueryUsesLocalMidnightWithOffset` (2026-11-05 14:00 em `America/Sao_Paulo` → `is:pr author:@me is:merged merged:>=2026-11-05T00:00:00-03:00 archived:false`), `mapsMergedPullRequests`, `fetchSnapshotSendsThreeSearches` (ajusta `sendsBearerTokenAndBothSearches`), `mergedTodayDropsYesterdayAndSortsNewestFirst` (Review Focus 4), `oldSnapshotWithoutMergedTodayDecodes`.
- [ ] **Step 2:** `swift test --filter "PullRequestMapperTests|GitHubClientTests|SnapshotStoreTests|MergedTodayTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): busca os prs mergeados hoje`

---

### Task 3: Pronto para merge, badges de pedido e linha compacta

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Presentation/ReviewSummary.swift`, `Presentation/MergeReadiness.swift`, `Presentation/ListTab.swift`
- Modify: `Presentation/RowPresentation.swift`, `Presentation/Badge.swift` (`BadgeTone.accent`), `Presentation/PresentationConstants.swift`
- Test: `MergeReadinessTests.swift`, `RowPresentationTests.swift`

**Interfaces:**
- Consumes: `reviewTarget`, `reviewDecision` (Task 1)
- Produces:
  - `public enum ListTab: String, Codable, CaseIterable, Sendable { case mine, review, merge }`
  - `public struct ReviewSummary: Equatable, Sendable { public let approvals: Int; public let hasChangesRequested: Bool; public init(_ pr: PullRequest, viewer: String) }`: a lógica de `latestVerdicts` sai do `RowPresenter` para cá.
  - `public enum MergeReadiness { public static func isReady(_ pr: PullRequest, viewer: String) -> Bool }` (regra da Global Constraints).
  - `RowPresenter.review(_:now:jiraKey:)` começa com o badge de pedido: `.you` → `Badge("para você", .accent)`; `.team(name)` → `Badge("time <name>", .neutral)`.
  - `RowPresenter.merge(_ pr:, viewer:, now:, jiraKey: String? = nil) -> RowPresentation`: badge de CI, de aprovações e `Badge("sem conflito", .positive)`; subtítulo igual ao de Meus PRs.
  - `RowPresenter.compactLine(_ pr: PullRequest, tab: ListTab, viewer: String, now: Date) -> String`.

Linha compacta (`repo` = parte depois da `/`):
- `.mine` e `.merge`: `<repo> #<n> · <review> · <ci> · conflito · draft · <idade>`, onde review é `aprovado` / `alterações pedidas` / `sem review`, CI é `CI ok` / `CI rodando` / `CI falhou` (sem CI: omitido), `conflito` e `draft` só quando valem.
- `.review`: `<repo> #<n> · <autor> · para você|time <nome> · <idade desde o pedido>`.

- [ ] **Step 1: Testes**
  - `readyWhenApprovedGreenAndMergeable`, `notReadyWhenPendingCI`, `noChecksCountsAsGreen`, `withoutBranchProtectionOneApprovalIsEnough`, `withoutBranchProtectionChangesRequestedBlocks`, `reviewRequiredBlocksEvenWithApproval`, `unknownMergeableIsNotReady` (Review Focus 5), `draftIsNotReady`.
  - `reviewRowShowsForYouBadgeFirst`, `reviewRowShowsTeamName` (`"time backend"`), `mergeRowBadges` (`["✓ CI 12/12", "✓ 2 aprovações", "sem conflito"]`).
  - `compactLineMine`: `"loja #812 · aprovado · CI ok · 2h"`; `compactLineOmitsCIWhenNone`; `compactLineReview`: `"loja #815 · maria · para você · 40min"`.
- [ ] **Step 2:** `swift test --filter "MergeReadinessTests|RowPresentationTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): define pronto para merge, badges de pedido e linha compacta`

---

### Task 4: Drafts e time nas notificações e nos contadores

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Transitions/TransitionOptions.swift`, `Presentation/ReviewInclusion.swift`, `Presentation/Counters.swift`
- Modify: `Transitions/TransitionEngine.swift`, `Polling/RefreshCoordinator.swift`
- Test: `TransitionEngineTests.swift`, `RefreshCoordinatorTests.swift`, `CountersTests.swift`

**Interfaces:**
- Produces:
  - `public struct TransitionOptions: Equatable, Sendable { public var ignoreDraftReviews: Bool; public init(ignoreDraftReviews: Bool = true) }`
  - `TransitionEngine.events(from:to:options: TransitionOptions = .init())`
  - `RefreshCoordinator.refresh(options: TransitionOptions = .init()) async -> RefreshResult`
  - `public enum ReviewInclusion { public static func visible(_ prs: [PullRequest], ignoreDrafts: Bool, includeTeam: Bool) -> [PullRequest] }`
  - `public enum Counters { public static func reviewBadge(_ s: Snapshot, ignoreDrafts: Bool) -> Int; public static func hasFailingCI(_ s: Snapshot) -> Bool; public static func readyToMerge(_ s: Snapshot) -> Int }`: `reviewBadge` conta só `.you`, sem drafts quando ignorando.

Regras de review pedido no engine: só PRs `.you` contam, em `old` e em `new`; com `ignoreDraftReviews`, drafts saem dos dois conjuntos. PR que estava em `old.toReview` como draft e chega em `new` sem draft notifica mesmo com `reviewRequestedAt` antigo (Review Focus 3). PR que passa de `.team` para `.you` notifica.

- [ ] **Step 1: Testes** `teamRequestNotifiesWhenIncluded`, `teamRequestSilentWhenExcluded`, `togglingTeamOptionDoesNotBurst`, `teamRequestBecomingDirectNotifies`, `draftReviewRequestIgnoredWhenOptionOn`, `draftReviewRequestNotifiesWhenOptionOff`, `draftBecomingReadyNotifiesWhenIgnoringDrafts`, `coordinatorPassesOptionsToEngine`, `reviewBadgeExcludesTeamAndIgnoredDrafts`, `reviewBadgeCountsTeamWhenIncluded`, `visibleReviewsRespectDraftAndTeamOptions`, `readyCountUsesMergeReadiness`.
- [ ] **Step 2:** `swift test --filter "TransitionEngineTests|RefreshCoordinatorTests|CountersTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): ignora drafts e pedidos ao time nas notificações de review`

---

### Task 5: Modelo de filtros, ordem, visões e marcações

**Files:**
- Create em `PRumoKit/Sources/PRumoKit/Organization/`: `CIFilter.swift`, `ReviewFilter.swift`, `StateFilter.swift`, `RequestFilter.swift`, `RowFilter.swift`, `SortOrder.swift`, `TabOrdering.swift`, `SavedView.swift`, `RowStyle.swift`, `MutedPullRequest.swift`, `RowMarks.swift`, `OrganizationSettings.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/OrganizationSettingsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum CIFilter: String, Codable, CaseIterable, Sendable { case passed, running, failing }
  public enum ReviewFilter: String, Codable, CaseIterable, Sendable { case approved, changesRequested, noReview }
  public enum StateFilter: String, Codable, CaseIterable, Sendable { case noDrafts, conflicting, newActivity, pinned }
  public enum RequestFilter: String, Codable, CaseIterable, Sendable { case forYou, forTeam, stale }
  public struct RowFilter: Codable, Equatable, Sendable {
      public var repositories: Set<String>; public var ci: Set<CIFilter>; public var review: Set<ReviewFilter>
      public var state: Set<StateFilter>; public var request: Set<RequestFilter>; public var authors: Set<String>
      public static let empty: RowFilter; public var criteriaCount: Int
  }
  public enum SortOrder: String, Codable, CaseIterable, Sendable { case recentActivity, needsActionFirst, oldestFirst, newestFirst, repository, diffSize }
  public struct TabOrdering: Codable, Equatable, Sendable { public var order: SortOrder = .recentActivity; public var groupByRepository = false }
  public struct SavedView: Codable, Equatable, Identifiable, Sendable { public let id: UUID; public var name: String; public var filter: RowFilter }
  public enum RowStyle: String, Codable, CaseIterable, Sendable { case detailed, compact }
  public struct MutedPullRequest: Codable, Equatable, Sendable { id: String; number: Int; title: String; repository: String; mutedAt: Date }
  public struct RowMarks: Codable, Equatable, Sendable {
      public var pinned: Set<String>; public var muted: [String: MutedPullRequest]
      public func isPinned(_ id: String) -> Bool; public func isMuted(_ id: String) -> Bool
      public func pruned(states: [String: PRState]) -> RowMarks
  }
  public struct OrganizationSettings: Codable, Equatable, Sendable {
      public var filter: RowFilter; public var orderings: [String: TabOrdering]
      public var views: [SavedView]; public var favorites: Set<String>; public var knownRepositories: Set<String>
      public var hideEmptyRepositories: Bool; public var rowStyle: RowStyle
      public var ignoreDraftsInReview: Bool; public var includeTeamRequests: Bool; public var marks: RowMarks
      public func ordering(for tab: ListTab) -> TabOrdering; public mutating func setOrdering(_ o: TabOrdering, for tab: ListTab)
      public static let defaults: OrganizationSettings
  }
  ```
  `orderings` usa `ListTab.rawValue` como chave para o JSON ficar um objeto. `criteriaCount` soma os itens de `ci`, `review`, `state`, `request` e `authors` (repositórios ficam fora: aparecem no botão "Repositórios · N"). `pruned` tira de `pinned` e `muted` os ids com estado `.closed` ou `.merged`.

Todos os campos com `decodeIfPresent` e o default da Global Constraints.

- [ ] **Step 1: Testes** `emptyJSONDecodesToDefaults` (`{}` → `ignoreDraftsInReview == true`, `includeTeamRequests == false`, `rowStyle == .detailed`, `ordering(for: .review) == TabOrdering()`), `roundTripCodable`, `criteriaCountIgnoresRepositories`, `marksPrunedOnlyWhenClosedOrMerged` (estado `.open` mantém).
- [ ] **Step 2:** `swift test --filter OrganizationSettingsTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): modelo de filtros, ordem, visões e marcações`

---

### Task 6: Filtrar, ordenar, agrupar e catálogo de repositórios

**Files:**
- Create em `PRumoKit/Sources/PRumoKit/Organization/`: `FilterContext.swift`, `RowFiltering.swift`, `RowSection.swift`, `RowOrdering.swift`, `RepositoryEntry.swift`, `RepositoryGroup.swift`, `RepositoryCatalog.swift`, `FilterChipKey.swift`, `FilterChip.swift`, `FilterChips.swift`, `OrganizationConstants.swift`
- Test: `RowFilteringTests.swift`, `RowOrderingTests.swift`, `RepositoryCatalogTests.swift`

**Interfaces:**
- Consumes: Tasks 3 e 5
- Produces:
  ```swift
  public struct FilterContext: Sendable { viewer: String; marks: RowMarks; unseen: Set<String>; staleLimit: TimeInterval; now: Date }
  public enum RowFiltering { public static func apply(_ prs: [PullRequest], filter: RowFilter, tab: ListTab, context: FilterContext) -> [PullRequest] }
  public struct RowSection: Equatable, Sendable { public let repository: String?; public let items: [PullRequest] }
  public enum RowOrdering { public static func sections(_ prs: [PullRequest], tab: ListTab, ordering: TabOrdering, marks: RowMarks, viewer: String) -> [RowSection] }
  public struct RepositoryEntry: Equatable, Sendable { name: String; count: Int; isFavorite: Bool }
  public struct RepositoryGroup: Equatable, Sendable { title: String; entries: [RepositoryEntry] }
  public enum RepositoryCatalog { public static func groups(snapshot: Snapshot, known: Set<String>, favorites: Set<String>, hideEmpty: Bool, search: String) -> [RepositoryGroup] }
  public enum FilterChipKey: Hashable, Sendable { case ci(CIFilter), review(ReviewFilter), state(StateFilter), request(RequestFilter), author(String) }
  public struct FilterChip: Equatable, Sendable { public let key: FilterChipKey; public let label: String }
  public enum FilterChips { public static func chips(_ f: RowFilter, staleHours: Int) -> [FilterChip] }
  extension RowFilter { public func removing(_ key: FilterChipKey) -> RowFilter }
  ```
  `FilterContext.staleLimit` é 24 h nesta etapa (`OrganizationConstants.defaultStaleLimit`); a etapa 5 passa o valor dos Ajustes.

Semântica do filtro (OR dentro do grupo, AND entre grupos; grupo vazio não filtra):
- `repositories`: vazio = todos.
- `ci`: `.passed` casa `.success` e `.none`; `.running` casa `.pending`; `.failing` casa `.failure`.
- `review` (via `ReviewSummary`): `.approved` = aprovações > 0 sem alteração pedida; `.changesRequested`; `.noReview` = nenhum dos dois.
- `state`: `.noDrafts` exclui drafts por conta própria; `.conflicting`, `.newActivity` (`context.unseen`) e `.pinned` são OR entre si quando algum está marcado.
- `request`: só vale na aba `.review` (`.forYou`, `.forTeam`, `.stale` = espera desde `reviewRequestedAt ?? createdAt` ≥ `staleLimit`); nas outras abas é ignorado.
- `authors`: compara sem diferenciar maiúsculas.

Ordem: `.recentActivity` = `updatedAt` desc; `.needsActionFirst` = primeiro os que pedem ação (Meus PRs e Merge: CI falhando, alteração pedida ou conflito; Revisar: `.you`), depois atividade recente; `.oldestFirst`/`.newestFirst` por `createdAt`; `.repository` por nome e depois número desc; `.diffSize` por `additions + deletions` desc. Empate: número desc. Depois da ordem, fixados sobem para o topo e silenciados descem para o fim, mantendo a ordem relativa. Com `groupByRepository`, uma seção por repositório em ordem alfabética, com a regra de fixados e silenciados dentro de cada seção; sem agrupar, uma seção com `repository == nil`.

Catálogo: contagem = PRs distintos (por id) de `mine` + `toReview` por repositório; nomes = `known ∪ favorites ∪ presentes`. Primeiro o grupo `FAVORITOS`, depois um grupo por org (`title` em maiúsculas, orgs e repositórios em ordem alfabética; favoritos também aparecem no grupo da org). `hideEmpty` tira os de contagem 0, exceto favoritos. `search` filtra por `contains` sem diferenciar maiúsculas.

Rótulos dos chips: `CI passou`, `CI rodando`, `CI falhando`, `Aprovado`, `Alterações pedidas`, `Sem review`, `Sem drafts`, `Com conflito`, `Com atividade nova`, `Fixados`, `Para você`, `Para o time`, `Parado há +<h>h`, `Autor: <login>`.

- [ ] **Step 1: Testes**
  - `emptyFilterKeepsAll`, `repositorySelectionFilters`, `ciGroupIsOrWithinAndAcrossGroups`, `noChecksCountsAsPassed`, `noDraftsExcludesDrafts`, `stateFiltersAreOrBetweenThemselves`, `requestFilterOnlyAppliesToReviewTab`, `staleRequestFilterUsesLimit`, `authorFilterIgnoresCase`.
  - `@Test(arguments: SortOrder.allCases) pinnedAlwaysTopMutedAlwaysBottom`, `needsActionFirstOrder`, `diffSizeOrder`, `groupByRepositorySections`.
  - `catalogGroupsFavoritesFirstWithCounts`, `catalogHidesEmptyButKeepsFavorites`, `catalogSearch`.
  - `chipsLabelsAndRemoval` (filtro com `.failing` e `.noDrafts` → `["CI falhando", "Sem drafts"]`; `removing(.ci(.failing))` tira só aquele).
- [ ] **Step 2:** `swift test --filter "RowFilteringTests|RowOrderingTests|RepositoryCatalogTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): filtra, ordena e agrupa as linhas`

---

### Task 7: Atividade nova

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Organization/ActivityTracker.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/ActivityTrackerTests.swift`

**Interfaces:**
- Produces: `public enum ActivityTracker { public static func touched(old: Snapshot?, new: Snapshot, events: [NotificationEvent]) -> Set<String>; public static func pruned(_ unseen: Set<String>, snapshot: Snapshot) -> Set<String> }`

`touched` = ids dos eventos (antes de qualquer filtro de silenciado, toggle ou Não perturbe) ∪ ids de `mine` e `toReview` cujo `headSHA` mudou em relação a um `headSHA` anterior não vazio. `old == nil` → vazio. `pruned` mantém só ids presentes em `mine` ou `toReview`.

- [ ] **Step 1: Testes** `eventsMarkActivity`, `newCommitMarksActivity`, `titleChangeDoesNotMark` (título e `updatedAt` mudam, SHA igual, sem eventos), `firstSnapshotMarksNothing`, `prunesIdsNoLongerListed`.
- [ ] **Step 2:** `swift test --filter ActivityTrackerTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): marca atividade nova por pr`

---

### Task 8: Aba Merge, fixados, silenciados, marcador de novo e linha compacta

**Files:**
- Create: `PRumo/Services/OrganizationStore.swift`, `PRumo/Views/Popover/MergedRowView.swift`
- Modify: `PRumo/AppConstants.swift` (`organizationKey = "organization"`, `unseenActivityKey = "unseenActivity"`), `PRumo/AppModel.swift`, `PRumo/Views/Popover/PopoverConstants.swift` (remove `PopoverTab`, usa `ListTab`), `PopoverView.swift`, `PRRowView.swift`, `PullRequest+Claude.swift`, `PRumo/Views/MenuBarLabel.swift`, `PRumo/Views/Popover/BadgeView.swift` (`.accent` → caramelo)

**Interfaces:**
- Consumes: Tasks 2 a 7
- Produces:
  ```swift
  @Observable @MainActor final class OrganizationStore {
      var settings: OrganizationSettings
      private(set) var unseen: Set<String>
      init(defaults: UserDefaults = .standard)
      func togglePin(_ pr: PullRequest)
      func toggleMute(_ pr: PullRequest, now: Date)
      func unmute(id: String)
      func recordActivity(_ ids: Set<String>)
      func markSeen(_ ids: Set<String>)
      func learnRepositories(from snapshot: Snapshot)
  }
  ```
  `AppModel` expõe `let organization: OrganizationStore`.

`AppModel.runRefresh` passa a: chamar `coordinator.refresh(options: TransitionOptions(ignoreDraftReviews: organization.settings.ignoreDraftsInReview))`; guardar o snapshot anterior para `ActivityTracker.touched` e gravar o resultado menos os silenciados em `recordActivity` (com `pruned`); postar só eventos de PRs não silenciados; chamar `learnRepositories`.

Popover:
- Abas `Meus PRs`, `Revisar`, `Merge`. Revisar mostra `ReviewInclusion.visible(...)` com as duas opções. Merge mostra `mine` com `MergeReadiness.isReady`, vazio `Nenhum PR pronto para merge`.
- Depois das linhas da aba Merge, cabeçalho `MERGEADOS HOJE · <n>` e uma `MergedRowView` por item de `MergedToday.items(...)` (recalculado no `TimelineView` de 60 s): `checkmark` verde, título, `org/repo #n · merge às HH:mm`; clique abre a URL.
- Barra de menu: contador `Counters.reviewBadge`, ponto vermelho `Counters.hasFailingCI`.
- Linha fixada: `pin.fill` caramelo antes do título.
- Linha silenciada: opacidade 0,55, `pause.fill` cinza no lugar da bolinha de status, `.help("Silenciado em dd/MM")`.
- Marcador de novo: ao abrir o popover, `PopoverView` guarda `highlighted = organization.unseen`; cada linha que aparece chama `markSeen([id])`; a linha com id em `highlighted` mostra uma bolinha caramelo de 7 pt no canto superior direito (some com o hover e com o menu aberto) e o título em `.semibold`. Abrir e fechar: confirmar que `onAppear`/`onDisappear` da `PopoverView` disparam a cada abertura no macOS 26; se não disparar, usar `NSWindow.didBecomeKeyNotification`/`didResignKeyNotification` da janela do popover.
- Linha compacta (`settings.rowStyle == .compact`): bolinha, título em uma linha e `RowPresenter.compactLine`, sem badges; o menu `⋯` continua igual.

Textos novos em `PopoverText`: `mergeTab = "Merge"`, `emptyMerge = "Nenhum PR pronto para merge"`, `mergedToday(count:)` → `"MERGEADOS HOJE · \(count)"`, `mergedAt(time:)` → `"merge às \(time)"`, `mutedOn(date:)` → `"Silenciado em \(date)"`.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Rodar o app: aba Merge com contador; um PR com commit novo ganha a bolinha caramelo e perde na abertura seguinte.
- [ ] **Step 4: Commit** `feat(app): adiciona a aba merge, fixados, silenciados e marcador de novo`

---

### Task 9: Barra de repositórios, filtros e ordem

**Files:**
- Create em `PRumo/Views/Popover/Filters/`: `FilterBar.swift`, `RepositoryPicker.swift`, `FilterPicker.swift`, `OrderPicker.swift`, `FilterChipsView.swift`, `SectionHeader.swift`, `FiltersConstants.swift`
- Modify: `PRumo/Views/Popover/PopoverView.swift`

**Interfaces:**
- Consumes: `RowFiltering`, `RowOrdering`, `RepositoryCatalog`, `FilterChips` (Task 6), `OrganizationStore` (Task 8)

Comportamento (mockup `filtros.html`):
- Barra abaixo das abas: à esquerda `Repositórios` / `Repositórios · <n>` e `Filtros` / `Filtros · <criteriaCount>`; à direita `↕ <ordem>` ou `↕ Agrupado por repo`. Cada botão abre um popover.
- Repositórios: campo `Buscar repositório`, grupos do catálogo com marca de seleção, `★` clicável (favorito) e contagem; rodapé `Esconder repositórios sem PR` e `Salvar como visão…`.
- Filtros: seção `VISÕES` (só com visões salvas; clique aplica o filtro), grupos `CI` (`passou`, `rodando`, `falhando`), `REVIEW` (`aprovado`, `alterações pedidas`, `sem review`), `ESTADO` (`sem drafts`, `com conflito`, `com atividade nova`, `fixados`), `REVISAR` (`para você`, `para o time`, `parado há +24h`), `AUTOR` (busca `Buscar pessoa` sobre os autores do snapshot, menos o viewer); rodapé `Salvar como visão…`.
- Ordem (da aba atual): `Atividade recente`, `Precisa de ação primeiro`, `Mais antigos primeiro`, `Mais novos primeiro`, `Repositório`, `Tamanho do diff`, toggle `Agrupar por repositório` e a nota `Fixados sempre no topo · silenciados no fim`.
- Chips abaixo da barra, cada um com `✕`, e `Limpar` (zera `filter`, mantendo a ordem).
- `Salvar como visão…` abre um `.alert` com campo `Nome` e botões `Salvar` / `Cancelar`; nome vazio desabilita `Salvar`.
- Listas: `RowFiltering.apply` → `RowOrdering.sections`; seção com repositório mostra `SectionHeader` `GLOBEX/WEB-APP · 2`. Contadores das abas mostram a quantidade depois dos filtros. "Mergeados hoje" respeita só o filtro de repositórios.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Rodar o app e conferir contra o mockup, no claro e no escuro: filtros persistem depois de sair e abrir o app; "Limpar" some com os chips; ordem diferente em cada aba.
- [ ] **Step 4: Commit** `feat(app): adiciona a barra de repositórios, filtros e ordem`

---

### Task 10: Fixar e silenciar pelo menu e pela notificação

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Presentation/RowMenuEntry.swift`, `Presentation/RowMenuPlan.swift`, `PRumo/Views/Popover/RowMenuEntry+Presentation.swift`, `RowMenuConstants.swift`, `PRumo/AppModel.swift`, `PRumo/Services/NotificationCategories.swift`, `PRumo/Services/NotificationService.swift`
- Test: `RowMenuPlanTests.swift`

**Interfaces:**
- Consumes: `RowMarks.pruned` (Task 5), `OrganizationStore` (Task 8), `GitHubClient.pullRequestStates(ids:)`
- Produces:
  - `RowMenuEntry` ganha `case pin(isPinned: Bool)` e `case mute(isMuted: Bool)`.
  - `RowMenuPlan.entries(pr:claudePurposes:jira:isPinned: Bool = false, isMuted: Bool = false)`: acrescenta `.separator`, `.pin`, `.mute` no fim.
  - `NotificationService.onMute: @MainActor (String) -> Void`.

Títulos: `.pin(false)` → `Fixar no topo`; `.pin(true)` → `Desafixar`; `.mute(false)` → `Silenciar este PR`; `.mute(true)` → `Reativar notificações`. `AppModel.perform` chama `togglePin`/`toggleMute`.

Notificação: ação `silenciar` "Silenciar" (`.foreground`) no fim de `ci-failed` e `ci-failed-no-run`. O `AppModel` procura o PR em `mine` e `toReview`; achou → `toggleMute` se ainda não estiver silenciado; não achou → nada.

Limpeza: depois de um refresh `.ok`, ids marcados ausentes de `mine` e `toReview` vão para `pullRequestStates`; o resultado passa por `RowMarks.pruned`. No máximo uma consulta por hora (`AppConstants.marksPruneInterval: TimeInterval = 3600`).

- [ ] **Step 1: Testes** `pinAndMuteEntriesComeLast` (`[..., .copyCheckout(...), .separator, .pin(isPinned: false), .mute(isMuted: false)]`), `entriesReflectPinnedAndMuted` (`isPinned: true, isMuted: true` → `.pin(isPinned: true)`, `.mute(isMuted: true)`).
- [ ] **Step 2:** `swift test --filter RowMenuPlanTests` → FAIL.
- [ ] **Step 3:** Implementar kit e app.
- [ ] **Step 4:** `swift test` → PASS; build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 5: Commit** `feat(app): fixa e silencia prs pelo menu e pela notificação`

---

### Task 11: Ajustes de filtros, linha compacta e onboarding

**Files:**
- Create: `PRumo/Views/Settings/FiltersSettingsView.swift`, `PRumo/Views/Settings/FiltersSettingsConstants.swift`
- Modify: `PRumo/Views/Settings/SettingsView.swift`, `SettingsConstants.swift` (`SettingsTab.filters`), `PRumo/Views/Onboarding/OnboardingView.swift`, `OnboardingConstants.swift`, `OnboardingModel.swift`

**Interfaces:**
- Consumes: `OrganizationStore` (Task 8)

- Aba `Geral`: picker `Linha do PR` com `Detalhada` e `Compacta`.
- Aba `Filtros` (símbolo `line.3.horizontal.decrease.circle`, depois de Geral): toggles `Ignorar drafts em Revisar` e `Incluir reviews pedidos ao time`; seção `Visões salvas` (nome editável, botão remover; vazio `Nenhuma visão salva`); seção `PRs silenciados` (`org/repo #n · título`, `Silenciado em dd/MM`, botão `Reativar`; vazio `Nenhum PR silenciado`).
- Onboarding, passo "Tudo pronto": toggle `Ignorar drafts em Revisar`, ligado, abaixo de "Abrir ao iniciar o macOS"; grava em `organization.settings.ignoreDraftsInReview`.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3: Commit** `feat(app): adiciona os ajustes de filtros e a linha compacta`

---

### Task 12: Verificação ponta a ponta

- [ ] **Step 1:** `swift test` → todos PASS. `xcodebuild clean build` → `BUILD SUCCEEDED`, zero warnings do projeto.
- [ ] **Step 2 (usuário):** com "Incluir reviews pedidos ao time" ligado, um PR pedido ao time aparece com `time <nome>`, sem notificação e fora do contador da barra.
- [ ] **Step 3 (usuário):** aba Merge lista os prontos; depois de um merge, o PR aparece em "Mergeados hoje" com o horário.
- [ ] **Step 4 (usuário):** silenciar um PR pelo menu e pela notificação de CI → desce para o fim, esmaecido, sem novas notificações; reativar pelos Ajustes.
- [ ] **Step 5 (usuário):** salvar uma visão, limpar os filtros, reaplicar a visão; trocar para linha compacta.
