<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.svg">
    <img src="docs/assets/logo-light.svg" width="112" alt="Ícone do PRumo">
  </picture>
</p>

<h1 align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/wordmark-dark.svg">
    <img src="docs/assets/wordmark-light.svg" width="200" alt="PRumo">
  </picture>
</h1>

<p align="center">Seus PRs e reviews na barra de menu do macOS.</p>

O PRumo acompanha os PRs que você abriu e os reviews pedidos a você no GitHub. Avisa quando a CI termina, quando aprovam, quando pedem alterações e quando chega comentário. Para CI quebrada, conflito, comentários e revisão, abre o Claude Code no terminal já na branch do PR.

## O que ele faz

**Barra de menu e popover**
- Ícone com a quantidade de reviews pendentes e um ponto vermelho quando algum PR seu está com a CI falhando.
- Abas Meus PRs e Revisar. Cada linha mostra o status da CI, aprovações, alterações pedidas, comentários, draft e conflito.
- Clique na linha abre o PR no navegador. O menu `⋯` (ou o botão direito) tem as ações do Claude, abrir no navegador e copiar link.

**Notificações**
- CI terminou (uma por commit, não por check), PR aprovado, alterações pedidas, comentário novo (de issue ou de review) e review pedido.
- Comentário seu ou de bot não notifica. Na primeira abertura, nada do que já existia vira aviso. Reiniciar o app não repete notificação.

**Claude Code no terminal**

| Situação | Onde aparece | O que o Claude recebe |
| --- | --- | --- |
| Review pedido a você | menu `⋯` na aba Revisar | `/code-review <n>` |
| CI falhando no seu PR | botão "corrigir" no badge, menu `⋯` e notificação | job e run que falharam, com `gh run view --log-failed` |
| PR em conflito | botão "resolver" no badge, menu `⋯` | fazer merge da branch base e resolver os conflitos |
| Comentários ou alterações pedidas | botão "resolver" no badge, menu `⋯` | ler os comentários, aplicar o que fizer sentido e resumir |

Como funciona:
- O app encontra o clone do repositório em `~/Code` pelo `remote`. Se não achar, pergunta a pasta uma vez e confere se ela é mesmo do repositório.
- Cria uma worktree em `~/Code/.prumo-worktrees/<repo>-<n>`. Seu clone principal não muda de branch. Revisão e PR de fork usam worktree destacada; CI, conflito e comentários no seu PR usam a branch real, sem resetar commits locais.
- Abre o terminal configurado rodando um script em `~/Library/Caches/PRumo/sessions/`. Nenhum texto do PR (título, nome de job, branch) é digitado no terminal ou montado numa linha de shell.
- A sessão roda com `zsh -il`, então uma função ou alias do seu `.zshrc` continua valendo. O comando é `claude` por padrão e pode ser trocado (por exemplo, `claude-ems`) em Ajustes › IA.
- A worktree é apagada quando o GitHub confirma que o PR foi fechado ou mergeado, e só se estiver limpa e sem commits não enviados.

Os prompts, o comando e as flags do `claude`, o terminal (Ghostty, Terminal, iTerm ou comando próprio) e as pastas ficam em Ajustes › IA.

## Requisitos

- macOS 26 ou mais novo.
- [GitHub CLI](https://cli.github.com) logado (`gh auth login`) ou um Personal Access Token com os escopos `repo` e `read:org`.
- Para as ações do Claude: [Claude Code](https://claude.com/claude-code) disponível no shell como `claude` (ou outro nome configurado).
- Para compilar: Xcode 27 e [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

## Download

Baixe o DMG em [prumo.aglv.dev](https://prumo.aglv.dev) e arraste o PRumo para Applications.

O app não é notarizado pela Apple. Na primeira abertura, o macOS bloqueia. Para liberar, vá em Ajustes do Sistema › Privacidade e Segurança e clique em "Abrir mesmo assim", ou rode:

```bash
xattr -dr com.apple.quarantine /Applications/PRumo.app
```

O widget pode não aparecer em outros Macs, porque o app não tem assinatura de desenvolvedor.

Para gerar o DMG localmente (saída em `build/PRumo.dmg` e o hash em `build/PRumo.dmg.sha256`, fora do git):

```bash
scripts/make-dmg.sh
```

## Release

A versão fica em `MARKETING_VERSION` no `project.yml`. Para publicar uma versão no GitHub Releases:

```bash
scripts/release.sh --dry-run 0.3.0
scripts/release.sh 0.3.0
```

O script exige árvore limpa na `main` e o `gh` logado. Ele grava a versão, roda os testes do kit, gera o DMG, cria o commit `chore: versão X.Y.Z` e a tag `vX.Y.Z`, faz push e publica o release com `PRumo.dmg` e `PRumo.dmg.sha256`. As notas saem dos commits `feat` e `fix` desde a tag anterior. A landing baixa sempre o último release, e o app avisa e instala a versão nova em Ajustes › Atualizações.

## Como compilar e rodar

```bash
xcodegen generate
xcodebuild -project PRumo.xcodeproj -scheme PRumo -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/PRumo-*/Build/Products/Debug/PRumo.app
```

O `PRumo.xcodeproj` é gerado a partir do `project.yml` e não vai para o git. A assinatura é ad-hoc, para rodar na sua máquina sem conta Apple paga.

Na primeira abertura, o app detecta o `gh` e pede confirmação da conta, ou pede um token. Depois pede permissão de notificação e oferece abrir ao iniciar o macOS.

Para ver o onboarding de novo:

```bash
defaults delete dev.aglv.prumo
```

## Privacidade

- O token fica no Keychain (`dev.aglv.prumo`). Nada vai para arquivo nem para servidor que não seja o do GitHub.
- O app consulta a API do GitHub direto do seu Mac a cada 60 s (configurável). Não existe backend.
- Org com SAML SSO não autorizado não derruba o app: os PRs que dá para ler continuam aparecendo.

## Desenvolvimento

```
PRumoKit/   pacote Swift com a lógica: cliente GraphQL, motor de notificações,
            estado salvo, token, apresentação das linhas, clones, worktrees e sessão do Claude
PRumo/      app SwiftUI: barra de menu, popover, notificações, onboarding e ajustes
docs/       spec, planos de implementação e mockups em HTML
scripts/    render-icons.swift, que gera os PNGs do ícone a partir do SVG
```

Testes do pacote:

```bash
cd PRumoKit && swift test
```

Spec em `docs/superpowers/specs/2026-11-05-prumo-design.md`. Os mockups em `docs/mockups/` abrem direto no navegador.

## Identidade visual

<p align="center"><img src="docs/assets/palette.svg" width="480" alt="Paleta do PRumo: areia, carvão e caramelo"></p>

O nome junta "PR" com prumo, o fio com peso que mostra a vertical certa. O logotipo é "PRumo" em SF Pro Bold com "PR" em caramelo. O ícone usa o símbolo `pull-request` com a main em carvão e o lado do PR em caramelo, sobre areia no tema claro e sobre carvão no escuro. Na interface, as cores de status (verde, amarelo, vermelho, laranja) são as do sistema e ficam separadas da paleta da marca. Os arquivos estão em `docs/assets/`.

## Créditos

Símbolo `pull-request` do [IBM Carbon](https://github.com/carbon-design-system/carbon), licença Apache 2.0. Claude Code é marca da Anthropic; o PRumo não é afiliado ao GitHub nem à Anthropic.
