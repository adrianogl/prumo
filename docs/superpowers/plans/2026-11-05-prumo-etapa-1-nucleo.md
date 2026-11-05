# PRumo: Etapa 1 (Núcleo) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App de barra de menu para macOS que mostra os PRs abertos do usuário e os reviews pedidos a ele, e notifica CI terminada, aprovação, alterações pedidas, comentário novo e review pedido.

**Architecture:** Toda a lógica testável (modelos, cliente GraphQL, motor de transições, persistência, token, apresentação das linhas) fica no pacote Swift local `PRumoKit`, testado com `swift test`. O target de app `PRumo` (gerado pelo XcodeGen) só tem SwiftUI, `MenuBarExtra`, `UserNotifications`, Keychain e `SMAppService`, e consome o `PRumoKit`.

**Tech Stack:** Swift 6.4, SwiftUI, Observation, Swift Testing, XcodeGen 2.46, GitHub GraphQL API v4. Sem dependências externas.

**Spec:** `docs/superpowers/specs/2026-11-05-prumo-design.md`

Este plano cobre só a etapa 1 da seção "Ordem de entrega" da spec. As etapas 2 a 7 terão um plano cada, escrito quando a anterior estiver pronta, porque cada uma depende das interfaces que a anterior consolidar.

## Global Constraints

- macOS 26 como deployment target. Sem ícone no Dock (`LSUIElement = YES`).
- App principal sem App Sandbox (precisa rodar `gh`). Assinatura: time pessoal gratuito do Xcode, "Sign to Run Locally" aceito.
- Uma conta, github.com. Token: `gh auth token` primeiro; senão PAT com escopos `repo` e `read:org`, guardado no Keychain (service `dev.aglv.prumo`, account `github-token`). Nunca gravar token em arquivo.
- Bundle id: `dev.aglv.prumo`.
- Intervalo de atualização padrão: 60 s.
- Primeira leitura (sem estado salvo) não notifica nada.
- Comentário do próprio usuário ou de bot não notifica.
- Notificação de CI: uma por commit (head SHA), não por check. Clique abre `<url do PR>/checks`.
- Paleta: areia `#f3e6cf` → `#d9c3a0`, carvão `#2a2622`, caramelo `#a5713a`. Fundo do popover claro `#fbf8f2`, escuro `#252322`. Cores de status: cores de sistema (`.green`, `.yellow`, `.red`, `.orange`).
- Logotipo: "PRumo", SF Pro Bold, tracking negativo proporcional a −1,2 pt em 40 pt (`tracking(-0.03 * fontSize)`), "PR" em caramelo.
- Ícones de interface: SF Symbols, nada de emoji. Comentários = `bubble.left.and.bubble.right`, conflito = símbolo de merge bloqueado (custom ou `arrow.triangle.merge` com `xmark`), espera = `clock`.
- Símbolo do app: `docs/mockups/pull-request-carbon.svg` (IBM Carbon, Apache 2.0). Aviso de licença na tela Sobre.
- Textos da interface em português do Brasil.
- Código sem comentários, salvo workaround não óbvio. Types e constantes em arquivos próprios, seguindo a convenção do projeto (ex.: `PullRequest.swift` para o modelo, `Constants.swift` por feature).
- Commits em Conventional Commits, em português, minúsculas, sem trailer de co-autoria.

## Review Focus

1. **Repositório sem CI** (`statusCheckRollup` nulo): linha sem badge de CI e nenhuma notificação de CI. Teste em Task 4 e Task 2.
2. **Push novo com CI rodando**: o head SHA muda no meio; só o resultado do SHA mais recente notifica, uma vez. Teste em Task 4.
3. **PR some e volta da lista** (fechado e reaberto, ou some por paginação): ao voltar, reviews e comentários antigos não viram notificação. Teste em Task 4.
4. **Token revogado no meio do uso (HTTP 401)**: o polling para, o popover pede reconexão, e ao reconectar o estado salvo continua sendo a base (sem rajada de notificações). Teste em Task 3 e Task 9.
5. **Volta da rede depois de horas offline**: a comparação é contra o último estado salvo em disco, então cada evento perdido notifica uma vez só, e comentários vários no mesmo PR viram uma notificação agrupada. Teste em Task 4 e Task 5.

---

## Estrutura de arquivos

