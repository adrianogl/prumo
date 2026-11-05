# PRumo: Etapa 5 (Ruído sob controle) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar controle sobre as notificações: Não perturbe, horário de trabalho, lembrete de review parado, notificações de pronto para merge e de conflito, e um toggle por tipo.

**Architecture:** O kit ganha os eventos novos no `TransitionEngine`, a política de silêncio (`QuietPolicy`), o rastreador de reviews parados e um `NotificationPipeline` puro que recebe os eventos brutos e decide o que é entregue e quais lembretes ficam marcados. O app só guarda as preferências, chama o pipeline depois de cada refresh e mostra o botão de Não perturbe e a aba Notificações.

**Tech Stack:** Swift 6.4, SwiftUI, Swift Testing, `UserNotifications`.

**Spec:** `docs/superpowers/specs/2026-11-05-prumo-design.md`, seções "Notificações", "Não perturbe e horário de trabalho", "Como o app sabe o que mudou" (pronto para merge, conflito, pausas e review parado) e "Ajustes › Notificações". Mockup: `docs/mockups/visao-geral.html` (notificações e ajustes).

**Base:** `main`, depois da etapa 4 (usa `MergeReadiness`, `ReviewInclusion`, `RowMarks`, `OrganizationStore`, `FilterContext.staleLimit` e a categoria de notificação com "Silenciar"). Commits direto na `main`.

## Global Constraints

- macOS 26 mínimo. Pacote SwiftPM `PRumoKit` + app `PRumo` gerado pelo XcodeGen (`project.yml`).
- Sem comentários no código.
- Kit: um tipo por arquivo. App: textos, medidas e símbolos em enums `XxxText`/`XxxMetrics`/`XxxSymbol` no `XxxConstants.swift` da pasta; nada de constante ou type solto dentro de view.
- Copy da interface em PT-BR, exatamente como escrita neste plano.
- Identidade da spec: caramelo `#a5713a` (`Color.prumoCaramel`) para destaque; cores de status do sistema; SF Symbols monocromáticos (Não perturbe = sino com Z, espera = relógio); nada de emoji.
- Assinatura ad-hoc (`CODE_SIGN_IDENTITY: "-"`), app sem sandbox.
- Commits direto na `main`, Conventional Commits em PT-BR (minúsculas, imperativo, sem ponto final), sem `Co-Authored-By` e sem menção a IA.
- Kit em TDD com Swift Testing (`@Test`, `#expect`): `cd PRumoKit && swift test`.
- Build do app: `xcodegen generate && xcodebuild -project PRumo.xcodeproj -scheme PRumo -destination 'platform=macOS' build` → `** BUILD SUCCEEDED **`, zero warnings do projeto.
- Testes nunca rodam `git`, `gh` ou `osascript` reais nem chamam a API do GitHub: usar `ProcessRunner` e `HTTPTransport` fakes. Testes de data usam `Calendar` com fuso `America/Sao_Paulo` fixo.
- Tudo que é persistido (snapshot em disco, JSON no UserDefaults, `reminders.json`) decodifica versões antigas: campo novo com `decodeIfPresent` e default, com teste usando JSON sem o campo.
- Não perturbe: opções "por 1 hora", "até amanhã às 9h" (dia seguinte do calendário, 09:00 local) e "até eu reativar". Durante a pausa o app atualiza os dados, mas descarta as notificações; ao sair da pausa, as do período não aparecem.
- Horário de trabalho: desligado por padrão; quando ligado, padrão seg–sex, 9h–18h (fim exclusivo). Fora dele, o app age como Não perturbe.
- Review parado: padrão 24 h, relógio corrido, uma vez por pedido. Se vencer durante uma pausa, sai no primeiro refresh depois da pausa, não é descartado. Pedido ao time lembra quando "Incluir reviews pedidos ao time" está ligado; drafts ignorados e PRs silenciados não lembram.
- Pronto para merge: regra do `MergeReadiness` da etapa 4 (inclui o caso sem branch protection: uma aprovação basta e PR sem checks conta como CI verde).

## Review Focus

