# PRumo: Etapa 6 (Teclado) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Usar o PRumo sem mouse: atalho global `⌥⌘P` configurável, busca digitando no popover e navegação e ações nas linhas pelo teclado.

**Architecture:** O kit ganha o modelo do atalho (`HotKeyCombo`), a busca (`SearchMatcher`) e a seleção (`KeyboardSelection`), puros e testados. O app registra o atalho com Carbon, alterna o popover clicando no botão do status item, trata as teclas na `PopoverView` com `onKeyPress` e abre o menu da linha com um `NSMenu` montado a partir das mesmas `RowMenuEntry` do menu `⋯`.

**Decisão do atalho global:** Carbon `RegisterEventHotKey`, sem dependência nova; funciona sem App Sandbox e sem permissão de Acessibilidade, e a biblioteca KeyboardShortcuts seria a única dependência de terceiros do projeto para umas 100 linhas.

**Tech Stack:** Swift 6.4, SwiftUI (`onKeyPress`, `FocusState`), Carbon (`RegisterEventHotKey`, `InstallEventHandler`), AppKit (`NSMenu`, `NSEvent`), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-05-prumo-design.md`, seções "Busca e teclado", "Menu da linha" (atalhos), "Claude no terminal" (`⌘K`), "Popover" (rodapé) e "Ajustes › Exibição" (atalho global).

**Base:** `main`, depois da etapa 5 (usa `RowMenuEntry`/`RowMenuPlan`, `AppModel.perform(_:on:)`, `ListTab`, `MergedPullRequest` e a lista filtrada da etapa 4). Commits direto na `main`.

## Global Constraints

- macOS 26 mínimo. Pacote SwiftPM `PRumoKit` + app `PRumo` gerado pelo XcodeGen (`project.yml`).
- Sem comentários no código.
- Kit: um tipo por arquivo. App: textos, medidas e símbolos em enums `XxxText`/`XxxMetrics`/`XxxSymbol` no `XxxConstants.swift` da pasta; nada de constante ou type solto dentro de view.
- Copy da interface em PT-BR, exatamente como escrita neste plano.
- Identidade da spec: caramelo `#a5713a` (`Color.prumoCaramel`) no contorno da linha selecionada; SF Mono nos atalhos; SF Symbols monocromáticos; nada de emoji.
- Assinatura ad-hoc (`CODE_SIGN_IDENTITY: "-"`), app sem sandbox.
- Nenhuma dependência nova de terceiros.
- Commits direto na `main`, Conventional Commits em PT-BR (minúsculas, imperativo, sem ponto final), sem `Co-Authored-By` e sem menção a IA.
- Kit em TDD com Swift Testing (`@Test`, `#expect`): `cd PRumoKit && swift test`.
- Build do app: `xcodegen generate && xcodebuild -project PRumo.xcodeproj -scheme PRumo -destination 'platform=macOS' build` → `** BUILD SUCCEEDED **`, zero warnings do projeto.
- Testes nunca rodam `git`, `gh` ou `osascript` reais nem chamam a API do GitHub.
- Tudo que é persistido decodifica versões antigas: campo novo com `decodeIfPresent` e default.
- Atalho global padrão `⌥⌘P` (keyCode 35, `kVK_ANSI_P`). Atalhos do popover: `↑` `↓` navegam, `↵` abre, `⌘1` `⌘2` `⌘3` trocam de aba, `⌘.` abre o menu da linha, `⌘K` primeira ação do Claude, `⌘J` Jira, `⌘C` copiar link, `⇧⌘C` copiar checkout, `esc` limpa a busca.

## Review Focus

