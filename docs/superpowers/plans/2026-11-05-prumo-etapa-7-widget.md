# PRumo: Etapa 7 (Widget) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Widgets pequeno e médio do PRumo na Central de Notificações e na mesa, se der para compartilhar dados entre o app e a extensão com conta gratuita e assinatura ad-hoc.

**Architecture:** A Task 1 é um spike que decide se a etapa existe. Se um container compartilhado funcionar, o kit resume o snapshot num `WidgetSnapshot` pequeno, o app grava esse JSON no container e pede reload ao WidgetKit, e a extensão `PRumoWidget` só lê e desenha. Se o spike falhar, a etapa termina na Task 1 com o resultado registrado na spec.

**Tech Stack:** Swift 6.4, WidgetKit, SwiftUI, XcodeGen (target `app-extension`), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-05-prumo-design.md`, seção "Widget" e etapa 7 da "Ordem de entrega". Mockup: `docs/mockups/visao-geral.html`, seção "Widgets".

**Base:** `main`, depois da etapa 6 (usa `Counters`, `MergeReadiness`, `RowMarks` da etapa 4 e `NotificationPreferences.staleReviewHours` da etapa 5). Commits direto na `main`.

## Global Constraints

- macOS 26 mínimo. Pacote SwiftPM `PRumoKit` + app `PRumo` e extensão `PRumoWidget` gerados pelo XcodeGen (`project.yml`).
- Sem comentários no código.
- Kit: um tipo por arquivo. App e widget: textos, medidas e símbolos em enums `XxxText`/`XxxMetrics`/`XxxSymbol` no `XxxConstants.swift` da pasta; nada de constante ou type solto dentro de view.
- Copy da interface em PT-BR, exatamente como escrita neste plano.
- Identidade da spec: logotipo "PRumo" com "PR" em caramelo `#a5713a`; contadores em caramelo; fundo do widget segue claro/escuro (`#fbf8f2` / `#252322`); cores de status do sistema; nada de emoji.
- Assinatura ad-hoc (`CODE_SIGN_IDENTITY: "-"`) no app e na extensão. App sem sandbox; a extensão do widget com App Sandbox (exigência do WidgetKit). Ad-hoc não tem Team ID, então App Group com prefixo de Team ID não se aplica.
- Commits direto na `main`, Conventional Commits em PT-BR (minúsculas, imperativo, sem ponto final), sem `Co-Authored-By` e sem menção a IA.
- Kit em TDD com Swift Testing (`@Test`, `#expect`): `cd PRumoKit && swift test`.
- Build: `xcodegen generate && xcodebuild -project PRumo.xcodeproj -scheme PRumo -destination 'platform=macOS' build` → `** BUILD SUCCEEDED **`, zero warnings do projeto.
- Testes nunca rodam `git`, `gh` ou `osascript` reais nem chamam a API do GitHub.
- Tudo que é persistido (incluindo o JSON do widget) decodifica versões antigas: campo novo com `decodeIfPresent` e default.
- Widget pequeno: "para revisar" e "CI falhando". Médio: "para revisar", "CI falhando", "prontos p/ merge" e até três PRs que pedem ação; clique no PR abre o PR.
- Contadores seguem as regras da barra de menu: "para revisar" conta só pedidos para você (sem time, sem drafts quando ignorados).

## Review Focus

1. **Assinatura ad-hoc sem Team ID**: App Group pode não valer, e a extensão pode nem aparecer na galeria. Decidido pelo spike da Task 1, com critério objetivo e saída documentada.
2. **App fechado ou sem rede**: o widget mostra o último dado com `Atualizado às HH:mm` e não zera os contadores. Teste na Task 2 (decode) e verificação na Task 4.
3. **Link vindo do widget com URL fora do GitHub**: ignorado. Teste na Task 2.
4. **Conta desconectada**: o widget volta para `Conecte sua conta no PRumo`. Verificação na Task 3.
5. **Dado igual a cada refresh de 60 s**: não grava nem pede reload, para não gastar o orçamento de reloads do WidgetKit. Verificação na Task 3.

---

### Task 1: Spike do container compartilhado

**Files:**
- Modify: `project.yml` (target `PRumoWidget`, dependência de embed no `PRumo`)
- Create: `PRumoWidget/Info.plist` (`NSExtension` → `NSExtensionPointIdentifier` = `com.apple.widgetkit-extension`), `PRumoWidget/PRumoWidget.entitlements`, `PRumoWidget/SpikeWidget.swift`
- Modify: `PRumo/Resources/PRumo.entitlements` (só na variante A), `PRumo/AppModel.swift` (escrita temporária do spike)
- Modify ao final: `docs/superpowers/specs/2026-11-05-prumo-design.md`, seção "Widget"

Target no `project.yml`: `PRumoWidget`, `type: app-extension`, `platform: macOS`, bundle `dev.aglv.prumo.widget`, `ENABLE_APP_SANDBOX: YES`, `CODE_SIGN_IDENTITY: "-"`, `CODE_SIGN_STYLE: Manual`, dependência `PRumoKit`. O app depende do target com `embed: true`.