1. **`mergeable` oscilando** `MERGEABLE → UNKNOWN → CONFLICTING` entre dois refreshes, ou `CONFLICTING → UNKNOWN → CONFLICTING` depois de um push: conflito notifica uma vez, só na entrada real. Teste na Task 1.
2. **Review vence durante o Não perturbe**: lembrete adiado para o primeiro refresh depois da pausa, uma vez só; os outros eventos do período continuam descartados. Teste na Task 4.
3. **Primeira execução com reviews antigos** (ou reinstalação): nenhum lembrete pelo estado que já existia. Teste na Task 4.
4. **Horário com fim antes do início** (ex.: 18h–9h): não pode silenciar tudo. Esperado: tratado como "sempre dentro" no kit e bloqueado na tela. Testes na Task 2, validação na Task 7.
5. **Tipo desligado e depois religado**: os lembretes de review parado que venceram enquanto o tipo estava desligado não saem todos de uma vez. Teste na Task 4.

---

### Task 1: Eventos de pronto para merge e de conflito

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/Transitions/NotificationEvent.swift`, `Transitions/TransitionEngine.swift`, `Model/Snapshot.swift`, `Model/PullRequest.swift`, `Polling/RefreshCoordinator.swift`
- Test: `TransitionEngineTests.swift`, `RefreshCoordinatorTests.swift`

**Interfaces:**
- Consumes: `MergeReadiness.isReady(_:viewer:)` (etapa 4)
- Produces:
  - `NotificationKind` ganha `readyToMerge`, `conflict`, `staleReview`.
  - `PullRequest.with(mergeable: Mergeable) -> PullRequest` (cópia).
  - `Snapshot.keepingKnownMergeable(from old: Snapshot?) -> Snapshot`: em `mine` e `toReview`, PR com `.unknown` herda o valor conhecido (`.mergeable` ou `.conflicting`) do mesmo id em `old`. O coordinator aplica antes do engine e antes de salvar.

Eventos (por PR que já existia em `old.mine`, depois dos de comentário):
- `.conflict`: `old.mergeable != .conflicting` e `new.mergeable == .conflicting`. Título `#<n> entrou em conflito`; corpo `<título> · conflito com <base>` (base vazia → só o título); URL do PR.
- `.readyToMerge`: `!isReady(old)` e `isReady(new)`. Título `#<n> pronto para merge`; corpo `Aprovado, CI <t>/<t> e sem conflito` com CI em sucesso, `Aprovado e sem conflito` sem checks; URL do PR.

- [ ] **Step 1: Testes** `enteringConflictNotifies`, `conflictBodyWithoutBaseIsTitle`, `becomingReadyNotifiesOnce`, `alreadyReadyDoesNotRenotify`, `readyBodyWithoutChecks`, `readyWithoutBranchProtectionNotifies` (`reviewDecision: nil`, uma aprovação), `unknownKeepsPreviousKnownMergeable`, `conflictNotifiesOnceAcrossUnknown` (sequência M → U → C notifica uma vez; C → U → C não notifica; Review Focus 1, no `RefreshCoordinatorTests` com fetch fake devolvendo os três snapshots).
- [ ] **Step 2:** `swift test --filter "TransitionEngineTests|RefreshCoordinatorTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): notifica pronto para merge e entrada em conflito`

---

### Task 2: Não perturbe e horário de trabalho

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Quiet/DoNotDisturb.swift`, `Quiet/WorkingHours.swift`, `Quiet/QuietPolicy.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/QuietPolicyTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum DoNotDisturb: Codable, Equatable, Sendable {
      case off, until(Date), indefinite
      public static func oneHour(from now: Date) -> DoNotDisturb
      public static func untilTomorrowMorning(from now: Date, calendar: Calendar) -> DoNotDisturb
      public func isActive(at now: Date) -> Bool
      public func normalized(at now: Date) -> DoNotDisturb
  }
  public struct WorkingHours: Codable, Equatable, Sendable {
      public var enabled = false; public var weekdays: Set<Int> = [2, 3, 4, 5, 6]
      public var startMinute = 540; public var endMinute = 1080
      public var isValid: Bool { startMinute < endMinute }
      public func contains(_ date: Date, calendar: Calendar) -> Bool
  }
  public enum QuietPolicy { public static func isQuiet(now: Date, dnd: DoNotDisturb, hours: WorkingHours, calendar: Calendar) -> Bool }
  ```
  `weekdays` usa o `Calendar.weekday` (1 = domingo). `contains` com `isValid == false` devolve `true`. `isQuiet` = `dnd.isActive(at:)` ou (`hours.enabled` e `!hours.contains`). `normalized` troca `until` vencido por `.off`.

- [ ] **Step 1: Testes** `oneHourEndsSixtyMinutesLater`, `untilTomorrowIsNextCalendarDayNineAM` (de 2026-11-05 23:30 → 2026-11-06 09:00; de 2026-11-06 00:30 → 2026-11-07 09:00), `expiredUntilIsInactiveAndNormalizesToOff`, `indefiniteStaysActive`, `insideWorkingHoursIsNotQuiet` (qui 10:00), `endIsExclusive` (qui 18:00 → quieto), `weekendIsQuiet` (sáb 10:00), `disabledWorkingHoursNeverQuiet`, `invalidRangeTreatedAsAlwaysInside` (Review Focus 4), `roundTripCodable`.
- [ ] **Step 2:** `swift test --filter QuietPolicyTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): adiciona não perturbe e horário de trabalho`

---

### Task 3: Review parado

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Reminders/StaleReminder.swift`, `Reminders/StaleReviewTracker.swift`, `Reminders/ReminderState.swift`, `Reminders/ReminderStore.swift`
- Modify: `Presentation/RowPresentation.swift`, `Presentation/PresentationConstants.swift`
- Test: `StaleReviewTests.swift`, `RowPresentationTests.swift`