```
project.yml                                  XcodeGen
PRumo/                                       target de app
  PRumoApp.swift                             @main, MenuBarExtra, Settings, janela de onboarding
  AppModel.swift                             estado observável, polling, coordenação
  AppConstants.swift
  Services/NotificationService.swift         UNUserNotificationCenter
  Services/KeychainTokenStore.swift
  Services/LaunchAtLogin.swift               SMAppService
  Views/MenuBarLabel.swift
  Views/Popover/PopoverView.swift
  Views/Popover/PRRowView.swift
  Views/Popover/BadgeView.swift
  Views/Popover/StatusBanner.swift
  Views/Brand/Wordmark.swift
  Views/Brand/BrandColors.swift
  Views/Onboarding/OnboardingView.swift
  Views/Settings/SettingsView.swift
  Resources/Assets.xcassets                  AppIcon, MenuBarGlyph, cores
  Resources/Info.plist
  Resources/PRumo.entitlements
PRumoKit/
  Package.swift
  Sources/PRumoKit/Model/*.swift
  Sources/PRumoKit/GitHub/*.swift
  Sources/PRumoKit/Transitions/*.swift
  Sources/PRumoKit/Persistence/SnapshotStore.swift
  Sources/PRumoKit/Auth/*.swift
  Sources/PRumoKit/Presentation/*.swift
  Tests/PRumoKitTests/...
  Tests/PRumoKitTests/Fixtures/*.json
scripts/render-icons.swift                   gera PNGs do AppIcon a partir do SVG
```

---

### Task 1: Esqueleto do projeto

**Files:**
- Create: `project.yml`, `PRumo/PRumoApp.swift`, `PRumo/Resources/Info.plist`, `PRumo/Resources/PRumo.entitlements`, `PRumoKit/Package.swift`, `PRumoKit/Sources/PRumoKit/PRumoKit.swift`, `PRumoKit/Tests/PRumoKitTests/SmokeTests.swift`
- Modify: `.gitignore` (adicionar `PRumo.xcodeproj/`, `.build/`)

**Interfaces:**
- Produces: pacote `PRumoKit` (library, plataforma `.macOS(.v26)`, `swift-tools-version: 6.2`), target de app `PRumo` dependendo dele; scheme `PRumo`.

- [ ] **Step 1: Teste smoke**

```swift
import Testing
@testable import PRumoKit

@Test func versionIsSet() { #expect(PRumoKit.version == "0.1.0") }
```

- [ ] **Step 2:** `cd PRumoKit && swift test` → FAIL (`PRumoKit` não existe).
- [ ] **Step 3:** Criar `Package.swift` e `public enum PRumoKit { public static let version = "0.1.0" }`.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5:** Criar `project.yml`: target `PRumo` (application, macOS 26, bundle id `dev.aglv.prumo`, `INFOPLIST_FILE`, `CODE_SIGN_ENTITLEMENTS`, `ENABLE_APP_SANDBOX = NO`, `ENABLE_HARDENED_RUNTIME = YES`, package local `PRumoKit`). `Info.plist` com `LSUIElement = YES`, `CFBundleDisplayName = PRumo`. `PRumoApp` com `MenuBarExtra("PRumo", systemImage: "arrow.triangle.pull") { Text("PRumo") }.menuBarExtraStyle(.window)`.
- [ ] **Step 6:** `xcodegen generate && xcodebuild -project PRumo.xcodeproj -scheme PRumo -destination 'platform=macOS' build` → `** BUILD SUCCEEDED **`.
- [ ] **Step 7: Commit** `chore: cria esqueleto do app e do pacote PRumoKit`

---