O widget do spike tem só `.systemSmall` e mostra o texto de `spike.txt` (ou `sem dados`).

Critérios (todos precisam passar):
1. Depois de rodar o app uma vez, o widget "PRumo" aparece na galeria de widgets (clique com o botão direito na mesa → "Editar widgets").
2. O widget mostra o texto que o app gravou, e uma troca do texto feita pelo app aparece depois de `WidgetCenter.shared.reloadAllTimelines()`.
3. Funciona de novo depois de sair e abrir o app e de reiniciar o Mac, sem pedido de permissão do macOS a cada abertura (um pedido único "acessar dados de outros apps" é aceitável e deve ser anotado).

Variantes, nesta ordem:
- **A. App Group `group.dev.aglv.prumo`**: entitlement `com.apple.security.application-groups` nos dois targets; app e widget usam `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`; os dois precisam devolver URL não nula e a mesma pasta.
- **B. Container da extensão**: sem App Group; o app (sem sandbox) grava em `~/Library/Containers/dev.aglv.prumo.widget/Data/Library/Application Support/PRumo/`, e o widget lê o próprio `URL.applicationSupportDirectory/PRumo/`.

- [ ] **Step 1:** Criar o target e o widget do spike; build → `BUILD SUCCEEDED`.
- [ ] **Step 2:** Testar a variante A contra os três critérios; anotar o resultado de cada um (o que apareceu, mensagens no Console filtrando por `chronod` e `PRumoWidget`).
- [ ] **Step 3:** Se A falhar, desfazer o entitlement e testar a variante B do mesmo jeito.
- [ ] **Step 4:** Registrar o resultado na seção "Widget" da spec, numa linha: `Spike (<data>): variante <A|B> funcionou com assinatura ad-hoc` ou `Spike (<data>): widget não funciona com assinatura ad-hoc: <critério que falhou e a evidência>`.
- [ ] **Step 5a (funcionou):** remover o texto fixo do spike, manter o target e a variante que passou, e fazer commit `feat(widget): adiciona a extensão do widget com dados compartilhados` (inclui a linha da spec). Seguir para a Task 2.
- [ ] **Step 5b (falhou):** desfazer tudo menos a linha da spec (`git checkout -- project.yml PRumo/` e remover `PRumoWidget/`), build → `BUILD SUCCEEDED`, commit `docs: registra que o widget não funciona com assinatura ad-hoc` e **parar aqui**. As Tasks 2 a 5 não são executadas; avisar o usuário com o critério que falhou.

---

### Task 2: Resumo do widget no kit

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Widget/WidgetReason.swift`, `Widget/WidgetItem.swift`, `Widget/WidgetSnapshot.swift`, `Widget/WidgetSummary.swift`, `Widget/WidgetLink.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/WidgetSummaryTests.swift`

**Interfaces:**
- Consumes: `Counters`, `MergeReadiness`, `ReviewRequestTarget` (etapa 4)
- Produces:
  ```swift
  public enum WidgetReason: String, Codable, Sendable { case ciFailing, staleReview, readyToMerge }
  public struct WidgetItem: Codable, Equatable, Identifiable, Sendable { id: String; number: Int; title: String; url: URL; reason: WidgetReason; waitingHours: Int? }
  public struct WidgetSnapshot: Codable, Equatable, Sendable {
      public var connected: Bool; public var toReview: Int; public var ciFailing: Int; public var readyToMerge: Int
      public var items: [WidgetItem]; public var updatedAt: Date
      public static let disconnected: WidgetSnapshot
  }
  public enum WidgetSummary {
      public static func make(snapshot: Snapshot, ignoreDrafts: Bool, muted: Set<String>, staleLimit: TimeInterval, now: Date) -> WidgetSnapshot
  }
  public enum WidgetLink {
      public static func make(_ url: URL) -> URL
      public static func target(from url: URL) -> URL?
  }
  ```
  - Contadores: `Counters.reviewBadge(snapshot, ignoreDrafts:)`, `mine` com `.failure`, `Counters.readyToMerge`.
  - Itens, sem PRs silenciados, no máximo 3, nesta ordem: CI falhando (`updatedAt` desc), review parado (`.you`, espera ≥ `staleLimit`, maior espera primeiro, `waitingHours` em horas inteiras), pronto para merge (`updatedAt` desc).
  - `WidgetLink.make`: `prumo://open?url=<URL com percent-encoding>`. `target`: só aceita esquema `prumo`, host `open` e URL `https` com host `github.com`; o resto → `nil` (Review Focus 3).
  - Campos de `WidgetSnapshot` com `decodeIfPresent` (`connected` padrão `true`, contadores 0, `items` vazio).

