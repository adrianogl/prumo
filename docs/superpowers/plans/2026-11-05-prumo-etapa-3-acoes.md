# PRumo: Etapa 3 (Ações) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completar o menu `⋯` da linha (Jira, re-rodar job que falhou, copiar `gh pr checkout`) e pôr os botões "Abrir" e "Re-rodar" nas notificações.

**Architecture:** Detecção da chave do Jira, montagem do menu (`RowMenuPlan`) e a chamada REST de re-run ficam no `PRumoKit`, testadas com fakes. O app ganha a aba Integrações nos Ajustes, renderiza o menu a partir das entradas do kit e roteia toda ação por um único `AppModel.perform(_:on:)`, que as etapas 4 e 6 reaproveitam.

**Tech Stack:** Swift 6.4, SwiftUI, Swift Testing, `URLSession` via `HTTPTransport`, `UNNotificationCategory`.

**Spec:** `docs/superpowers/specs/2026-11-05-prumo-design.md`, seções "Menu da linha", "Notificações" (tabela), "Ajustes › Integrações" e etapa 5 da "Ordem de entrega" (o usuário antecipou Ações para a etapa 3).

**Base:** `main`. Commits direto na `main`.

## Global Constraints

- macOS 26 mínimo. Pacote SwiftPM `PRumoKit` + app `PRumo` gerado pelo XcodeGen (`project.yml`).
- Sem comentários no código.
- Kit: um tipo por arquivo. App: textos, medidas e símbolos em enums `XxxText`/`XxxMetrics`/`XxxSymbol` no `XxxConstants.swift` da pasta; nada de constante ou type solto dentro de view.
- Copy da interface em PT-BR, exatamente como escrita neste plano.
- Identidade da spec: caramelo `#a5713a` (`Color.prumoCaramel`) para destaque; cores de status do sistema; SF Symbols monocromáticos; nada de emoji.
- Assinatura ad-hoc (`CODE_SIGN_IDENTITY: "-"`), app sem sandbox.
- Commits direto na `main`, Conventional Commits em PT-BR (minúsculas, imperativo, sem ponto final), sem `Co-Authored-By` e sem menção a IA.
- Kit em TDD com Swift Testing (`@Test`, `#expect`): `cd PRumoKit && swift test`.
- Build do app: `xcodegen generate && xcodebuild -project PRumo.xcodeproj -scheme PRumo -destination 'platform=macOS' build` → `** BUILD SUCCEEDED **`, zero warnings do projeto.
- Testes nunca rodam `git`, `gh` ou `osascript` reais nem chamam a API do GitHub: usar `ProcessRunner` e `HTTPTransport` fakes.
- Tudo que é persistido (snapshot em disco, JSON no UserDefaults) decodifica versões antigas: campo novo com `decodeIfPresent` e default, com teste usando JSON sem o campo.
- Chave do Jira: `<PREFIXO>-<número>`; URL `https://<site>/browse/<CHAVE>`. Padrões: `ON` → `empresa.atlassian.net`, `DEV` → site vazio (o usuário preenche).
- Re-run: `POST https://api.github.com/repos/{owner}/{repo}/actions/runs/{run_id}/rerun-failed-jobs`, headers `Authorization: bearer <token>`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`. Sucesso = HTTP 201.

## Review Focus

1. **Chave em minúsculas ou colada em outra palavra**: branch `feat/on-1234-filtro` → `ON-1234`; `MON-12`, `ON-` e `ABC-1` (prefixo não configurado) não casam. Testes na Task 1.
2. **Prefixo sem site** (o `DEV` padrão): o badge com a chave aparece, mas o item "Abrir card no Jira" não, porque não há URL. Testes nas Tasks 1 e 3.
3. **Falha que vem de CI externa** (StatusContext ou check com `detailsUrl` fora de `/actions/runs/`): sem item "Re-rodar" no menu e notificação sem botão "Re-rodar". Testes nas Tasks 2 e 3.
4. **Primeiro check falho não é do Actions** (StatusContext `lint` antes do CheckRun `unit-tests`): o item diz "unit-tests", não "lint", porque é o job que o run vai re-rodar. Teste na Task 2.
5. **GitHub recusa o re-run** (403 sem permissão ou run em andamento, 404, 401): alerta com o texto da Task 5; o polling segue e o estado de conexão não muda. Teste de mapeamento na Task 2.

---

### Task 1: Chave do Jira

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Jira/JiraSite.swift`, `Jira/JiraSettings.swift`, `Jira/JiraLink.swift`, `Jira/JiraKeyDetector.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/JiraTests.swift`