### Task 2: Modelos e decodificação da resposta GraphQL

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Model/PullRequest.swift`, `CIStatus.swift`, `Review.swift`, `Comment.swift`, `Snapshot.swift`
- Create: `PRumoKit/Sources/PRumoKit/GitHub/GraphQLResponse.swift` (DTOs `Decodable` privados ao módulo), `GitHub/PullRequestMapper.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/PullRequestMapperTests.swift`, `Fixtures/search-mine.json`, `Fixtures/search-review.json`

**Interfaces:**
- Produces (todos `public`, `Sendable`, `Codable`, `Equatable`):
  - `struct PullRequest: Identifiable { id: String; number: Int; title: String; url: URL; repository: String /* "org/repo" */; author: String; isDraft: Bool; createdAt: Date; updatedAt: Date; headSHA: String; ci: CIStatus; reviews: [Review]; comments: [Comment]; commentCount: Int; additions: Int; deletions: Int; mergeable: Mergeable; reviewRequestedAt: Date? }`
  - `enum CIStatus { case none; case pending(done: Int, total: Int); case success(total: Int); case failure(failedChecks: [String], total: Int) }` com `var isTerminal: Bool`
  - `enum Mergeable: String { case mergeable = "MERGEABLE", conflicting = "CONFLICTING", unknown = "UNKNOWN" }`
  - `struct Review { id: String; author: String; state: ReviewState; submittedAt: Date }`, `enum ReviewState: String { approved = "APPROVED", changesRequested = "CHANGES_REQUESTED", commented = "COMMENTED", dismissed = "DISMISSED", pending = "PENDING" }`
  - `struct Comment { id: String; author: String; authorIsBot: Bool; body: String; url: URL; createdAt: Date }`
  - `struct Snapshot { viewer: String; mine: [PullRequest]; toReview: [PullRequest]; fetchedAt: Date }`
  - `enum PullRequestMapper { static func snapshot(mineJSON: Data, reviewJSON: Data, now: Date) throws -> Snapshot }`

Regras do mapeamento de CI (a partir de `commits(last:1).nodes[0].commit.statusCheckRollup`):
- rollup nulo → `.none`
- algum CheckRun com `status != COMPLETED` ou StatusContext `PENDING`/`EXPECTED` → `.pending(done:total:)`
- algum CheckRun com `conclusion` em `FAILURE, TIMED_OUT, CANCELLED, ACTION_REQUIRED, STARTUP_FAILURE` ou StatusContext `FAILURE`/`ERROR` → `.failure(failedChecks:)` com os nomes na ordem da resposta
- senão → `.success(total:)`; `total` = `contexts.totalCount`

`reviewRequestedAt` = `createdAt` do `ReviewRequestedEvent` mais recente cujo `requestedReviewer.login == viewer`. Bots: `author.__typename == "Bot"`.

- [ ] **Step 1: Fixtures.** `search-mine.json` com 4 PRs cobrindo: CI sucesso 12/12 com 2 aprovações; CI falha (`unit-tests`) 1 de 12; CI pendente 4/9 e draft; sem rollup (null) com `CHANGES_REQUESTED` e `CONFLICTING`. `search-review.json` com 2 PRs, um com `ReviewRequestedEvent` para o viewer. Formato exatamente o da query da Task 3.
- [ ] **Step 2: Testes**

```swift
@Test func mapsCIStatuses() throws {
    let s = try PullRequestMapper.snapshot(mineJSON: fixture("search-mine"), reviewJSON: fixture("search-review"), now: .fixed)
    #expect(s.mine.map(\.ci) == [.success(total: 12), .failure(failedChecks: ["unit-tests"], total: 12), .pending(done: 4, total: 9), .none])
}
@Test func detectsBotsAndConflict() throws { /* comment de bot → authorIsBot == true; mine[3].mergeable == .conflicting */ }
@Test func reviewRequestedAtComesFromViewerEvent() throws { /* toReview[0].reviewRequestedAt == data do evento */ }
@Test func viewerLoginIsRead() throws { /* s.viewer == "adriano" */ }
```

- [ ] **Step 3:** `swift test --filter PullRequestMapperTests` → FAIL.
- [ ] **Step 4:** Implementar DTOs e `PullRequestMapper`. Datas ISO 8601 com `JSONDecoder.DateDecodingStrategy.iso8601`.
- [ ] **Step 5:** `swift test` → PASS.
- [ ] **Step 6: Commit** `feat(kit): adiciona modelos e leitura da resposta do github`

---

### Task 3: Cliente GraphQL

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/GitHub/GitHubClient.swift`, `GitHub/Queries.swift`, `GitHub/HTTPTransport.swift`, `GitHub/GitHubError.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/GitHubClientTests.swift`

