# PRumo: Etapa 2 (Claude no terminal) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A partir de um PR no PRumo, abrir uma sessão do Claude Code no terminal configurado, numa worktree do PR, com o prompt de revisão ou de correção de CI já pronto.

**Architecture:** Toda a lógica (parse de remote, descoberta de clones, templates, plano de comandos git, montagem do comando do terminal, orquestração) fica no `PRumoKit` atrás do `ProcessRunner` da etapa 1, testável com fakes. O app só adiciona o menu `⋯`, o "corrigir" no badge, a ação na notificação, a aba Claude nos Ajustes e a limpeza das worktrees depois de cada refresh.

**Tech Stack:** Swift 6.4, SwiftUI, Swift Testing, `git` e `open`/`osascript` via `ProcessRunner`, `UNNotificationCategory`.

**Spec:** `docs/superpowers/specs/2026-11-05-prumo-design.md`, seção "Claude no terminal" e etapa 2 da "Ordem de entrega". Mockup: `docs/mockups/claude.html` (opções A e C).

**Base:** branch `feat/etapa-2-claude`, criada a partir de `feat/etapa-1-nucleo` (PR #1 ainda aberto).

## Global Constraints

- Tudo da etapa 1 continua valendo (macOS 26, sem sandbox, ad-hoc, sem comentários no código, types e constantes em arquivos próprios, copy em PT-BR, Conventional Commits sem trailer).
- Pasta raiz dos clones: padrão `~/Code`, configurável. Busca até 3 níveis de profundidade, ignorando `node_modules`, `.build`, `DerivedData`, `vendor` e pastas que começam com `.`.
- Pasta das worktrees: padrão `~/Code/.prumo-worktrees`, configurável. Nome: `<repo>-<número>` (só o nome do repo, sem a org; ex.: `web-app-809`).
- Template de revisão padrão: `/code-review {numero}`.
- Template de CI padrão: `A CI do PR #{numero} ({repo}) falhou no job {job}. Leia o log com gh run view {run} --log-failed, encontre a causa e corrija.`
- Variáveis: `{numero}`, `{url}`, `{repo}` (`org/repo`), `{branch}`, `{titulo}`, `{job}`, `{run}`. Variável desconhecida fica como está no texto.
- Flags extras do `claude`: padrão vazio. Nunca adicionar `--dangerously-skip-permissions` por conta própria.
- Terminais: Ghostty (padrão), Terminal, iTerm, personalizado (template com `{dir}` e `{cmd}`).
- Símbolo do Claude: asset `ClaudeMark` (SVG, sem template rendering), cor `#D97757`. Botões dessa ação: fundo `#fff3ec` / texto `#a4492c` no claro; no escuro fundo `#3a2a22` / texto `#e8a487`.
- Textos: "Revisar com Claude", "Corrigir CI com Claude", "corrigir" (no badge), "Corrigir com Claude" (na notificação).
- Worktree removida quando o PR sai das listas (mergeado ou fechado), só se `git status --porcelain` vier vazio.

## Review Focus

1. **Branch do PR já em uso no clone principal**: `git worktree add` falha com "already checked out". Esperado: abrir o terminal no caminho onde a branch já está, sem criar worktree. Teste na Task 4.
2. **PR vindo de fork** (`isCrossRepository`): não dá para dar push na branch. Esperado: revisão funciona (worktree destacada em `pull/<n>/head`); "Corrigir CI" usa a mesma worktree destacada e o prompt ganha o aviso "O PR vem de um fork; não faça push." Teste nas Tasks 4 e 6.
3. **Texto com aspas, `$` e crase no título ou no template**: o comando do terminal não pode quebrar nem executar nada. Esperado: quoting seguro para shell e para AppleScript. Teste na Task 5.
4. **Worktree com mudanças não commitadas quando o PR fecha**: não apagar. Teste na Task 4.
5. **Clone não encontrado e repositório com vários clones** (`~/Code/x/web-app` e `~/Code/y/web-app`): sem clone, o app pede a pasta uma vez e guarda; com vários, usa o primeiro por ordem alfabética do caminho e permite trocar nos Ajustes. Teste na Task 2.

---

### Task 1: Dados do PR para a sessão

**Files:**
- Modify: `PRumoKit/Sources/PRumoKit/GitHub/Queries.swift`, `GitHub/GraphQLResponse.swift`, `GitHub/PullRequestMapper.swift`, `Model/PullRequest.swift`
- Modify: fixtures `search-mine.json`, `search-review.json`
- Test: `PRumoKit/Tests/PRumoKitTests/PullRequestMapperTests.swift`, `SnapshotStoreTests.swift`

**Interfaces:**
- Produces: em `PullRequest`, `headRefName: String`, `isCrossRepository: Bool`, `failedRunID: Int?` (Codable com default ao decodificar snapshot antigo: `""`, `false`, `nil`).

A query passa a pedir `headRefName isCrossRepository` no PR e `detailsUrl` em `CheckRun`. `failedRunID` sai do `detailsUrl` do primeiro CheckRun com falha, pelo padrão `/actions/runs/(\d+)/`.

- [ ] **Step 1: Testes** `mapsHeadRefAndForkFlag`, `failedRunIDFromDetailsURL` (`https://github.com/globex/web-app/actions/runs/1234567/job/89` → `1234567`), `failedRunIDNilForExternalCI` (detailsUrl de outro domínio), `oldSnapshotWithoutNewFieldsDecodes`.
- [ ] **Step 2:** `swift test --filter PullRequestMapperTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): traz branch, fork e run da ci de cada pr`

---

### Task 2: Descoberta de clones

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Claude/RemoteURL.swift`, `Claude/CloneLocator.swift`, `Claude/FileSystem.swift`
- Modify: `PRumoKit/Sources/PRumoKit/Auth/ProcessRunner.swift`, `Auth/GhCLITokenSource.swift`, fakes em `TokenResolverTests.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/CloneLocatorTests.swift`

**Interfaces:**
- Produces:
  - `enum RemoteURL { static func repository(from url: String) -> String? }` → `"org/repo"` em minúsculas, aceita `git@github.com:org/repo.git`, `https://github.com/org/repo(.git)`, `ssh://git@github.com/org/repo.git`; outro host → `nil`.
  - `protocol FileSystem: Sendable { func directories(in url: URL) -> [URL]; func exists(_ url: URL) -> Bool }` e `struct LocalFileSystem: FileSystem`.
  - `struct CloneLocator: Sendable { init(root: URL, fileSystem: FileSystem, runner: ProcessRunner); func scan() async -> [String: [URL]] }`: para cada pasta com `.git` (diretório ou arquivo), roda `git -C <pasta> remote get-url origin` e agrupa por repositório. Profundidade e exclusões da Global Constraints.
  - `enum CloneResolver { static func pick(repository: String, scanned: [String: [URL]], overrides: [String: URL]) -> URL? }`: override vence; senão o primeiro caminho em ordem alfabética.

- [ ] **Step 1: Testes** `parsesSSHAndHTTPSRemotes`, `rejectsOtherHosts`, `scanFindsReposUpToDepth3AndSkipsExcluded`, `worktreeGitFileCountsAsRepo`, `overrideWinsOverScan`, `multipleClonesPickAlphabeticalFirst` (Review Focus 5), `missingRepoReturnsNil`.
- [ ] **Step 2:** `swift test --filter CloneLocatorTests` → FAIL.
- [ ] **Step 3:** Estender o `ProcessRunner` da etapa 1 para devolver `(status: Int32, stdout: String, stderr: String)`, drenando o stderr (resolve o minor da etapa 1), e ajustar `SystemProcessRunner`, `GhCLITokenSource` e os fakes existentes. Depois implementar o locator, com `FileSystem` e `ProcessRunner` fakes nos testes.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): encontra o clone local de cada repositório`

---

### Task 3: Ajustes do Claude e templates

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Claude/ClaudeSettings.swift`, `Claude/TerminalKind.swift`, `Claude/PromptTemplate.swift`, `Claude/ClaudeDefaults.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/PromptTemplateTests.swift`