**Interfaces:**
- Produces:
  - `public struct JiraSite: Codable, Equatable, Identifiable, Sendable { public var id: UUID; public var prefix: String; public var host: String }`
  - `public struct JiraSettings: Codable, Equatable, Sendable { public var sites: [JiraSite]; public static let defaults: JiraSettings; public func link(for pr: PullRequest) -> JiraLink? }`
  - `public struct JiraLink: Equatable, Sendable { public let key: String; public let url: URL? }`
  - `public enum JiraKeyDetector { public static func key(title: String, branch: String, prefixes: Set<String>) -> String? }`

Regras:
- Prefixo normalizado com `trimmingCharacters(.whitespaces)` + `uppercased()`; só vale se casar `^[A-Z][A-Z0-9]*$`. Prefixo inválido é ignorado.
- Token procurado: `\b([A-Za-z][A-Za-z0-9]*)-(\d+)\b`, comparando o prefixo em maiúsculas com o conjunto. Primeiro procura no título, depois na branch. Primeira ocorrência vence. Resultado sempre em maiúsculas.
- Site normalizado: tira espaços, `https://`, `http://` e `/` final. Vazio → `url == nil`.

- [ ] **Step 1: Testes**
  - `detectsKeyInTitle`: título `"feat(pedido): ON-1234 filtro"` → `"ON-1234"`.
  - `detectsLowercaseKeyInBranch`: título sem chave, branch `"feat/on-1234-filtro"` → `"ON-1234"`.
  - `titleWinsOverBranch`: título com `ON-1`, branch com `ON-2` → `"ON-1"`.
  - `ignoresUnconfiguredPrefix`: `"ABC-1"` com prefixos `["ON"]` → `nil`.
  - `ignoresPrefixInsideWord`: `"MON-12"`, `"ON-"` e `"ON-x"` → `nil`.
  - `linkUsesNormalizedHost`: site `" https://empresa.atlassian.net/ "` → `url == URL(string: "https://empresa.atlassian.net/browse/ON-1234")`.
  - `emptyHostGivesKeyWithoutURL`: site `""` para `DEV` → `JiraLink(key: "DEV-7", url: nil)`.
  - `invalidPrefixIsIgnored`: prefixo `"o n"` não reconhece nada.
  - `defaultsMatchSpec`: `defaults.sites.map(\.prefix) == ["ON", "DEV"]`, hosts `["empresa.atlassian.net", ""]`.
  - `settingsRoundTripCodable`.
- [ ] **Step 2:** `swift test --filter JiraTests` → FAIL (tipos não existem).
- [ ] **Step 3:** Implementar os quatro tipos.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): reconhece a chave do jira no título e na branch`

---

### Task 2: Job do Actions que falhou e re-run pela API

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Model/PullRequest.swift`, `GitHub/PullRequestMapper.swift`, `GitHub/GitHubClient.swift`, `Transitions/NotificationEvent.swift`, `Transitions/TransitionEngine.swift`
- Modify: `PRumoKit/Tests/PRumoKitTests/Support/PullRequest+Fixture.swift` (parâmetro `failedRunName: String? = nil`)
- Test: `PullRequestMapperTests.swift`, `SnapshotStoreTests.swift`, `GitHubClientTests.swift`, `TransitionEngineTests.swift`

**Interfaces:**
- Produces:
  - `PullRequest.failedRunName: String?`: nome do mesmo CheckRun de onde sai `failedRunID`; `nil` quando `failedRunID` é `nil`. Parâmetro `failedRunName: String? = nil` no fim do `init`; `decodeIfPresent` no `init(from:)`; `CodingKeys` ganha o caso.
  - `GitHubClient.rerunFailedJobs(repository: String, runID: Int) async throws(GitHubError)`: request da Global Constraints; status passa pelo `check(_:)` existente (401 → `.unauthorized`, 403 sem rate limit → `.server(status: 403)`, 404 → `.server(status: 404)`), erro de transporte → `.network`.
  - `NotificationEvent.failedRunID: Int?`: novo parâmetro `failedRunID: Int? = nil` no `init`. `TransitionEngine` preenche com `new.failedRunID` só no evento `.ciFailed`.

