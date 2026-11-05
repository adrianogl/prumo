# PRumo: design

Data: 2026-11-05
Status: rascunho para aprovação

## Por que existe

Hoje, para saber se um PR andou, é preciso abrir o GitHub: ver se a CI terminou, se alguém aprovou, se pediram alteração, se tem review esperando. As notificações do GitHub misturam tudo e se perdem no e-mail.

O PRumo é um app de barra de menu para macOS que acompanha só duas coisas da conta do usuário: os PRs que ele abriu e os reviews que pediram a ele. Ele avisa quando algo muda e, em um clique, abre o PR no navegador.

A referência é o pullbar.app. O PRumo não copia nome, visual nem marca dele; a identidade é própria (ver "Identidade visual").

## Objetivos

- Ver, sem abrir o navegador, o estado de cada PR aberto do usuário: CI, aprovações, alterações pedidas, comentários, draft, conflito.
- Ver a fila de reviews pedidos ao usuário (e, opcionalmente, ao time dele).
- Receber notificação nativa do macOS quando:
  - a CI de um PR do usuário termina (passou ou falhou);
  - um PR do usuário é aprovado;
  - pedem alterações num PR do usuário;
  - entra comentário novo num PR do usuário;
  - pedem review ao usuário;
  - um review pedido ao usuário está parado há mais de X horas;
  - um PR do usuário fica pronto para merge;
  - um PR do usuário entra em conflito.
- Clicar numa linha ou notificação abre a página certa no navegador padrão.
- Receber as mesmas notificações no iPhone e no iPad, na hora, sem app iOS próprio e sem conta Apple paga (ver "Notificações no iPhone e iPad").

## Não objetivos

- Aprovar, comentar ou fazer merge dentro do app. Isso continua no navegador.
- Várias contas do GitHub, GitHub Enterprise Server.
- Estatísticas (tempo médio de review etc.), status de deploy por ambiente.
- Distribuição na App Store.
- App nativo para iPhone ou iPad. Sem Apple Developer Program pago, o app instalado pelo Xcode expira a cada 7 dias e não tem CloudKit nem push. Se um dia houver conta paga, o caminho é extrair o núcleo para um pacote Swift e fazer o app iOS em cima dele.
- Servidor próprio. O Mac é o único lugar que fala com o GitHub.

## Anti-objetivos

O app falhou, mesmo funcionando, se:

- notificar o estado que já existia na primeira execução ou depois de reiniciar;
- disparar uma notificação por check de CI em vez de uma por resultado;
- notificar comentário do próprio usuário ou de bot;
- precisar de mais de um clique para chegar ao PR;
- virar um cliente do GitHub com botões de aprovar e comentar.

## Plataforma

- App nativo em Swift e SwiftUI, só na barra de menu (`MenuBarExtra` com estilo janela), sem ícone no Dock (`LSUIElement`).
- macOS 26 ou mais novo. Motivo: ícone com variantes clara e escura feitas no Icon Composer. A máquina do usuário roda macOS 27.2 com Xcode 27.2.
- Uma conta do GitHub (github.com).
- Conta Apple gratuita (time pessoal do Xcode). O usuário não vai assinar o Developer Program. Tudo que depende de conta paga (CloudKit, push da Apple, App Store, notarização) está fora.

## Autenticação

1. Na primeira abertura, o app roda `gh auth token`. Se der certo, mostra "Encontrei o GitHub CLI logado como @usuário" e o botão "Usar esta conta".
2. Se não houver `gh` ou ele não estiver logado, o app pede um Personal Access Token (escopos `repo` e `read:org`), com link para criar o token no GitHub.
3. O token fica no Keychain. O app não grava token em arquivo.
4. Token revogado ou inválido (HTTP 401): aviso no popover que leva de volta ao passo 1.

Rodar `gh` exige que o app principal não use App Sandbox. Isso é aceitável porque a distribuição é local (ver "Distribuição").

## Telas

Mockups de referência, gerados durante a conversa de design:

- `docs/mockups/visao-geral.html`: ícone, barra de menu, as três abas, notificações, widgets e ajustes, claro e escuro lado a lado.
- `docs/mockups/fluxo-claro-escuro.html`: o fluxo completo em 15 passos, claro e escuro.

Os arquivos são fragmentos HTML com CSS inline e abrem direto no navegador. Os dados neles (orgs, PRs, pessoas) são inventados.