**Interfaces:**
- Produces:
  - `enum TerminalKind: Codable, Equatable, Sendable { case ghostty, terminal, iterm, custom(template: String) }`
  - `struct ClaudeSettings: Codable, Equatable, Sendable { var reviewTemplate: String; var ciTemplate: String; var extraFlags: String; var terminal: TerminalKind; var clonesRoot: String; var worktreesRoot: String; var cloneOverrides: [String: String]; var removeWorktreeOnClose: Bool; static let defaults: ClaudeSettings }` (valores da Global Constraints em `ClaudeDefaults`).
  - `enum PromptTemplate { static func render(_ template: String, values: [String: String]) -> String }`
  - `enum PromptValues { static func review(_ pr: PullRequest) -> [String: String]; static func ci(_ pr: PullRequest) -> [String: String] }`: `{job}` = primeiro check falho; `{run}` = `failedRunID` ou vazio.

- [ ] **Step 1: Testes** `rendersAllVariables`, `unknownVariableStaysLiteral`, `defaultsMatchSpec` (compara com as strings da Global Constraints), `ciValuesUseFirstFailedCheckAndRun`, `settingsRoundTripCodable`.
- [ ] **Step 2:** `swift test --filter PromptTemplateTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): adiciona ajustes e templates do claude`

---