**Interfaces:**
- Consumes: `ReviewRequestTarget` (etapa 4)
- Produces:
  ```swift
  public struct StaleReminder: Equatable, Sendable { public let key: String; public let event: NotificationEvent }
  public enum StaleReviewTracker {
      public static func key(for pr: PullRequest) -> String
      public static func due(snapshot: Snapshot, limit: TimeInterval, reminded: Set<String>, muted: Set<String>, ignoreDrafts: Bool, includeTeam: Bool, now: Date) -> [StaleReminder]
  }
  public struct ReminderState: Codable, Equatable, Sendable {
      public var initialized = false; public var reminded: [String] = []
      public mutating func insert(_ keys: [String])
  }
  public actor ReminderStore { public init(fileURL: URL); public static func defaultURL() -> URL; public func load() -> ReminderState; public func save(_ state: ReminderState) throws }
  ```
  - `key`: `"<id>@<Int(início.timeIntervalSince1970)>"`, com início = `reviewRequestedAt ?? createdAt`. Pedido novo depois de um re-review gera chave nova.
  - `due`: PRs de `toReview` (`.you`, e `.team` quando `includeTeam`), fora de `muted`, sem draft quando `ignoreDrafts`, espera ≥ `limit`, chave fora de `reminded`. Evento `.staleReview`, título `Review parado há <h>h: #<n>` (h = horas inteiras), corpo `<autor> pediu seu review em <título>`, URL do PR.
  - `insert` sem duplicar e mantendo só as 500 chaves mais novas.
  - `ReminderStore.defaultURL()`: `~/Library/Application Support/PRumo/reminders.json`. Arquivo ausente ou inválido → `ReminderState()`.
  - `RowPresenter.review(_:now:jiraKey:staleLimit: TimeInterval? = nil)`: espera ≥ limite → acrescenta `Badge("esperando há <h>h", .warning, .clock)` e a bolinha vira `.attention` (CI falhando continua `.failed`).

- [ ] **Step 1: Testes** `dueAfterLimitOnlyOnce`, `notDueBeforeLimit`, `teamRequestDueWhenIncluded`, `teamRequestNeverDueWhenExcluded`, `mutedNeverDue`, `draftSkippedWhenIgnoring`, `newRequestGetsNewKey`, `titleUsesWholeHours` (26h30 → `Review parado há 26h: #798`), `stateCapsAt500KeepingNewest`, `storeRoundTripAndMissingFile`, `reviewRowShowsWaitBadgeAndAttentionDot`.
- [ ] **Step 2:** `swift test --filter "StaleReviewTests|RowPresentationTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): lembra review parado uma vez por pedido`

---