**Interfaces:**
- Consumes: `PullRequestMapper.snapshot(mineJSON:reviewJSON:now:)`
- Produces:
  - `protocol HTTPTransport: Sendable { func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) }` e `struct URLSessionTransport: HTTPTransport`
  - `enum GitHubError: Error, Equatable { case unauthorized, rateLimited(resetAt: Date?), network, server(status: Int), graphQL(messages: [String]) }`
  - `struct GitHubClient: Sendable { init(token: String, transport: HTTPTransport = URLSessionTransport(), now: @Sendable () -> Date = Date.init); func fetchSnapshot() async throws(GitHubError) -> Snapshot }`
  - `Queries.searchQuery` (string GraphQL) e `Queries.mine = "is:pr is:open author:@me archived:false"`, `Queries.review = "is:pr is:open user-review-requested:@me archived:false"`

A query usa `search(query:, type: ISSUE, first: 50)` e `viewer { login }`; pede por PR os campos da Task 2: `commits(last:1)` com `statusCheckRollup { state contexts(first:100) { totalCount nodes { __typename ... on CheckRun { name status conclusion } ... on StatusContext { context state } } } }`, `reviews(last:30)`, `comments(last:20) { totalCount nodes { id url body createdAt author { __typename login } } }`, `timelineItems(itemTypes:[REVIEW_REQUESTED_EVENT], last:10)`. As duas buscas vão em duas requests em paralelo (`async let`), `POST https://api.github.com/graphql`, header `Authorization: bearer <token>`.

- [ ] **Step 1: Testes com transport fake**

```swift
@Test func sendsBearerTokenAndBothSearches() async throws { /* fake grava requests: 2 POSTs, header "bearer t0k", corpos contêm Queries.mine e Queries.review */ }
@Test func maps401ToUnauthorized() async { /* fake responde 401 → throws .unauthorized */ }
@Test func maps403WithZeroRemainingToRateLimited() async { /* header x-ratelimit-remaining: 0, x-ratelimit-reset: 1793900000 */ }
@Test func mapsURLErrorToNetwork() async { /* fake lança URLError(.notConnectedToInternet) → .network */ }
@Test func surfacesGraphQLErrors() async { /* 200 com {"errors":[{"message":"x"}]} → .graphQL(["x"]) */ }
```

- [ ] **Step 2:** `swift test --filter GitHubClientTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): adiciona cliente graphql do github`

---

### Task 4: Motor de transições

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Transitions/NotificationEvent.swift`, `Transitions/TransitionEngine.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/TransitionEngineTests.swift`, `Tests/PRumoKitTests/Support/PullRequest+Fixture.swift` (builder `PullRequest.fixture(...)` com valores padrão)

**Interfaces:**
- Consumes: `Snapshot`, `PullRequest`, `CIStatus`, `Review`, `Comment`
- Produces:
  - `enum NotificationKind: String, Codable, Sendable { case ciFailed, ciSucceeded, approved, changesRequested, newComment, reviewRequested }`
  - `struct NotificationEvent: Equatable, Sendable { kind: NotificationKind; pullRequestID: String; title: String; body: String; url: URL; threadID: String /* = pullRequestID */ }`
  - `enum TransitionEngine { static func events(from old: Snapshot?, to new: Snapshot) -> [NotificationEvent] }`

Regras:
- `old == nil` → `[]`.
- Só PRs presentes nos dois snapshots geram eventos de `mine`; PR novo em `mine` não gera nada.
- **CI**: evento quando `new.ci.isTerminal` e (`!old.ci.isTerminal` ou `old.headSHA != new.headSHA`). `.none` nunca notifica.
- **Aprovado / alterações pedidas**: um evento por `Review.id` de `new` ausente em `old`, com autor `!= viewer`, estado `approved` ou `changesRequested`.
- **Comentário**: comentários de `new` com `id` ausente em `old`, autor `!= viewer`, `!authorIsBot`, `createdAt > old.fetchedAt` (protege PR que some e volta). Um evento por PR; se mais de um comentário, título "N comentários novos em #n".
- **Review pedido**: PR em `new.toReview` com `id` ausente de `old.toReview`.
- **Reviews** também usam `submittedAt > old.fetchedAt`.

Textos exatos (spec, tabela de notificações):

| kind | title | body | url |
| --- | --- | --- | --- |
| ciFailed | `CI falhou em #809` | `<título> · <primeiro check falho>` | `<pr.url>/checks` |
| ciSucceeded | `CI terminou em #812: 12/12` | `<título>` | `<pr.url>/checks` |
| approved | `#812 aprovado` | `<autor> aprovou <título>` | `pr.url` |
| changesRequested | `Alterações pedidas em #74` | `<autor> pediu alterações em <título>` | `pr.url` |
| newComment | `Comentário novo em #812` | `<autor>: "<até 80 caracteres do corpo>"` | `comment.url` |
| reviewRequested | `Review pedido: #815` | `<autor do PR> pediu seu review em <título>` | `pr.url` |