### Task 4: Worktrees

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Claude/WorktreeManager.swift`, `Claude/SessionPurpose.swift`, `Claude/WorktreeError.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/WorktreeManagerTests.swift`

**Interfaces:**
- Consumes: `ProcessRunner`, `PullRequest` (Task 1)
- Produces:
  - `enum SessionPurpose: Sendable { case review, fixCI }`
  - `enum WorktreeError: Error, Equatable { case gitFailed(String) }`
  - `struct WorktreeManager: Sendable { init(runner: ProcessRunner, worktreesRoot: URL); func prepare(pr: PullRequest, clone: URL, purpose: SessionPurpose) async throws(WorktreeError) -> URL; func removeIfClean(path: URL, clone: URL) async -> Bool }`

Regras de `prepare`:
1. Caminho alvo `worktreesRoot/<repo>-<número>`. Se já existe, faz `git -C <alvo> fetch` e devolve o caminho.
2. `git -C <clone> worktree list --porcelain`: se alguma entrada tem `branch refs/heads/<headRefName>` e o PR não é de fork, devolve o caminho dessa entrada (Review Focus 1).
3. `.fixCI` e `!isCrossRepository`: `git -C <clone> fetch origin <headRefName>` e `git -C <clone> worktree add <alvo> -B <headRefName> origin/<headRefName>`; depois `git -C <alvo> branch --set-upstream-to=origin/<headRefName>`.
4. `.review`, ou PR de fork: `git -C <clone> fetch origin pull/<n>/head` e `git -C <clone> worktree add --detach <alvo> FETCH_HEAD` (Review Focus 2).

`removeIfClean`: `git -C <path> status --porcelain` vazio → `git -C <clone> worktree remove <path>` e devolve `true`; senão `false` (Review Focus 4).

- [ ] **Step 1: Testes** com runner fake que grava os comandos: `fixCIOnOwnBranchCreatesTrackingWorktree`, `reviewUsesDetachedPullHead`, `forkPRAlwaysDetached`, `branchAlreadyCheckedOutReturnsExistingPath`, `existingTargetIsReusedAndFetched`, `gitFailureSurfacesStderr`, `dirtyWorktreeIsKept`, `cleanWorktreeIsRemoved`.
- [ ] **Step 2:** `swift test --filter WorktreeManagerTests` → FAIL.
- [ ] **Step 3:** Implementar. `gitFailed` carrega o `stderr` do comando (o `ProcessRunner` passa a devolvê-lo na Task 2).
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): prepara e limpa worktrees dos prs`