- [ ] **Step 1: Testes** `countsMatchMenuBarRules` (pedido ao time e draft ignorado fora de `toReview`), `itemsOrderedCIThenStaleThenReady`, `capsAtThreeItems`, `mutedNotInItems`, `staleItemHasWholeHours`, `linkRoundTrip`, `linkRejectsNonGitHubURL` (`https://exemplo.com`, `http://github.com/...` e esquema `https` direto → `nil`), `oldWidgetJSONDecodes` (`{"toReview":3}` → `connected == true`, `items == []`).
- [ ] **Step 2:** `swift test --filter WidgetSummaryTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): resume os prs para o widget`

---

### Task 3: App publica os dados e abre os links do widget

**Files:**
- Create: `PRumo/Services/WidgetPublisher.swift`, `PRumo/Services/AppDelegate.swift`
- Modify: `PRumo/AppModel.swift`, `PRumo/PRumoApp.swift` (`@NSApplicationDelegateAdaptor`), `PRumo/Resources/Info.plist` (`CFBundleURLTypes` com esquema `prumo`), `PRumo/AppConstants.swift`

**Interfaces:**
- Consumes: `WidgetSummary`, `WidgetLink` (Task 2), local de gravação da variante vencedora da Task 1
- Produces:
  - `@MainActor final class WidgetPublisher { init(fileURL: URL); func publish(_ snapshot: WidgetSnapshot) }`: grava `widget.json` (ISO 8601, escrita atômica) e chama `WidgetCenter.shared.reloadAllTimelines()` só quando o conteúdo mudou em relação ao último publicado, ignorando `updatedAt` na comparação (Review Focus 5).
  - `AppDelegate.application(_:open:)`: para cada URL, `WidgetLink.target(from:)` → `NSWorkspace.shared.open`; `nil` → ignora.

`AppModel` publica depois de cada refresh `.ok` com `WidgetSummary.make(...)` (preferências e marcações atuais) e publica `WidgetSnapshot.disconnected` no `signOut` (Review Focus 4).

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** `open 'prumo://open?url=https%3A%2F%2Fgithub.com%2Fglobex%2Fweb-app%2Fpull%2F1'` abre o PR no navegador; `open 'prumo://open?url=https%3A%2F%2Fexemplo.com'` não faz nada.
- [ ] **Step 4: Commit** `feat(app): publica os dados do widget e abre prs vindos dele`

---

### Task 4: Telas do widget

**Files:**
- Create: `PRumoWidget/PRumoWidgetBundle.swift`, `PRumoWidget/PRumoWidget.swift`, `PRumoWidget/WidgetProvider.swift`, `PRumoWidget/SmallWidgetView.swift`, `PRumoWidget/MediumWidgetView.swift`, `PRumoWidget/WidgetConstants.swift`
- Delete: `PRumoWidget/SpikeWidget.swift`
- Modify: `project.yml` (o target do widget inclui `PRumo/Views/Brand/Wordmark.swift` e `PRumo/Views/Brand/BrandColors.swift` nas sources)

**Interfaces:**
- Consumes: `WidgetSnapshot`, `WidgetLink` (Task 2), local de leitura da variante da Task 1

- Provider: lê `widget.json`; ausente → `WidgetSnapshot.disconnected`. Uma entrada, política `.after(now + 30 min)` como rede de segurança (o reload normal vem do app). `placeholder` com 3 / 1 / 2 e os três itens do mockup.
- Famílias: `.systemSmall` e `.systemMedium`. Nome na galeria `PRumo`, descrição `Reviews pendentes, CI falhando e PRs prontos para merge.`
- Pequeno: `Wordmark` pequeno; `<n>` em caramelo + `para revisar`; `<n>` + `CI falhando`.
- Médio: os três contadores (`para revisar`, `CI falhando`, `prontos p/ merge`) e até três linhas, cada uma num `Link(destination: WidgetLink.make(item.url))`: CI falhando `#809 feat(pedido): filtro por status` com bolinha vermelha; review parado `#798 reserva por pedido · 26h` com bolinha laranja; pronto `#812 pronto para merge` com bolinha verde. Sem itens: `Nada pedindo ação`.
- Dado com mais de 1 h: rodapé `Atualizado às HH:mm` (Review Focus 2).
- `connected == false`: `Conecte sua conta no PRumo`.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Conferir os dois tamanhos na galeria, no claro e no escuro, contra o mockup.
- [ ] **Step 4: Commit** `feat(widget): mostra contadores e prs que pedem ação`

---

### Task 5: Verificação ponta a ponta

- [ ] **Step 1:** `swift test` → todos PASS. `xcodebuild clean build` → `BUILD SUCCEEDED`, zero warnings do projeto.
- [ ] **Step 2 (usuário):** adicionar os dois widgets; um review novo muda "para revisar" em até um refresh.
- [ ] **Step 3 (usuário):** clicar num PR do widget médio → abre o PR no navegador.
- [ ] **Step 4 (usuário):** sair do PRumo e esperar mais de 1 h → o widget mantém os números com `Atualizado às HH:mm`.
- [ ] **Step 5 (usuário):** desconectar a conta nos Ajustes → `Conecte sua conta no PRumo`.