### Task 4: Preferências e pipeline de notificações

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Notifications/NotificationToggle.swift`, `Notifications/NotificationPreferences.swift`, `Notifications/NotificationPipeline.swift`, `Notifications/PipelineResult.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/NotificationPipelineTests.swift`

**Interfaces:**
- Consumes: Tasks 2 e 3
- Produces:
  ```swift
  public enum NotificationToggle: String, Codable, CaseIterable, Sendable {
      case ci, approved, changesRequested, newComment, reviewRequested, staleReview, readyToMerge, conflict
      public init(kind: NotificationKind)
  }
  public struct NotificationPreferences: Codable, Equatable, Sendable {
      public var disabled: Set<NotificationToggle> = []
      public var groupByPullRequest = true
      public var staleReviewHours = 24
      public var dnd: DoNotDisturb = .off
      public var workingHours = WorkingHours()
      public func isEnabled(_ kind: NotificationKind) -> Bool
  }
  public struct PipelineResult: Equatable, Sendable { public let deliver: [NotificationEvent]; public let reminders: ReminderState }
  public enum NotificationPipeline {
      public static func run(events: [NotificationEvent], snapshot: Snapshot, preferences: NotificationPreferences,
                             muted: Set<String>, ignoreDrafts: Bool, includeTeam: Bool, reminders: ReminderState,
                             now: Date, calendar: Calendar) -> PipelineResult
  }
  ```
  `NotificationToggle(kind:)`: `ciFailed` e `ciSucceeded` → `.ci`; os outros pelo nome. Guardar `disabled` (e não `enabled`) faz tipo novo nascer ligado.

Regras do `run`, em ordem:
1. `quiet = QuietPolicy.isQuiet(...)`. Quieto → nenhum evento de transição entra em `deliver`.
2. Fora do silêncio, entram os eventos com tipo ligado e PR fora de `muted`.
3. `reminders.initialized == false` ou `reminders.viewer != snapshot.viewer` → recomeça com `ReminderState(viewer: snapshot.viewer)`; todas as chaves de `StaleReviewTracker.due` vão para `reminded`, nada é entregue e `initialized` vira `true` (Review Focus 3).
4. Quieto → lembretes não são calculados nem marcados (adiados; Review Focus 2).
5. Fora do silêncio → todos os `due` são marcados; só entram em `deliver` se `.staleReview` estiver ligado (Review Focus 5).

- [ ] **Step 1: Testes** `quietDropsTransitionEvents`, `mutedDropped`, `disabledKindDropped`, `ciToggleCoversFailedAndSucceeded`, `firstRunMarksExistingStaleWithoutDelivering`, `staleDuringQuietIsPostponedNotDropped` (quieto: nada; mesmo estado fora do silêncio: entrega uma vez; terceira chamada: nada), `disabledStaleToggleMarksWithoutDelivering`, `emptyJSONDecodesDefaults` (`{}` → `staleReviewHours == 24`, `groupByPullRequest == true`, `dnd == .off`, `workingHours.enabled == false`), `newKindsDefaultOn`.
- [ ] **Step 2:** `swift test --filter NotificationPipelineTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): decide o que notificar com tipos, silêncio e lembretes`

---

### Task 5: Pipeline no app

**Files:**
- Create: `PRumo/Services/NotificationPreferencesStore.swift`
- Modify: `PRumo/AppModel.swift`, `PRumo/AppConstants.swift` (`notificationPreferencesKey = "notificationPreferences"`), `PRumo/Services/NotificationService.swift`, `PRumo/Services/NotificationCategories.swift`, `PRumo/Views/Popover/PopoverView.swift`, `PRumo/Views/Popover/Filters/FilterPicker.swift`

**Interfaces:**
- Consumes: `NotificationPipeline`, `ReminderStore` (Tasks 3 e 4), `OrganizationStore` (etapa 4)
- Produces:
  - `@Observable @MainActor final class NotificationPreferencesStore { var preferences: NotificationPreferences; init(defaults: UserDefaults = .standard); var isQuiet: Bool; func refreshQuiet(now: Date) }`; `isQuiet` recalculado no `refreshQuiet` (chamado a cada refresh e a cada minuto pelo `TimelineView` do cabeçalho), que também aplica `dnd.normalized`.
  - `AppModel.preferences: NotificationPreferencesStore`; `AppModel` guarda um `ReminderStore(fileURL: ReminderStore.defaultURL())`.
  - `NotificationService.post(_ events: [NotificationEvent], grouped: Bool)`: `grouped == false` → `threadIdentifier` vazio.

`runRefresh`, depois de um resultado `.ok`: atividade nova com os eventos brutos (como na etapa 4), `NotificationPipeline.run(...)` com `muted` de `organization.settings.marks`, grava o `ReminderState` devolvido e posta `deliver`. Resultado de erro não chama o pipeline.

Lembretes: o `ReminderState` fica em memória no `AppModel` (carregado do `ReminderStore` uma vez, gravado a cada refresh). O `signOut` zera o estado em memória e grava um `ReminderState()` vazio no arquivo. `ReminderState.viewer` guarda a conta dona da base: trocar de conta sem passar pelo `signOut` (reconectar no onboarding, `gh auth switch` seguido de reinício) refaz a base sem entregar nada, e estado antigo sem `viewer` também é refeito na primeira passada.

Categorias: `conflict` com `abrir` "Abrir" e `silenciar` "Silenciar" para `.conflict`; `.readyToMerge` e `.staleReview` usam a categoria `pr` (só "Abrir").

`staleLimit`: `PopoverView` passa `TimeInterval(preferences.staleReviewHours * 3600)` para `RowPresenter.review(..., staleLimit:)` e para `FilterContext.staleLimit`; o rótulo `parado há +<h>h` do filtro e do chip usa o mesmo valor.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3: Commit** `feat(app): aplica não perturbe, horário, lembretes e toggles nas notificações`

---

### Task 6: Botão de Não perturbe no cabeçalho

**Files:**
- Create: `PRumo/Views/Popover/DoNotDisturbButton.swift`
- Modify: `PRumo/Views/Popover/PopoverView.swift`, `PopoverConstants.swift`

**Interfaces:**
- Consumes: `NotificationPreferencesStore` (Task 5), `DoNotDisturb` (Task 2)

- Ícone: `bell` com `zzz` pequeno sobreposto no canto superior direito; caramelo quando `isQuiet`, secundário quando não. Fica entre o logotipo e o botão de atualizar.
- Menu: `Por 1 hora`, `Até amanhã às 9h`, `Até eu reativar`; com Não perturbe ativo, divisor e `Reativar notificações` (volta para `.off`).
- Tooltip: `Não perturbe`; ativo até hoje → `Não perturbe até HH:mm`; até outro dia → `Não perturbe até amanhã às HH:mm`; indefinido → `Não perturbe até você reativar`; quieto só pelo horário → `Fora do horário de trabalho`.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Rodar o app: ativar "Por 1 hora" → ícone caramelo e tooltip com o horário; reiniciar o app mantém o estado.
- [ ] **Step 4: Commit** `feat(app): adiciona o botão de não perturbe no cabeçalho`

---

### Task 7: Aba Notificações nos Ajustes

**Files:**
- Create: `PRumo/Views/Settings/NotificationsSettingsView.swift`, `PRumo/Views/Settings/NotificationsSettingsConstants.swift`
- Modify: `PRumo/Views/Settings/SettingsView.swift`, `SettingsConstants.swift` (`SettingsTab.notifications`)

**Interfaces:**
- Consumes: `NotificationPreferencesStore` (Task 5)

Aba `Notificações` (símbolo `bell`, depois de Geral):
- Toggles, na ordem: `CI terminou nos meus PRs` (`.ci`), `Meu PR foi aprovado`, `Alterações pedidas`, `Comentário novo`, `Novo pedido de review`, `Review parado`, `PR pronto para merge`, `PR entrou em conflito`.
- `Lembrar review parado após`: `4 h`, `8 h`, `24 h`, `48 h` (desabilitado com "Review parado" desligado).
- `Agrupar notificações de CI` (`groupByPullRequest`).
- `Só em horário de trabalho`; ligado mostra os dias (`D S T Q Q S S`, botões alternáveis) e `Das` / `às` (`DatePicker` só com hora e minuto). Fim igual ou antes do início mostra `O fim precisa ser depois do início.` em vermelho e não grava o horário (Review Focus 4).

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3: Commit** `feat(app): adiciona os ajustes de notificações`

---

### Task 8: Verificação ponta a ponta

- [ ] **Step 1:** `swift test` → todos PASS. `xcodebuild clean build` → `BUILD SUCCEEDED`, zero warnings do projeto.
- [ ] **Step 2 (usuário):** ativar Não perturbe "Por 1 hora", provocar um evento (comentário num PR seu) → nada aparece; reativar → o comentário antigo não aparece, só os seguintes.
- [ ] **Step 3 (usuário):** baixar "Lembrar review parado após" para 4 h com um review pedido há mais tempo → um lembrete `Review parado há <h>h: #<n>`; o próximo refresh não repete.
- [ ] **Step 4 (usuário):** PR aprovado com CI verde → `#<n> pronto para merge`; conflito → `#<n> entrou em conflito` com "Abrir" e "Silenciar".
- [ ] **Step 5 (usuário):** desligar "Comentário novo" e conferir que comentários não notificam, mas a bolinha de novo continua acendendo.