---

### Task 5: Comando do terminal

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Claude/TerminalCommand.swift`, `Claude/ShellQuote.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/TerminalCommandTests.swift`

**Interfaces:**
- Produces:
  - `enum ShellQuote { static func single(_ s: String) -> String }` (aspas simples, `'` vira `'\''`) e `static func appleScriptString(_ s: String) -> String` (escapa `\` e `"`).
  - `struct LaunchCommand: Equatable, Sendable { let executable: String; let arguments: [String] }`
  - `enum TerminalCommand { static func claudeLine(prompt: String, extraFlags: String) -> String; static func build(kind: TerminalKind, directory: URL, line: String) -> LaunchCommand }`

Montagem:
- `claudeLine`: `claude <extraFlags> <ShellQuote.single(prompt)>` (flags vazias não deixam espaço duplo).
- Ghostty: `/usr/bin/open` `["-na", "Ghostty", "--args", "--working-directory=<dir>", "-e", "/bin/zsh", "-lc", "<line>"]`.
- Terminal: `/usr/bin/osascript` `["-e", "tell application \"Terminal\" to do script \"cd <dir> && <line>\"", "-e", "tell application \"Terminal\" to activate"]`, com `cd` usando `ShellQuote.single(dir)` e o script inteiro passando por `appleScriptString`.
- iTerm: `osascript` com `create window with default profile` e `write text`.
- Personalizado: `/bin/zsh -lc <template com {dir} e {cmd} substituídos, ambos com ShellQuote.single>`.

- [ ] **Step 1: Testes** `ghosttyArguments`, `terminalAppleScriptEscapes`, `itermAppleScript`, `customTemplateSubstitutesQuoted`, `quotesSingleQuoteDollarAndBacktick` (prompt `Fix "it" $(rm -rf ~) \`x\` it's` precisa aparecer literal dentro de aspas simples; Review Focus 3), `emptyFlagsNoDoubleSpace`.
- [ ] **Step 2:** `swift test --filter TerminalCommandTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): monta o comando do terminal para o claude`

---