- [ ] **Step 1: Testes**

```swift
@Test func firstSnapshotEmitsNothing()
@Test func ciPendingToFailureEmitsOneEventWithChecksURL()        // url termina em "/checks", body contém "unit-tests"
@Test func ciNoneNeverNotifies()                                 // Review Focus 1
@Test func newPushWhilePendingNotifiesOnlyLatestSHAOnce()        // Review Focus 2: old pending sha A, new success sha B → 1 evento; new→newer igual → 0
@Test func approvalFromOtherUserNotifies()
@Test func ownCommentAndBotCommentAreIgnored()
@Test func multipleNewCommentsBecomeOneEvent()                   // title "3 comentários novos em #812"
@Test func prThatDisappearsAndReturnsDoesNotReplayHistory()      // Review Focus 3: comentário/review com data < old.fetchedAt
@Test func newReviewRequestNotifies()
@Test func eventsAfterLongOfflineGapNotifyOnce()                 // Review Focus 5
```

- [ ] **Step 2:** `swift test --filter TransitionEngineTests` → FAIL.
- [ ] **Step 3:** Implementar `TransitionEngine.events(from:to:)`.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): adiciona motor de transições das notificações`

---

### Task 5: Persistência do estado

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Persistence/SnapshotStore.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/SnapshotStoreTests.swift`

**Interfaces:**
- Produces: `actor SnapshotStore { init(fileURL: URL); func load() -> Snapshot?; func save(_ snapshot: Snapshot) throws }` e `static func defaultURL() -> URL` = `~/Library/Application Support/PRumo/snapshot.json`.

- [ ] **Step 1: Testes** `roundTripsSnapshot`, `missingFileReturnsNil`, `corruptFileReturnsNil` (arquivo com `"{"` → `nil`, não lança), `saveIsAtomic` (usa `.atomic`; diretório criado se não existir). Diretório temporário por teste.
- [ ] **Step 2:** `swift test --filter SnapshotStoreTests` → FAIL.
- [ ] **Step 3:** Implementar com `JSONEncoder` (`.iso8601`, `.sortedKeys`).
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): persiste o último estado em disco`

---

### Task 6: Token (gh CLI e Keychain)

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Auth/TokenSource.swift`, `Auth/GhCLITokenSource.swift`, `Auth/ProcessRunner.swift`, `Auth/TokenResolver.swift`
- Create: `PRumo/Services/KeychainTokenStore.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/TokenResolverTests.swift`

**Interfaces:**
- Produces:
  - `protocol ProcessRunner: Sendable { func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String) }`
  - `struct GhCLITokenSource { init(runner: ProcessRunner, candidatePaths: [String] = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"]); func token() async -> String? }` (procura o primeiro caminho existente; status 0 e stdout não vazio, com trim)
  - `protocol TokenStore: Sendable { func read() -> String?; func write(_ token: String) throws; func delete() throws }`
  - `enum TokenOrigin: String, Codable { case ghCLI, pasted }`
  - `struct TokenResolver { init(store: TokenStore, gh: GhCLITokenSource); func resolve() async -> (token: String, origin: TokenOrigin)? }`: Keychain primeiro (token salvo vence), senão `gh`.
  - App: `struct KeychainTokenStore: TokenStore` com `kSecClassGenericPassword`, service `dev.aglv.prumo`, account `github-token`.

- [ ] **Step 1: Testes** `prefersStoredToken`, `fallsBackToGh`, `ghNonZeroExitReturnsNil`, `ghNotInstalledReturnsNil`, `trimsNewline` (stdout `"gho_abc\n"` → `"gho_abc"`), com runner e store fakes.
- [ ] **Step 2:** `swift test --filter TokenResolverTests` → FAIL.
- [ ] **Step 3:** Implementar; `ProcessRunner` real com `Process` e `Pipe`, timeout de 5 s.
- [ ] **Step 4:** `swift test` → PASS. Para `KeychainTokenStore`: `xcodebuild ... build` → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat(auth): resolve token pelo gh cli ou pelo keychain`

---

### Task 7: Apresentação das linhas

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Presentation/RowPresentation.swift`, `Presentation/Badge.swift`, `Presentation/RelativeAge.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/RowPresentationTests.swift`