- [ ] **Step 1: Testes**
  - `failedRunNameMatchesRunCheck`: rollup com StatusContext `lint` (FAILURE) seguido de CheckRun `unit-tests` (FAILURE, `detailsUrl` `https://github.com/acme/loja/actions/runs/555/job/9`) → `ci == .failure(failedChecks: ["lint", "unit-tests"], ...)`, `failedRunID == 555`, `failedRunName == "unit-tests"`.
  - `failedRunNameNilForExternalCI`: CheckRun falho com `detailsUrl` de outro domínio → `failedRunID == nil`, `failedRunName == nil`.
  - `oldSnapshotWithoutFailedRunNameDecodes` (em `SnapshotStoreTests`): JSON sem a chave → `failedRunName == nil`.
  - `rerunPostsToRESTEndpoint`: o fake captura o request; `httpMethod == "POST"`, `url == "https://api.github.com/repos/acme/loja/actions/runs/555/rerun-failed-jobs"`, os três headers; resposta 201 não lança.
  - `rerunMaps403ToServer`, `rerunMaps404ToServer`, `rerunMaps401ToUnauthorized`.
  - `ciFailedEventCarriesRunID`: PR pendente → falha com `failedRunID: 555` → evento com `failedRunID == 555`.
  - `ciSucceededEventHasNoRunID`.
- [ ] **Step 2:** `swift test --filter "PullRequestMapperTests|GitHubClientTests|TransitionEngineTests|SnapshotStoreTests"` → FAIL.
- [ ] **Step 3:** Implementar. No mapper, trocar `failedRunID(_:)` por uma função que devolve `(id: Int, name: String)?` a partir do mesmo `first(where: isFailedCheckRun)`. No client, extrair a parte comum de `post(query:variables:)` (envio, `check`) para reaproveitar na chamada REST, sem `checkGraphQLErrors`.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): re-roda os jobs que falharam pela api do github`

---

### Task 3: Entradas do menu da linha e badge do Jira

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Presentation/RowMenuEntry.swift`, `Presentation/RowMenuPlan.swift`
- Modify: `PRumoKit/Sources/PRumoKit/Presentation/RowPresentation.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/RowMenuPlanTests.swift`, `RowPresentationTests.swift`

**Interfaces:**
- Consumes: `JiraLink` (Task 1), `PullRequest.failedRunID`/`failedRunName` (Task 2), `SessionPurpose`
- Produces:
  ```swift
  public enum RowMenuEntry: Equatable, Sendable {
      case claude(SessionPurpose, primary: Bool)
      case openInBrowser
      case openJira(key: String, url: URL)
      case rerunFailedJobs(jobName: String, runID: Int)
      case copyLink
      case copyCheckout(command: String)
      case separator
  }
  public enum RowMenuPlan {
      public static func entries(pr: PullRequest, claudePurposes: [SessionPurpose], jira: JiraLink?) -> [RowMenuEntry]
  }
  ```
  - `RowPresenter.mine(_:viewer:now:jiraKey: String? = nil)` e `RowPresenter.review(_:now:jiraKey: String? = nil)`: com chave, acrescenta `Badge(key, .neutral)` como último badge.

Ordem das entradas (spec, "Menu da linha"): Claude (o primeiro com `primary: true`) e `.separator` só se houver Claude; `.openInBrowser`; `.openJira` só com `jira?.url`; `.rerunFailedJobs` só com `failedRunID != nil` e `ci` em `.failure` (`jobName` = `failedRunName ?? ""`); `.copyLink`; `.copyCheckout(command: "gh pr checkout <número>")`.

- [ ] **Step 1: Testes**
  - `menuOrderWithEverything`: PR com CI falhando (`failedRunID: 555`, `failedRunName: "unit-tests"`), purposes `[.fixCI, .addressComments]`, Jira com URL → `[.claude(.fixCI, primary: true), .claude(.addressComments, primary: false), .separator, .openInBrowser, .openJira(key: "ON-1234", url: …), .rerunFailedJobs(jobName: "unit-tests", runID: 555), .copyLink, .copyCheckout(command: "gh pr checkout 812")]`.
  - `noClaudeNoSeparator`: purposes vazios → começa em `.openInBrowser`.
  - `noJiraEntryWithoutURL`: `JiraLink(key: "DEV-7", url: nil)` → sem `.openJira`.
  - `noRerunWithoutRunID` e `noRerunWhenCINotFailing` (`failedRunID: 555` com `ci: .success`).
  - `jiraBadgeIsLastOnMineAndReview` e `noJiraBadgeWithoutKey`.