### Task 6: Orquestração da sessão

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Claude/ClaudeLauncher.swift`, `Claude/ClaudeLaunchError.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/ClaudeLauncherTests.swift`

**Interfaces:**
- Consumes: Tasks 2 a 5
- Produces:
  - `enum ClaudeLaunchError: Error, Equatable { case cloneNotFound(repository: String), worktree(String), launchFailed(String) }`
  - `struct ClaudeLauncher: Sendable { init(settings: ClaudeSettings, scanned: [String: [URL]], runner: ProcessRunner); func launch(pr: PullRequest, purpose: SessionPurpose) async throws(ClaudeLaunchError) -> URL }` → devolve o diretório usado.

Fluxo: `CloneResolver.pick` → `WorktreeManager.prepare` → `PromptTemplate.render` (template conforme `purpose`; em PR de fork com `.fixCI`, acrescenta ao prompt ` O PR vem de um fork; não faça push.`) → `TerminalCommand.build` → `runner.run`. Status diferente de 0 no launch → `.launchFailed(stderr)`.

- [ ] **Step 1: Testes** `reviewLaunchesWithReviewTemplateInWorktree`, `fixCIUsesCITemplateWithJobAndRun`, `forkFixCIAppendsNoPushWarning`, `missingCloneThrowsCloneNotFound`, `launchFailureSurfacesStderr`.
- [ ] **Step 2:** `swift test --filter ClaudeLauncherTests` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `feat(kit): orquestra a sessão do claude para um pr`

---

### Task 7: Aba Claude nos Ajustes

**Files:**
- Create: `PRumo/Services/ClaudeSettingsStore.swift`, `PRumo/Views/Settings/ClaudeSettingsView.swift`, `PRumo/Views/Settings/ClaudeSettingsConstants.swift`
- Modify: `PRumo/Views/Settings/SettingsView.swift`, `PRumo/AppModel.swift`, `PRumo/AppConstants.swift`

**Interfaces:**
- Consumes: `ClaudeSettings`, `CloneLocator`
- Produces: `@Observable @MainActor final class ClaudeSettingsStore { var settings: ClaudeSettings; var scanned: [String: [URL]]; func rescan() async; func setOverride(repository: String, path: URL) }`, persistido em UserDefaults (chave `claudeSettings`, JSON). `AppModel` expõe `claude: ClaudeSettingsStore`.

Tela (mockup `docs/mockups/claude.html`, seção "Ajustes › Claude"): campos de template com a linha de variáveis embaixo, flags, picker de terminal (com campo de template quando "Personalizado"), pasta dos clones e das worktrees (com botão "Escolher…" via `NSOpenPanel`), lista "Clones encontrados" (`org/repo → caminho`, botão para trocar o caminho, "Buscar de novo", "+ Adicionar manualmente") e o toggle "Apagar worktree quando o PR fechar". Varredura roda ao abrir a aba e no início do app, fora da main thread.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** `xcodegen generate && xcodebuild ... build` → `BUILD SUCCEEDED`, sem warnings do projeto.
- [ ] **Step 3: Commit** `feat(app): adiciona a aba claude nos ajustes`

---

### Task 8: Menu `⋯`, badge "corrigir" e símbolo do Claude

**Files:**
- Create: `PRumo/Resources/Assets.xcassets/ClaudeMark.imageset/` (SVG + Contents.json), `PRumo/Views/Popover/RowMenu.swift`, `PRumo/Views/Claude/ClaudeButtonStyle.swift`, `PRumo/Views/Claude/ClaudeColors.swift`
- Modify: `PRumo/Views/Popover/PRRowView.swift`, `BadgeView.swift`, `PopoverConstants.swift`, `PRumo/AppModel.swift`

**Interfaces:**
- Consumes: `ClaudeLauncher`, `ClaudeSettingsStore`
- Produces: `AppModel.launchClaude(pr: PullRequest, purpose: SessionPurpose)`: monta o `ClaudeLauncher` com os ajustes atuais e roda; em `.cloneNotFound`, abre `NSOpenPanel` ("Onde está o clone de org/repo?"), grava o override e tenta de novo uma vez; outros erros viram um alerta com a mensagem.

Comportamento (mockup, opções A e C):
- Botão `⋯` aparece no hover da linha (mesmo lugar do mockup da etapa 1) e também pelo botão direito. Itens: primeiro o do Claude, depois "Abrir no navegador" e "Copiar link". Nos meus PRs com CI falhando: "Corrigir CI com Claude". Na aba Revisar: "Revisar com Claude". Nos meus PRs sem CI falhando, não há item do Claude.
- O atalho `⌘K` aparece no item, mas só funciona com o menu aberto; o atalho global com PR selecionado é da etapa de teclado.
- Badge de CI falhando nos meus PRs: ao lado, um botão pequeno "corrigir" com o `ClaudeMark`, cores da Global Constraints; o clique não abre o PR no navegador.
- `ClaudeMark`: SVG de uma fonte oficial que o usuário vai fornecer. Até lá, usar a estrela de 12 raios desenhada no mockup (`docs/mockups/claude.html`), em `#D97757`. Registrar a troca como pendência do usuário.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** `xcodebuild ... build` → `BUILD SUCCEEDED`.
- [ ] **Step 3:** Rodar o app e conferir: hover mostra `⋯`, o menu tem os itens certos por aba, "corrigir" só aparece com CI falhando.
- [ ] **Step 4: Commit** `feat(app): abre o claude pelo menu da linha e pelo badge da ci`

---

### Task 9: "Corrigir com Claude" na notificação