**Interfaces:**
- Produces:
  - `enum StatusDot: Equatable { case ok, running, failed, attention }` (verde, amarelo, vermelho, laranja)
  - `enum BadgeTone: Equatable { case positive, negative, pending, warning, neutral }`
  - `enum BadgeIcon: Equatable { case none, comments, conflict, clock }`
  - `struct Badge: Equatable { text: String; tone: BadgeTone; icon: BadgeIcon }`
  - `struct RowPresentation: Equatable { dot: StatusDot; title: String; subtitle: String; badges: [Badge] }`
  - `enum RowPresenter { static func mine(_ pr: PullRequest, viewer: String, now: Date) -> RowPresentation; static func review(_ pr: PullRequest, now: Date) -> RowPresentation }`
  - `enum RelativeAge { static func string(from: Date, now: Date) -> String }`: `"40min"`, `"5h"`, `"3d"` (menos de 1 min → `"agora"`).

Regras de `dot`: CI falha → `failed`; alterações pedidas pendentes → `attention`; CI pendente → `running`; senão `ok`. Precedência nessa ordem.
Badges de `mine`, nesta ordem, só quando aplicáveis: CI (`✓ CI 12/12` positive, `✗ unit-tests` negative, `● CI 4/9` pending), aprovações (`✓ 2 aprovações` / `✓ 1 aprovação`, positive), `alterações pedidas` (negative), `draft` (neutral), `conflito` (warning, icon conflict), comentários (`"3"`, neutral, icon comments).
Badges de `review`: autor (neutral), CI, `+212 −48` (neutral). `subtitle` = `"org/repo #n · <idade>"`.

- [ ] **Step 1: Testes** `failedCIWinsOverChangesRequested`, `badgesForSuccessfulPRWithApprovals` (igual a `[Badge("✓ CI 12/12", .positive, .none), Badge("✓ 2 aprovações", .positive, .none), Badge("3", .neutral, .comments)]`), `noCIBadgeWhenCIIsNone`, `singularApproval`, `reviewRowShowsAuthorCIAndDiff`, `relativeAgeBuckets` (59 s → "agora", 40 min → "40min", 5 h → "5h", 3 d → "3d").
- [ ] **Step 2:** `swift test --filter RowPresentationTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): define a apresentação das linhas de PR`

---

### Task 8: Identidade visual no app

**Files:**
- Create: `scripts/render-icons.swift`, `PRumo/Resources/Assets.xcassets/AppIcon.appiconset/*`, `PRumo/Resources/Assets.xcassets/MenuBarGlyph.imageset/` (SVG com "Preserve Vector Data" e "Render As Template"), `PRumo/Views/Brand/BrandColors.swift`, `PRumo/Views/Brand/Wordmark.swift`

**Interfaces:**
- Produces: `extension Color { static let prumoSand, prumoSandDeep, prumoCharcoal, prumoCaramel, prumoPopoverBackground /* claro #fbf8f2, escuro #252322 */ }`; `struct Wordmark: View { init(size: CGFloat) }`; imagem `"MenuBarGlyph"`.

- [ ] **Step 1:** `scripts/render-icons.swift` lê `docs/mockups/pull-request-carbon.svg`, desenha o ícone claro (degradê areia `#f3e6cf`→`#d9c3a0`, cantos 22%, símbolo escalado a 64% e centralizado, primeiro `path` em caramelo, segundo em carvão) e grava os PNGs 16…1024 em `AppIcon.appiconset` com o `Contents.json`.
- [ ] **Step 2:** `swift scripts/render-icons.swift` → 10 PNGs gerados; `xcodebuild ... build` → `BUILD SUCCEEDED`.
- [ ] **Step 3:** `Wordmark`: `Text("PR").foregroundStyle(.prumoCaramel) + Text("umo")`, `.font(.system(size: size, weight: .bold))`, `.tracking(-0.03 * size)`. `MenuBarGlyph`: os dois paths do SVG, template.
- [ ] **Step 4: Ação do usuário (registrar no handoff):** a variante escura "carimbo" e a tinted do ícone exigem o Icon Composer (GUI). O executor só deixa o claro pronto e lista essa pendência ao final.
- [ ] **Step 5: Commit** `feat(brand): adiciona ícone, glifo da barra e logotipo`