- [ ] **Step 2:** `swift test --filter "RowMenuPlanTests|RowPresentationTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): monta o menu da linha com jira, re-rodar e checkout`

---

### Task 4: Aba Integrações nos Ajustes

**Files:**
- Create: `PRumo/Services/IntegrationSettingsStore.swift`, `PRumo/Views/Settings/IntegrationsSettingsView.swift`, `PRumo/Views/Settings/IntegrationsSettingsConstants.swift`
- Modify: `PRumo/Views/Settings/SettingsView.swift`, `PRumo/Views/Settings/SettingsConstants.swift` (`SettingsTab.integrations`), `PRumo/AppConstants.swift` (`jiraSettingsKey = "jiraSettings"`), `PRumo/AppModel.swift`

**Interfaces:**
- Consumes: `JiraSettings`, `JiraLink` (Task 1)
- Produces: `@Observable @MainActor final class IntegrationSettingsStore { var jira: JiraSettings; init(defaults: UserDefaults = .standard); func link(for pr: PullRequest) -> JiraLink? }`, JSON em `UserDefaults` na chave `jiraSettings`, gravado no `didSet`; decode que falha → `.defaults`. `AppModel` expõe `let integrations: IntegrationSettingsStore` (injetável no `init`, como `claude`).

Tela (aba "Integrações", símbolo `link`, entre Claude e Sobre):
- Seção "Jira", com a nota "Chaves reconhecidas no título ou na branch do PR."
- Uma linha por site: campo "Prefixo" (vira maiúsculas ao sair do campo), campo "Site" com placeholder `empresa.atlassian.net`, botão `minus.circle` para remover.
- Linha com site vazio mostra embaixo, em secundário: "Sem site: a chave aparece na linha, mas não abre."
- Botão "Adicionar prefixo".

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app (Global Constraints) → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Rodar o app: a aba mostra `ON → empresa.atlassian.net` e `DEV` vazio; editar, fechar e reabrir os Ajustes mantém o valor.
- [ ] **Step 4: Commit** `feat(app): adiciona a aba integrações com os sites do jira`

---

### Task 5: Menu da linha com as novas ações

**Files:**
- Create: `PRumo/Views/Popover/RowMenuConstants.swift`, `PRumo/Views/Popover/RowMenuEntry+Presentation.swift`
- Modify: `PRumo/Views/Popover/RowActions.swift`, `RowMenuItems.swift`, `RowMenuButton.swift`, `PRRowView.swift`, `PopoverView.swift`, `PRumo/AppModel.swift`

**Interfaces:**
- Consumes: `RowMenuPlan`, `RowMenuEntry`, `RowPresenter(..., jiraKey:)` (Task 3), `IntegrationSettingsStore.link(for:)` (Task 4), `GitHubClient.rerunFailedJobs` (Task 2)
- Produces:
  - `struct RowActions { let entries: [RowMenuEntry]; let perform: (RowMenuEntry) -> Void }` (substitui `claudePurposes`/`launch`).
  - `extension RowMenuEntry { var title: String; var keyboardShortcut: KeyboardShortcut? }` em `RowMenuEntry+Presentation.swift`.
  - `AppModel.perform(_ entry: RowMenuEntry, on pr: PullRequest)`: único ponto de execução das ações da linha (as etapas 4 e 6 usam).
  - `AppModel.rerunFailedJobs(pr: PullRequest, runID: Int)` e `AppModel.isRerunning(_ pr: PullRequest) -> Bool` (conjunto `rerunning`, como `launching`).

Títulos e atalhos (`RowMenuText`):

| Entrada | Título | Atalho |
| --- | --- | --- |
| `.openInBrowser` | `Abrir no navegador` | `↵` (`.return`, sem modificador) |
| `.openJira` | `Abrir card no Jira: ON-1234` | `⌘J` |
| `.rerunFailedJobs` | `Re-rodar job que falhou: unit-tests` (sem nome: `Re-rodar job que falhou`) | nenhum |
| `.copyLink` | `Copiar link` | `⌘C` |
| `.copyCheckout` | `Copiar gh pr checkout 812` | `⇧⌘C` |
| `.claude` | títulos atuais de `SessionPurpose` | `⌘K` só em `primary` |