### Ícone na barra de menu

- Símbolo `pull-request` monocromático como template image (o macOS pinta de branco ou preto conforme o tema).
- Ao lado, o número de reviews pendentes para o usuário.
- Ponto vermelho pequeno quando algum PR do usuário está com CI falhando.

### Popover

Cabeçalho: ícone do app pequeno, logotipo "PRumo", botão de Não perturbe (sino com Z) e botão de atualizar.

Abaixo, um seletor de três abas, cada uma com contador em caramelo:

- **Meus PRs**: PRs abertos de autoria do usuário, em qualquer repositório.
- **Revisar**: PRs abertos com review pedido ao usuário e ainda não revisados por ele. Cada linha diz se o pedido foi "para você" (caramelo) ou para um time do usuário (cinza, com o nome do time).
- **Merge**: PRs do usuário aprovados, com CI verde e sem conflito. No fim, a seção "Mergeados hoje" com os PRs do usuário que entraram hoje e o horário do merge.

Abaixo das abas, uma barra de filtros (mockup em `docs/mockups/filtros.html`):

- **Repositórios ▾**: lista agrupada por org, com busca, favoritos (★) no topo e quantidade de PRs por repositório. Multisseleção. Opção "esconder repositórios sem PR". Vale para as três abas.
- **Filtros ▾**: combinação de critérios:
  - CI: passou, rodando, falhando;
  - review: aprovado, alterações pedidas, sem review;
  - estado: sem drafts, com conflito, com atividade nova, fixados;
  - em Revisar: para você, para o time, parado há mais que o limite;
  - autor (busca por pessoa).
- **Ordem ▾** (à direita), escolhida por aba: atividade recente (padrão), precisa de ação primeiro, mais antigos primeiro, mais novos primeiro, repositório, tamanho do diff. Opção extra "agrupar por repositório", com cabeçalho e contagem por repositório. Fixados ficam sempre no topo e silenciados sempre no fim, em qualquer ordem.
- Filtros ativos aparecem como chips logo abaixo da barra, cada um com ✕, e um "Limpar".
- Uma combinação de repositórios e filtros pode ser salva como **visão**, com nome, para reaplicar depois.
- Filtros, ordem e visões ficam salvos entre execuções.

Rodapé: "Atualizado há Ns", o atalho global (`⌥⌘P`) e o botão Ajustes. Com navegação por teclado ativa, o rodapé mostra os atalhos do popover.

### Linha de PR

Dois modos, configuráveis nos Ajustes. O padrão é o detalhado.

**Detalhado** (padrão):

- à esquerda, bolinha de status: verde (tudo ok), amarelo (CI rodando), vermelho (CI falhou), laranja (alterações pedidas ou review parado);
- título do PR;
- `org/repo #número · idade`;
- badges: CI (`✓ CI 12/12`, `✗ unit-tests` com o nome do primeiro check que falhou, `● CI 4/9`), aprovações, alterações pedidas, comentários (ícone de conversa e quantidade), draft, conflito (ícone de merge bloqueado), chave do Jira, e na aba Revisar: para você/time, autor e tamanho do diff (`+212 −48`), espera (ícone de relógio e horas);
- à direita, no topo, bolinha caramelo de "novo" quando o PR teve atividade desde a última vez que o popover foi aberto. O título fica em negrito nesse caso.

**Compacto**: bolinha de status e uma linha só de metadados (`repo #n · aprovado · CI ok · 2h`).

Interação:

- clique na linha abre o PR no navegador;
- ao passar o mouse, aparece um botão `⋯` no canto direito (a bolinha de "novo" some enquanto isso); ele abre o menu da linha;
- botão direito (ou Control + clique) abre o mesmo menu.

Menu da linha:

- Abrir no navegador (`↵`)
- Abrir card no Jira: ON-1234 (`⌘J`), só quando há chave reconhecida
- Re-rodar job que falhou: nome do job, só quando há job do GitHub Actions falhado
- Copiar link (`⌘C`)
- Copiar `gh pr checkout <n>` (`⇧⌘C`)
- Fixar no topo / Desafixar
- Silenciar este PR / Reativar notificações

**PR fixado**: sobe para o topo da aba, com um alfinete caramelo antes do título.

**PR silenciado**: não gera notificação, desce para o fim da aba, fica esmaecido e troca a bolinha de status por um símbolo de pausa cinza. Tooltip com "Silenciado em DD/MM".