1. **Atalho já usado por outro app** (`RegisterEventHotKey` falha): aviso `Esse atalho já está em uso.` e o anterior continua registrado. Verificação na Task 3.
2. **Foco no campo de busca**: `⌘C` copia o texto selecionado do campo, não o link da linha; `↑` `↓` `↵` continuam navegando. Verificação na Task 5.
3. **Refresh tira da lista a linha selecionada**: seleção limpa, sem crash e sem pular para outra linha sozinha. Teste na Task 2.
4. **Busca com acento, maiúsculas ou `#`**: `calculo` casa `Corrige cálculo`; `#81` casa o PR 812. Teste na Task 2.
5. **Teclado ABNT2 ou outro layout**: o atalho usa a posição física (keyCode), e o texto mostrado é o caractere capturado na gravação. Teste na Task 1.

---

### Task 1: Modelo do atalho global

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Keyboard/HotKeyModifier.swift`, `Keyboard/HotKeyCombo.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/HotKeyComboTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum HotKeyModifier: String, Codable, CaseIterable, Sendable { case control, option, shift, command }
  public struct HotKeyCombo: Codable, Equatable, Sendable {
      public var keyCode: UInt32; public var key: String; public var modifiers: Set<HotKeyModifier>
      public static let standard: HotKeyCombo
      public var display: String
      public var carbonModifiers: UInt32
      public var isValid: Bool
  }
  ```
  `standard = HotKeyCombo(keyCode: 35, key: "P", modifiers: [.option, .command])`. `display` na ordem do macOS `⌃⌥⇧⌘` + `key` em maiúsculas. `carbonModifiers`: `cmdKey` 256, `shiftKey` 512, `optionKey` 2048, `controlKey` 4096 (valores fixos no kit, sem importar Carbon). `isValid`: tem `.control`, `.option` ou `.command`.

- [ ] **Step 1: Testes** `standardIsOptionCommandP` (`display == "⌥⌘P"`), `displayOrderMatchesMacConvention` (`[.command, .shift, .control]` + `"K"` → `"⌃⇧⌘K"`), `carbonFlags` (`⌥⌘` → 2304), `shiftOnlyIsInvalid`, `displayUsesCapturedKeyNotKeyCode` (keyCode 35 com `key: "Ç"` → `"⌥⌘Ç"`; Review Focus 5), `roundTripCodable`.
- [ ] **Step 2:** `swift test --filter HotKeyComboTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): modelo do atalho global`

---

### Task 2: Busca e seleção

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Keyboard/SearchMatcher.swift`, `Keyboard/MoveDirection.swift`, `Keyboard/KeyboardSelection.swift`
- Test: `SearchMatcherTests.swift`, `KeyboardSelectionTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum SearchMatcher {
      public static func matches(_ pr: PullRequest, query: String) -> Bool
      public static func matches(_ merged: MergedPullRequest, query: String) -> Bool
  }
  public enum MoveDirection: Sendable { case up, down }
  public enum KeyboardSelection {
      public static func move(from current: String?, in ids: [String], direction: MoveDirection) -> String?
      public static func validated(_ current: String?, in ids: [String]) -> String?
  }
  ```

Busca: normaliza com `folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)`; divide por espaços; cada termo precisa casar título, repositório (`contains`) ou número (termo sem `#` inicial, só dígitos, e `String(number).hasPrefix(termo)`). Consulta vazia casa tudo.

Seleção: `move` de `nil` para baixo → primeiro; para cima → último; nas pontas fica parado (sem dar a volta); lista vazia → `nil`. `validated` devolve `nil` se o id sumiu.