---

### Task 9: AppModel, polling e notificações

**Files:**
- Create: `PRumo/AppModel.swift`, `PRumo/AppConstants.swift`, `PRumo/Services/NotificationService.swift`
- Create: `PRumoKit/Sources/PRumoKit/Polling/RefreshCoordinator.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/RefreshCoordinatorTests.swift`

**Interfaces:**
- Consumes: `GitHubClient`, `SnapshotStore`, `TransitionEngine`, `TokenResolver`
- Produces:
  - Kit: `enum ConnectionState: Equatable { case ok, offline(lastSuccess: Date?), unauthorized, rateLimited(resetAt: Date?) }`
  - Kit: `actor RefreshCoordinator { init(fetch: @Sendable () async throws(GitHubError) -> Snapshot, store: SnapshotStore); func refresh() async -> (snapshot: Snapshot?, events: [NotificationEvent], state: ConnectionState) }`: carrega o salvo, busca, calcula eventos contra o salvo, salva o novo. Em erro, devolve o snapshot salvo, `[]` e o estado do erro; não sobrescreve o salvo.
  - App: `@Observable @MainActor final class AppModel { var snapshot: Snapshot?; var connection: ConnectionState; var lastRefresh: Date?; var needsOnboarding: Bool; func start(); func refreshNow(); func signOut() }`. Loop `Task` com `refreshInterval` (UserDefaults `refreshInterval`, padrão 60). Para quando `connection == .unauthorized`.
  - App: `final class NotificationService: NSObject, UNUserNotificationCenterDelegate { func requestAuthorization() async -> Bool; func post(_ events: [NotificationEvent]) }`: `threadIdentifier = event.threadID`, `userInfo["url"]`; no clique, `NSWorkspace.shared.open(url)`.