### Notificações

Banner nativo (`UserNotifications`) com o ícone do app. Clique abre a página certa:

| Evento | Título | Abre | Botões |
| --- | --- | --- | --- |
| CI terminou com falha | CI falhou em #809 | página de checks do PR | Abrir, Re-rodar, Silenciar |
| CI terminou com sucesso | CI terminou em #812: 12/12 | página de checks do PR | Abrir |
| Aprovado | #812 aprovado | PR | Abrir |
| Alterações pedidas | Alterações pedidas em #74 | PR | Abrir |
| Comentário novo | Comentário novo em #812 | comentário | Abrir |
| Review pedido | Review pedido: #815 | PR | Abrir |
| Review parado | Review parado há 26h: #798 | PR | Abrir |
| Pronto para merge | #812 pronto para merge | PR | Abrir |
| Entrou em conflito | #74 entrou em conflito | PR | Abrir, Silenciar |

Cada tipo pode ser ligado e desligado nos Ajustes.

### Não perturbe e horário de trabalho

- Botão no cabeçalho com opções: por 1 hora, até amanhã às 9h, até eu reativar.
- Enquanto ativo, o app continua atualizando os dados, mas não notifica. Ao desativar, as notificações do período não aparecem; só o que mudar dali em diante.
- Horário de trabalho (ex.: seg–sex, 9h–18h): fora dele, o app age como Não perturbe.

### Busca e teclado

- Atalho global (`⌥⌘P`, configurável) abre e fecha o popover.
- Com o popover aberto, digitar abre um campo de busca que filtra as três abas por título, repositório ou número.
- `↑` `↓` navegam entre as linhas (linha com contorno caramelo), `↵` abre, `⌘1` `⌘2` `⌘3` trocam de aba, `⌘.` abre o menu da linha.

### Notificações no iPhone e iPad