- [ ] **Step 1: Testes** `matchesTitleIgnoringCaseAndAccents`, `matchesRepository` (`"web-app"`), `matchesNumberWithHash` (`"#81"` → PR 812), `allTermsMustMatch`, `emptyQueryMatchesAll`, `matchesMergedPullRequest`, `downFromNoneSelectsFirst`, `upFromNoneSelectsLast`, `clampsAtEnds`, `emptyListGivesNil`, `selectionDroppedWhenRowDisappears` (Review Focus 3).
- [ ] **Step 2:** `swift test --filter "SearchMatcherTests|KeyboardSelectionTests"` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): busca e seleção por teclado`

---

### Task 3: Atalho global

**Files:**
- Create: `PRumo/Services/GlobalHotKey.swift`, `PRumo/Services/StatusItemToggle.swift`, `PRumo/Views/Settings/HotKeyRecorder.swift`
- Modify: `PRumo/AppConstants.swift` (`hotKeyKey = "globalHotKey"`), `PRumo/AppModel.swift`, `PRumo/PRumoApp.swift`, `PRumo/Views/Settings/SettingsView.swift`, `SettingsConstants.swift`, `PRumo/Views/Popover/PopoverView.swift` (rodapé)

**Interfaces:**
- Consumes: `HotKeyCombo` (Task 1)
- Produces:
  - `@MainActor final class GlobalHotKey { init(onPress: @escaping @MainActor () -> Void); func register(_ combo: HotKeyCombo) -> Bool; func unregister() }`: `InstallEventHandler` uma vez para `kEventHotKeyPressed` no `GetApplicationEventTarget()`, `RegisterEventHotKey(combo.keyCode, combo.carbonModifiers, ...)`; status diferente de `noErr` → `false`.
  - `@MainActor enum StatusItemToggle { static func toggle() -> Bool }`: procura em `NSApp.windows` a janela cuja classe contém `NSStatusBarWindow`, pega o `NSStatusBarButton` dela e chama `performClick(nil)`; sem botão → `false`.
  - `AppModel.hotKey: HotKeyCombo` (UserDefaults, JSON, padrão `.standard`) e `AppModel.setHotKey(_:) -> Bool`: registra o novo; se falhar, registra de novo o anterior e devolve `false`.

Gravador nos Ajustes (aba Geral, linha `Atalho global`): botão com `combo.display` em SF Mono; clique → `Digite o atalho…` e um monitor local de `keyDown` (`NSEvent.addLocalMonitorForEvents`). `esc` cancela. Tecla sem `⌘`, `⌥` ou `⌃` → `Use ⌘, ⌥ ou ⌃ no atalho.`. Falha de registro → `Esse atalho já está em uso.` (Review Focus 1). `key` vem de `event.charactersIgnoringModifiers?.uppercased()`. Botão `Restaurar padrão`.

Rodapé do popover: `Atualizado há 30s · ⌥⌘P` (o atalho em SF Mono).

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Rodar o app com outro app em foco: `⌥⌘P` abre o popover, de novo fecha. Se `performClick` não abrir a janela do `MenuBarExtra` no macOS 26, parar e reportar ao usuário; não trocar o `MenuBarExtra` por `NSStatusItem` nesta task.
- [ ] **Step 4:** Gravar `⌃⌥⌘K` nos Ajustes, sair e abrir o app: o atalho novo funciona e o rodapé mostra `⌃⌥⌘K`.
- [ ] **Step 5: Commit** `feat(app): abre o popover pelo atalho global`

---

### Task 4: Busca no popover

**Files:**
- Create: `PRumo/Views/Popover/SearchField.swift`
- Modify: `PRumo/Views/Popover/PopoverView.swift`, `PopoverConstants.swift`

**Interfaces:**
- Consumes: `SearchMatcher` (Task 2), filtros da etapa 4

- A `PopoverView` fica `.focusable()` com `.focusEffectDisabled()` e foco inicial ao abrir.
- Com o campo escondido, `onKeyPress` de caractere imprimível sem `⌘`/`⌃` mostra o campo abaixo da barra de filtros, com o caractere digitado, e passa o foco para ele.
- Placeholder: `Buscar por título, repositório ou número`. Botão `xmark.circle.fill` limpa.
- A busca vale para as três abas e para "Mergeados hoje", depois dos filtros da etapa 4; os contadores das abas mostram o resultado da busca.
- Sem resultado na aba: `Nada encontrado para “<busca>”`.
- `esc` com busca preenchida limpa e esconde o campo; `esc` sem busca deixa o sistema fechar o popover.
- A busca é limpa quando o popover fecha.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Rodar o app: abrir, digitar `812` → só o PR 812, contadores atualizados; `esc` limpa.
- [ ] **Step 4: Commit** `feat(app): busca nas três abas digitando no popover`

---

### Task 5: Navegação e ações pelo teclado

**Files:**
- Create: `PRumo/Views/Popover/RowMenuNSMenu.swift`, `PRumo/Views/Popover/RowFramePreference.swift`
- Modify: `PRumo/Views/Popover/PopoverView.swift`, `PRRowView.swift`, `PopoverConstants.swift`, `RowMenuEntry+Presentation.swift`

**Interfaces:**
- Consumes: `KeyboardSelection` (Task 2), `RowMenuPlan`/`RowMenuEntry` e `AppModel.perform(_:on:)` (etapas 3 e 4)
- Produces:
  - `@MainActor enum RowMenuNSMenu { static func show(entries: [RowMenuEntry], at point: NSPoint, in view: NSView, perform: @escaping (RowMenuEntry) -> Void) }`: monta um `NSMenu` com os mesmos títulos e `keyEquivalent` de `RowMenuEntry+Presentation` (`.separator` → `NSMenuItem.separator()`), ícone do Claude nas entradas `.claude`.
  - `struct RowFramePreference: PreferenceKey` (`[String: CGRect]` em coordenadas da janela) para posicionar o menu.

Comportamento:
- `@State selectedID: String?` na `PopoverView`, sobre os ids visíveis da aba atual na ordem mostrada (seções da etapa 4 achatadas). `↓`/`↑` → `KeyboardSelection.move`; mudança na lista → `validated`. `ScrollViewReader` mantém a linha visível.
- Linha selecionada: contorno caramelo de 1,5 pt com cantos de 6 pt.
- `↵` → `.openInBrowser`; `⌘1` `⌘2` `⌘3` → Meus PRs, Revisar, Merge (limpa a seleção); `⌘K` → primeira entrada `.claude` da linha (sem nenhuma, `NSSound.beep()`); `⌘J` → `.openJira` quando existe; `⌘C` → `.copyLink`; `⇧⌘C` → `.copyCheckout`; `⌘.` → `RowMenuNSMenu.show` no canto inferior esquerdo da linha.
- Com o campo de busca em foco, `⌘C`, `⌘J` e `⇧⌘C` ficam com o campo; `↑` `↓` `↵` `⌘1–3` `⌘K` `⌘.` continuam agindo na lista (Review Focus 2).
- Rodapé com linha selecionada: `↑↓ navegar · ↵ abrir · ⌘. menu · ⌘K Claude` em SF Mono, no lugar de `Atualizado há…`.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** Build do app → `BUILD SUCCEEDED`, zero warnings.
- [ ] **Step 3:** Rodar o app só com teclado: `⌥⌘P`, `↓` `↓`, `⌘.` (menu aparece na linha), `esc`, `⌘K` num PR com CI falhando (abre o Claude), `⌘2`, `↵` (abre o PR).
- [ ] **Step 4: Commit** `feat(app): navega e age nas linhas pelo teclado`

---

### Task 6: Verificação ponta a ponta

- [ ] **Step 1:** `swift test` → todos PASS. `xcodebuild clean build` → `BUILD SUCCEEDED`, zero warnings do projeto.
- [ ] **Step 2 (usuário):** tentar gravar um atalho que outro app já usa (ex.: o do Raycast) → aviso, o anterior continua funcionando.
- [ ] **Step 3 (usuário):** digitar `calculo` e `#81` na busca; selecionar texto do campo e `⌘C` → copia o texto, não o link.
- [ ] **Step 4 (usuário):** com uma linha selecionada, esperar um refresh que tire o PR da lista → seleção some sem erro.

---

## Mudanças durante a execução

- Ajustes com 600 de largura.
- Cores: azul para atenção, cinza para CI rodando, com o badge de CI rodando também cinza.
- Busca sempre visível, embaixo dos filtros.
- Task A: autores de comentário ignorados na aba Comentários.
- Task J: badge do Jira clicável e azul.