- [ ] **Step 1: Testes do coordinator** `firstRefreshSavesBaselineWithoutEvents`, `secondRefreshEmitsEventsAndSaves`, `unauthorizedKeepsStoredSnapshotAndEmitsNothing` (Review Focus 4), `offlineThenBackComparesAgainstStoredSnapshot` (Review Focus 5).
- [ ] **Step 2:** `swift test --filter RefreshCoordinatorTests` → FAIL.
- [ ] **Step 3:** Implementar o coordinator, depois `AppModel` e `NotificationService`.
- [ ] **Step 4:** `swift test` → PASS; `xcodebuild ... build` → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat(app): atualiza periodicamente e dispara notificações`

---

### Task 10: Barra de menu e popover

**Files:**
- Create: `PRumo/Views/MenuBarLabel.swift`, `Views/Popover/PopoverView.swift`, `PRRowView.swift`, `BadgeView.swift`, `StatusBanner.swift`
- Modify: `PRumo/PRumoApp.swift`

**Interfaces:**
- Consumes: `AppModel`, `RowPresenter`, `Wordmark`, `Color.prumo*`, `MenuBarGlyph`

Comportamento (mockups `docs/mockups/visao-geral.html` e `fluxo-claro-escuro.html`, passos 3, 4 e 11):
- `MenuBarLabel`: `MenuBarGlyph` + número de `toReview.count` (oculto quando 0) + ponto vermelho de 5 pt se algum `mine` tem `ci` falho.
- `PopoverView` com largura 390: cabeçalho (ícone 20 pt, `Wordmark(size: 13)`, botão atualizar `arrow.clockwise`), `Picker` segmentado "Meus PRs" / "Revisar" com contador caramelo, lista (`ScrollView`, altura máxima 520), rodapé "Atualizado há Ns" e "Ajustes" (`SettingsLink`).
- `StatusBanner` acima da lista: offline → "Sem conexão. Mostrando dados de HH:mm. Tentando de novo em Ns." (ícone `exclamationmark.triangle`); unauthorized → "Token inválido. Conectar de novo" (abre onboarding); rateLimited → "Limite da API do GitHub. Volta às HH:mm".
- Estado vazio por aba: "Nenhum PR aberto" / "Nenhum review pedido".
- `PRRowView`: dot 9 pt, título (2 linhas no máximo), subtítulo, badges (`BadgeView` com SF Symbol por `BadgeIcon`), clique abre `pr.url`. Hover com fundo levemente mais escuro.
- Skeleton de carregamento enquanto `snapshot == nil` e sem erro.

- [ ] **Step 1:** Implementar as views.
- [ ] **Step 2:** `xcodebuild ... build` → `BUILD SUCCEEDED`.
- [ ] **Step 3:** Rodar o app com o token real (`gh` logado). Verificar: ícone na barra, contador, as duas abas com os PRs reais, clique abre o navegador, tema claro e escuro (Ajustes do Sistema → Aparência).
- [ ] **Step 4: Commit** `feat(app): adiciona barra de menu e popover com as abas`

---

### Task 11: Onboarding e Ajustes

**Files:**
- Create: `PRumo/Views/Onboarding/OnboardingView.swift`, `PRumo/Views/Settings/SettingsView.swift`, `PRumo/Services/LaunchAtLogin.swift`
- Modify: `PRumo/PRumoApp.swift` (janela `Window("Bem-vindo ao PRumo", id: "onboarding")`, cena `Settings`), `PRumo/AppModel.swift`

**Interfaces:**
- Consumes: `TokenResolver`, `GhCLITokenSource`, `KeychainTokenStore`, `GitHubClient`, `NotificationService.requestAuthorization()`
- Produces: `enum LaunchAtLogin { static var isEnabled: Bool { get }; static func set(_ enabled: Bool) throws }` sobre `SMAppService.mainApp`.

Fluxo (mockup `fluxo-claro-escuro.html`, passos 1 a 3):
1. Boas-vindas: ícone 72 pt, `Wordmark(size: 22)`, "Seus PRs e reviews na barra de menu." Se o `gh` devolver token, valida com `fetchSnapshot` e mostra "✓ Encontrei o GitHub CLI logado como @login" + "Usar esta conta" / "Usar outro token".
2. Token: campo seguro, "Escopos: repo, read:org. Fica guardado no Keychain.", link "Criar token no GitHub ↗" para `https://github.com/settings/tokens/new?scopes=repo,read:org&description=PRumo`. "Conectar" valida antes de salvar; erro → "Token inválido ou sem os escopos necessários."
3. Pede permissão de notificação.
4. "Tudo pronto": toggle "Abrir ao iniciar o macOS" (ligado), texto "O PRumo fica no canto da barra de menu. Na primeira leitura não dispara notificação pelo que já existe; só pelo que mudar depois.", botão "Começar".

Ajustes (abas do `Settings`): **Conta** (login, origem do token, "Desconectar" apaga Keychain e snapshot e volta ao onboarding); **Geral** (intervalo: 30 s, 60 s, 2 min, 5 min; abrir ao iniciar); **Sobre** (versão, "Símbolo pull-request do IBM Carbon, licença Apache 2.0", link para a licença).

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** `xcodebuild ... build` → `BUILD SUCCEEDED`.
- [ ] **Step 3:** Teste manual: apagar o item do Keychain e `~/Library/Application Support/PRumo`, abrir o app → onboarding com `gh`; "Usar outro token" com token inválido → mensagem de erro; desconectar nos Ajustes → volta ao onboarding.
- [ ] **Step 4: Commit** `feat(app): adiciona onboarding e ajustes`

---

### Task 12: Verificação ponta a ponta

**Files:** nenhum código novo; correções que surgirem entram no commit da task de origem.

- [ ] **Step 1:** `cd PRumoKit && swift test` → todos PASS.
- [ ] **Step 2:** `xcodegen generate && xcodebuild -scheme PRumo -destination 'platform=macOS' build` → `BUILD SUCCEEDED`, sem warnings de concorrência do Swift 6.
- [ ] **Step 3:** Com o app rodando e a conta real: abrir um PR de teste num repositório pessoal com GitHub Actions; confirmar 1 notificação de CI ao terminar; comentar a partir de outra conta ou pedir para alguém comentar → notificação; comentar com a própria conta → nada; fechar e abrir o app → nada repetido.
- [ ] **Step 4:** Desligar o Wi-Fi → banner de sem conexão com os últimos dados; religar → volta sem rajada.
- [ ] **Step 5:** Listar no handoff: pendência do Icon Composer (variante escura e tinted) e qualquer desvio da spec.