O Mac funciona como servidor. Toda notificação que o PRumo dispara no Mac também pode ser enviada para um tópico do [ntfy](https://ntfy.sh), serviço de push open source. No iPhone e no iPad, o usuário instala o app oficial do ntfy (gratuito) e assina o tópico.

- Ajustes → Integrações → ntfy: liga e desliga o envio, servidor (padrão `https://ntfy.sh`, aceita servidor próprio), nome do tópico e token de acesso opcional para servidor com autenticação.
- O app gera um nome de tópico aleatório e longo (ex.: `prumo-7f3k9q2xw8...`), porque no servidor público quem sabe o nome do tópico lê as mensagens. Botão "Enviar teste" e um QR code com o link de assinatura para abrir no iPhone.
- Cada mensagem leva título e corpo iguais aos da notificação do Mac, o link do PR como ação de clique (abre no Safari), tag de ícone por tipo e prioridade alta para CI falhou e conflito.
- O que vai para o ntfy: título do PR, `org/repo #n`, nome do check, nome de quem comentou ou revisou e o começo do comentário. O token do GitHub não sai do Mac.
- Valem as mesmas regras de tipo, silenciado, Não perturbe e horário de trabalho.
- Para não chegar a mesma notificação no Mac e no iPhone ao mesmo tempo, o envio para o ntfy, por padrão, só acontece com a tela do Mac bloqueada ou sem uso há mais de 5 minutos. Ajuste: "sempre", "só quando eu estiver longe do Mac" (padrão) ou "nunca".
- Limite conhecido: com o Mac desligado ou dormindo, nada é enviado.

### Widget

Depende de App Group entre o app e a extensão. Com conta gratuita, o macOS pode aceitar App Group com o prefixo do Team ID sem perfil pago, mas isso precisa ser testado. Se não funcionar, o widget sai do escopo.

WidgetKit, dois tamanhos:

- **Pequeno**: "para revisar" e "CI falhando".
- **Médio**: os três contadores (para revisar, CI falhando, prontos para merge) e até três PRs que pedem ação. Clique abre o PR.

### Onboarding

1. Boas-vindas com detecção do `gh`, ou tela de token.
2. Pedido de permissão de notificação do macOS.
3. Tela "Tudo pronto" com "Abrir ao iniciar o macOS" e "Ignorar drafts em Revisar", os dois ligados por padrão.
4. Primeira leitura com skeleton de carregamento. Nenhuma notificação pelo estado atual.

### Ajustes

Janela com estas seções:

- **Conta**: usuário conectado e origem do token (`gh` ou token colado); trocar conta.
- **Exibição**: linha detalhada ou compacta; intervalo de atualização (padrão 60 s); abrir ao iniciar o macOS; atalho global.
- **Notificações**: um toggle por tipo; agrupar notificações de CI; lembrete de review parado após N horas (padrão 24 h); só em horário de trabalho (dias e horário).
- **Filtros**: ignorar drafts em Revisar; incluir reviews pedidos ao time; visões salvas; PRs silenciados (lista, com reativar).
- **Integrações**: Jira, com uma lista de prefixo de chave → endereço do site (ex.: `ON` → `empresa.atlassian.net`, `DEV` → site da Contoso); ntfy (ver "Notificações no iPhone e iPad").
- **Sobre**: versão e aviso de licença do símbolo do IBM Carbon (Apache 2.0).

### Sem conexão

Sem rede ou com erro da API, o popover mantém os últimos dados com um aviso ("Sem conexão. Mostrando dados de 10:40. Tentando de novo em 30s.") e tenta de novo. Erro 401 leva ao fluxo de token.

## Identidade visual

- **Nome**: PRumo. "PR" + prumo, o fio com peso que mostra a vertical certa.
- **Logotipo**: "PRumo" em SF Pro Bold, tracking negativo (cerca de −1,2 pt a 40 pt, proporcional nos outros tamanhos), "PR" em caramelo.
- **Símbolo**: `pull-request` do IBM Carbon (`@carbon/icons`, licença Apache 2.0). SVG em `docs/mockups/pull-request-carbon.svg`. O caminho da direita (seta e nó do PR) é o "lado PR"; o da esquerda é a main.
- **Paleta**:
  - areia `#f3e6cf` → `#d9c3a0` (degradê do fundo do ícone claro);
  - carvão `#2a2622`;
  - caramelo `#a5713a` (destaque: "PR" do logo, contadores, seleção, bolinha de "novo", alfinete).
- **Cores de status**: as cores de sistema do macOS (verde, amarelo, vermelho, laranja), separadas da paleta da marca.
- **Ícone do app** (Icon Composer):
  - claro: fundo areia, main em carvão, PR em caramelo;
  - escuro ("carimbo"): fundo carvão, main em areia, PR em caramelo;
  - tinted: gerado pelo sistema a partir do claro.
- **Ícones da interface**: SF Symbols monocromáticos, traço fino. Nada de emoji. Escolhas: comentários = conversa (dois balões), Não perturbe = sino com Z, conflito = merge bloqueado, espera = relógio, silenciado = pausa, fixado = alfinete.
- **Tipografia**: SF Pro na interface, SF Mono em nomes de branch, comandos e atalhos.
- **Tema**: segue o claro/escuro do sistema. Fundo do popover claro `#fbf8f2`, escuro `#252322`.

## Como o app sabe o que mudou

- A cada intervalo (padrão 60 s), o app busca o estado atual pela GraphQL API do GitHub e compara com o último estado salvo.
- O estado salvo fica em disco (Application Support), para que reiniciar o app ou o Mac não gere notificações repetidas.
- Na primeira leitura depois do onboarding, o estado vira a base e nada é notificado.
- Regras de transição:
  - **CI**: o rollup de checks do último commit do PR sai de pendente para sucesso ou falha. Uma notificação por commit, não por check.
  - **Aprovado**: decisão de review passa a aprovado, ou chega review aprovado novo.
  - **Alterações pedidas**: chega review com alterações pedidas.
  - **Comentário**: comentário novo (de issue ou de review) de autor que não é o usuário e não é bot.
  - **Review pedido**: PR novo na lista de reviews pedidos.
  - **Review parado**: pedido aberto há mais que o limite configurado. Lembra uma vez por pedido.
  - **Pronto para merge**: PR passa a cumprir aprovado + CI verde + sem conflito.
  - **Conflito**: `mergeable` passa a `CONFLICTING`.
- Drafts: entram em Meus PRs normalmente. Em Revisar, são ignorados se a opção estiver ligada.
- **Pronto para merge** em repositório sem review obrigatório ou sem CI: basta ao menos uma aprovação e nenhuma alteração pedida pendente. PR sem nenhum check conta como CI verde.
- **Reviews pedidos ao time** (opção ligada): aparecem na aba Revisar com o badge do time, mas não disparam notificação de review pedido nem lembrete de review parado, e não entram no contador da barra de menu nem no widget. O PR sai da aba quando alguém do time envia um review.
- **Agrupar notificações de CI**: as notificações de um mesmo PR usam o mesmo `threadIdentifier`, e a Central de Notificações empilha tudo sob o PR. Não existe banner agregado de vários PRs.
- **Atividade nova** (bolinha caramelo): qualquer evento que geraria notificação (CI terminou, review, comentário, conflito, pronto para merge) ou commit novo no PR. Mudança de label ou de título não conta. A bolinha some quando o popover é aberto com aquele PR visível.
- **Pausas e review parado**: as horas de espera contam no relógio corrido. Se o limite vence durante o Não perturbe ou fora do horário de trabalho, o lembrete é adiado para o fim da pausa, em vez de ser descartado. As outras notificações continuam descartadas.

## Ordem de entrega

Cada etapa termina com o app usável.

1. **Núcleo**: projeto Xcode, identidade (ícone, logotipo, cores), onboarding e token, leitura pela API, abas Meus PRs e Revisar, linha detalhada, abrir no navegador, notificações de CI, aprovado, alterações pedidas, comentário e review pedido, estado persistido, ajustes básicos, abrir ao iniciar.
2. **Organização**: aba Merge e mergeados hoje, barra de repositórios, filtros e ordem, visões salvas, linha compacta, silenciar, fixar, ignorar drafts, para você/time, marcador de novo.
3. **Ruído sob controle**: Não perturbe, horário de trabalho, review parado, notificações de pronto para merge e conflito, toggles por tipo.
4. **iPhone e iPad pelo ntfy**: envio para o tópico, QR code de assinatura, regra de "só quando eu estiver longe do Mac".
5. **Ações**: menu `⋯`, re-rodar job, copiar link e checkout, Jira, botões nas notificações.
6. **Teclado**: atalho global, busca, navegação por teclado.
7. **Widget**, se o App Group funcionar com conta gratuita.

## Distribuição

Build local, assinado com o time pessoal (gratuito) do Xcode, para rodar na máquina do usuário. Sem App Store e sem notarização.

## Decisões tomadas por mim (revisar)

- Sem ícone no Dock.
- Token: tenta `gh auth token` antes de pedir PAT; PAT no Keychain.
- Intervalo de atualização de 60 s, configurável.
- Primeira leitura sem notificações.
- Comentário do próprio usuário e de bot não notifica.
- Notificação de CI abre a página de checks, não a página do PR.
- Não perturbe descarta o que aconteceu durante a pausa.
- Sem conexão: mostra os últimos dados com aviso.
- Tela "Tudo pronto" no onboarding.
- Na aba Revisar, autor e tamanho do diff na linha.
- Ponto vermelho no ícone da barra quando há CI falhando.
- Reativar PR silenciado pelo menu da linha ou pelos Ajustes.
- Atalhos `⌘J`, `⇧⌘C` e `⌘.`.
- A busca filtra as três abas.
- Widget mostra no máximo três PRs.
- Horário de trabalho vem desligado por padrão.
- macOS 26 como versão mínima.
- "Agrupar notificações de CI" empilha as notificações de cada PR na Central de Notificações.
- A bolinha de "novo" acende com eventos que gerariam notificação ou com commit novo.
- O lembrete de review parado é adiado para o fim da pausa, em vez de ser descartado.
- Pronto para merge sem branch protection: uma aprovação basta; PR sem checks conta como CI verde (sugestão aceita).
- Reviews do time: na lista, sem notificação e fora dos contadores (sugestão aceita).
- ntfy: tópico aleatório gerado pelo app, servidor público como padrão, envio só quando o usuário está longe do Mac (tela bloqueada ou 5 min sem uso).
- Ordem escolhida por aba; filtros e repositórios valem para as três abas.
- Distribuição local, sem App Store.

## Fica para o builder

- Estrutura de pastas e módulos do projeto Xcode.
- Formato das queries GraphQL e paginação.
- Formato do estado salvo em disco.
- Como compartilhar dados com o widget (App Group é o caminho esperado, já que a extensão do widget precisa de sandbox).
- Implementação do atalho global (API do sistema ou biblioteca).
- Testes: as regras de transição de notificação precisam de testes unitários com estados antes e depois.