`perform`: `.claude` → `launchClaude`; `.openInBrowser` e `.openJira` → `NSWorkspace.shared.open`; cópias → `NSPasteboard`; `.rerunFailedJobs` → `rerunFailedJobs`; `.separator` → nada. `RowMenuItems` vira um `ForEach` sobre `entries` (separador vira `Divider`); item de re-run desabilitado enquanto `isRerunning`.

`rerunFailedJobs`: chama o client fora da main; sucesso → `refreshNow()`. Erro → `NSAlert` com título `Não foi possível re-rodar o job` e mensagem:
- `.server(403)`: `O GitHub recusou: sem permissão para re-rodar jobs em <org/repo> ou o run ainda está rodando.`
- `.server(404)`: `Run <id> não encontrado em <org/repo>.`
- `.unauthorized`: `Token inválido. Conecte de novo pelo popover.`
- `.network`: `Sem conexão com o GitHub.`
- `.rateLimited`: `Limite da API do GitHub. Tente de novo mais tarde.`
- outros: `O GitHub respondeu com erro (HTTP <status>).`

O alerta não altera `connection` (Review Focus 5).

`PopoverView` passa `jiraKey: model.integrations.link(for: pr)?.key` para os presenters.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Rodar o app e conferir: PR com `ON-xxxx` no título ou na branch mostra o badge e o item do Jira (abre `https://empresa.atlassian.net/browse/ON-xxxx`); PR com CI do Actions falhando mostra "Re-rodar job que falhou: <job>"; "Copiar gh pr checkout <n>" põe o texto no clipboard.
- [ ] **Step 4: Commit** `feat(app): abre o jira, re-roda job e copia o checkout pelo menu da linha`

---

### Task 6: Botões nas notificações

**Files:**
- Modify: `PRumo/Services/NotificationCategories.swift`, `PRumo/Services/NotificationService.swift`, `PRumo/AppModel.swift`

**Interfaces:**
- Consumes: `NotificationEvent.failedRunID` (Task 2), `AppModel.rerunFailedJobs` (Task 5)
- Produces: `NotificationService.onRerun: @MainActor (String, URL) -> Void` (id do PR, URL da notificação).

Categorias (registradas no `init`, como hoje):

| Categoria | Quando | Ações |
| --- | --- | --- |
| `ci-failed` (id mantido) | `.ciFailed` com `failedRunID` | `abrir` "Abrir", `re-rodar` "Re-rodar", `corrigir-claude` "Corrigir com Claude" |
| `ci-failed-no-run` | `.ciFailed` sem `failedRunID` | `abrir` "Abrir", `corrigir-claude` "Corrigir com Claude" |
| `pr` | todos os outros tipos | `abrir` "Abrir" |

Todas as ações com `.foreground`. Ação `re-rodar`: o `AppModel` procura o PR em `snapshot.mine` pelo id; com `failedRunID` → `rerunFailedJobs`; sem PR ou sem run → abre a URL. "Silenciar" entra na etapa 4 (depende do silenciar por PR), nas duas categorias de CI e na de conflito da etapa 5.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3: Commit** `feat(app): adiciona abrir e re-rodar nos botões das notificações`

---

### Task 7: Verificação ponta a ponta e ordem de entrega

**Files:**
- Modify: `docs/superpowers/specs/2026-11-05-prumo-design.md` (seção "Ordem de entrega")

- [ ] **Step 1:** `swift test` → todos PASS. `xcodebuild clean build` → `BUILD SUCCEEDED`, zero warnings do projeto.
- [ ] **Step 2 (usuário):** preencher o site do `DEV` em Ajustes › Integrações e abrir um card `DEV-…` pelo menu `⋯` e pelo `⌘J` com o menu aberto.
- [ ] **Step 3 (usuário):** num PR com CI do Actions falhando, "Re-rodar job que falhou" → a CI volta para rodando no próximo refresh.
- [ ] **Step 4 (usuário):** notificação "CI falhou" com botão "Re-rodar"; uma notificação de aprovação mostra só "Abrir".
- [ ] **Step 5:** Atualizar a lista da "Ordem de entrega" na spec para a ordem escolhida: 3 Ações, 4 Organização, 5 Ruído sob controle, 6 Teclado, 7 Widget.
- [ ] **Step 6: Commit** `docs: atualiza a ordem de entrega na spec`