**Files:**
- Modify: `PRumo/Services/NotificationService.swift`, `PRumo/AppModel.swift`
- Create: `PRumo/Services/NotificationCategories.swift`

**Interfaces:**
- Consumes: `NotificationEvent` (`kind`, `pullRequestID`), `AppModel.launchClaude(pr:purpose:)`

Categoria `ci-failed` com ações `abrir` ("Abrir", foreground) e `corrigir-claude` ("Corrigir com Claude", foreground), registrada no início do app. Só eventos `ciFailed` usam a categoria. `userInfo` ganha `pullRequestID`. Na ação `corrigir-claude`, o app procura o PR em `snapshot.mine` pelo id e chama `launchClaude(pr:purpose: .fixCI)`; PR não encontrado → abre a URL.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** `xcodebuild ... build` → `BUILD SUCCEEDED`.
- [ ] **Step 3: Commit** `feat(app): corrige ci com o claude a partir da notificação`

---

### Task 10: Limpeza das worktrees

**Files:**
- Create: `PRumoKit/Sources/PRumoKit/Claude/WorktreeRegistry.swift`
- Modify: `PRumo/AppModel.swift`
- Test: `PRumoKit/Tests/PRumoKitTests/WorktreeRegistryTests.swift`

**Interfaces:**
- Produces: `struct WorktreeRecord: Codable, Equatable, Sendable { let pullRequestID: String; let path: String; let clone: String }`; `actor WorktreeRegistry { init(fileURL: URL); func add(_ r: WorktreeRecord); func records() -> [WorktreeRecord]; func remove(path: String) }` (JSON em `~/Library/Application Support/PRumo/worktrees.json`); `enum WorktreeCleanup { static func stale(records: [WorktreeRecord], snapshot: Snapshot) -> [WorktreeRecord] }` (registro cujo PR não está em `mine` nem em `toReview`).

Só worktrees criadas pelo PRumo entram no registro (caminho dentro de `worktreesRoot`); o caminho devolvido pelo Review Focus 1 (branch já em uso) não entra. Depois de cada refresh com sucesso e com `removeWorktreeOnClose` ligado, o `AppModel` chama `removeIfClean` para cada `stale` e tira do registro as que foram removidas.

- [ ] **Step 1: Testes** `staleWhenPRLeftBothLists`, `notStaleWhileInReview`, `registryRoundTrip`, `externalPathNotRegistered`.
- [ ] **Step 2:** `swift test --filter WorktreeRegistryTests` → FAIL.
- [ ] **Step 3:** Implementar o registro e a chamada no `AppModel`.
- [ ] **Step 4:** `swift test` → PASS; `xcodebuild ... build` → `BUILD SUCCEEDED`.
- [ ] **Step 5: Commit** `feat(app): apaga a worktree quando o pr fecha`

---

### Task 11: Verificação ponta a ponta

- [ ] **Step 1:** `swift test` → todos PASS. `xcodebuild clean build` → `BUILD SUCCEEDED`, zero warnings do projeto.
- [ ] **Step 2 (usuário):** num PR seu com CI falhando, clicar "corrigir" no badge → Ghostty abre em `~/Code/.prumo-worktrees/<repo>-<n>` na branch do PR, com o `claude` rodando o prompt de CI com job e run preenchidos.
- [ ] **Step 3 (usuário):** na aba Revisar, `⋯` → "Revisar com Claude" → worktree destacada e `/code-review <n>`.
- [ ] **Step 4 (usuário):** trocar o terminal para Terminal e depois iTerm nos Ajustes e repetir o passo 3.
- [ ] **Step 5 (usuário):** botão "Corrigir com Claude" na notificação de CI falhou.
- [ ] **Step 6 (usuário):** fazer merge de um PR com worktree limpa → a pasta some depois do próximo refresh; com mudança não commitada, a pasta fica.
- [ ] **Step 7:** listar no handoff a pendência do SVG oficial do `ClaudeMark`.
