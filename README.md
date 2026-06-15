# Macflow

Gerenciador leve de **atalhos globais** e **window management** para macOS,
configurado por um único arquivo `config.toml` no estilo dotfiles.

- ⚡️ **Leve**: binário ~200 KB, sem dependências externas, CPU ~0% quando ocioso.
- 🎯 **App switcher**: `Ctrl+1`, `Ctrl+2`… abrem ou focam seus apps favoritos.
- 🪟 **Window management**: metades, terços, quadrantes, maximizar, centralizar e mover entre monitores.
- 🔁 **Hot-reload**: salvou o `config.toml`, os atalhos são reaplicados na hora.
- 🍫 **Menu bar only**: sem ícone no Dock, sem ruído.
- 🖥️ **Multi-monitor** completo.

---

## Como funciona

| Camada | Tecnologia |
|---|---|
| Hotkeys globais | Carbon `RegisterEventHotKey` (zero dependências) |
| Window management | Accessibility API (`AXUIElement`) |
| App switching | `NSWorkspace` + busca em `/Applications` |
| Config | Parser TOML próprio + `DispatchSource` para hot-reload |
| UI | AppKit menu bar (`NSStatusItem`), app `.accessory` |

---

## Requisitos

- macOS 13 (Ventura) ou superior
- Swift 6 toolchain (Xcode 16+ ou Command Line Tools)

---

## Instalação

```bash
git clone <seu-fork> macflow
cd macflow

# 1. (recomendado) Cria um certificado de assinatura estável — UMA vez só.
#    Sem isso, a permissão de Acessibilidade precisa ser re-concedida a cada build.
./scripts/create-codesign-cert.sh

# 2. Compila, instala e inicia o app.
./install.sh
```

O `install.sh`:

1. Compila o binário em release.
2. Instala em `~/.local/bin/macflow`.
3. Assina o binário (com o certificado `macflow-codesign`, se existir).
4. Cria `~/.config/macflow/config.toml` (symlink para o `config.toml` do repo).
5. Instala o LaunchAgent (`~/Library/LaunchAgents/com.macflow.agent.plist`) e inicia o app.

### 3. Conceder permissão de Acessibilidade

Os atalhos de **janela** usam a Accessibility API e exigem permissão (o app
switcher funciona sem ela). Após instalar:

1. Aperte qualquer atalho de janela (ex.: `Ctrl+Option+Return`) — vai surgir um prompt.
2. Vá em **Ajustes do Sistema → Privacidade e Segurança → Acessibilidade**.
3. Se já existir uma entrada **macflow** antiga, remova-a com o `−` (pode estar órfã).
4. Habilite o **macflow**.

> **Por que o certificado importa.** O macOS amarra a permissão de Acessibilidade
> à assinatura do binário. Com a assinatura ad-hoc padrão, o hash muda a cada
> recompilação e a permissão é perdida (o app volta a pedir acesso). Assinando com
> um certificado self-signed estável (passo 1), a permissão fica amarrada ao
> certificado e **sobrevive a todas as recompilações futuras** — mesma técnica do
> yabai/skhd. Você só precisa conceder a Acessibilidade uma única vez.

### Atalhos de Acessibilidade

Se você pular o passo 1 (certificado), o app ainda funciona, mas terá de
re-conceder a Acessibilidade toda vez que recompilar. Para criar o certificado
depois, rode `./scripts/create-codesign-cert.sh` e em seguida `./install.sh`.

### Desinstalar

```bash
./uninstall.sh   # remove binário e LaunchAgent; preserva sua config
```

---

## Editando a configuração

O arquivo fica em `~/.config/macflow/config.toml` (ou no repo, via symlink).
Edite pelo menu (**Editar config.toml**) ou direto no seu editor. Ao salvar, o
Macflow recarrega sozinho — não precisa reiniciar.

### Apps

```toml
[settings]
app_modifier = "Ctrl"      # modificador comum a todos os apps

[apps]
"1" = "Safari"             # Ctrl+1
"2" = "Visual Studio Code" # Ctrl+2
"3" = "iTerm"
"4" = "com.apple.Terminal" # bundle id também funciona
```

App já aberto → é focado. App fechado → é aberto (busca em `/Applications`,
`~/Applications`, `/System/Applications` e, por fim, via bundle id).

### Janelas

```toml
[windows]
left   = "Ctrl+Option+Left"
right  = "Ctrl+Option+Right"
maximize = "Ctrl+Option+Return"
next-monitor = "Ctrl+Option+Shift+Right"
```

**Ações disponíveis:**

| Categoria | Ações |
|---|---|
| Metades | `left`, `right`, `top`, `bottom` |
| Quadrantes | `top-left`, `top-right`, `bottom-left`, `bottom-right` |
| Terços | `left-third`, `center-third`, `right-third`, `left-two-thirds`, `right-two-thirds` |
| Tela | `maximize`, `center` |
| Monitores | `next-monitor`, `prev-monitor` |

**Modificadores:** `Ctrl`, `Option` (ou `Alt`), `Cmd`, `Shift`.
**Teclas:** setas (`Left`/`Right`/`Up`/`Down`), letras, dígitos, `F1`–`F12`,
`Return`, `Space`, `Tab`, `Escape`.

Veja o [`config.toml.example`](./config.toml.example) totalmente comentado.

---

## Sincronizando via Git (dotfiles)

O `install.sh` mantém o `config.toml` **dentro do repositório** e cria um symlink
em `~/.config/macflow/config.toml`. Assim você versiona seus atalhos:

```bash
cd macflow
git add config.toml
git commit -m "meus atalhos"
git push
```

Em outra máquina, basta clonar e rodar `./install.sh` novamente.

---

## Estrutura do projeto

```
macflow/
├── Package.swift
├── Sources/Macflow/
│   ├── App/              # main, AppDelegate, MenuBarController, Log
│   ├── Config/           # Config, ConfigManager, TOMLParser, FileWatcher, DefaultConfig
│   ├── Hotkeys/          # HotkeyCenter (Carbon), HotkeyParser, HotkeyBinder
│   ├── WindowManager/    # WindowManager, WindowAction, AXWindow
│   ├── AppSwitcher/      # AppSwitcher
│   └── Accessibility/    # AccessibilityManager
├── LaunchAgent/com.macflow.agent.plist
├── scripts/
│   └── create-codesign-cert.sh   # cria o certificado de assinatura estável
├── config.toml.example
├── install.sh
├── uninstall.sh
└── README.md
```

---

## Adicionando novas ações

O código é modular e fácil de estender.

**Nova ação de janela** (ex.: `almost-maximize`):

1. Adicione o `case` em [`WindowAction`](./Sources/Macflow/WindowManager/WindowAction.swift)
   com seu `rawValue` em kebab-case.
2. Implemente o frame em `frame(in:)` (ou trate no `WindowManager` se precisar de
   contexto extra, como faz `center`).
3. Use a ação no `config.toml`: `almost-maximize = "Ctrl+Option+M"`.

**Novo tipo de atalho/tecla:** adicione o token ao `keyMap`/`modifierMap` em
[`HotkeyParser`](./Sources/Macflow/Hotkeys/HotkeyParser.swift).

---

## Desenvolvimento

```bash
swift build              # debug
swift run Macflow        # roda direto no terminal
swift build -c release   # binário otimizado
```

Logs do LaunchAgent: `/tmp/macflow.out.log` e `/tmp/macflow.err.log`.
O Macflow registra ali o que foi carregado e cada ação de janela executada —
útil para depurar atalhos que "não fazem nada".

---

## Troubleshooting

**Atalhos de janela não fazem nada.**
Quase sempre é permissão de Acessibilidade. Veja o log:

```bash
tail -f /tmp/macflow.err.log
```

- `perform(...) ignorado: SEM permissão de Acessibilidade` → conceda/re-conceda a
  Acessibilidade (veja [Instalação](#3-conceder-permissão-de-acessibilidade)).
  Se você recompilou sem o certificado estável, a permissão antiga vira "órfã":
  remova a entrada **macflow** em Acessibilidade e conceda de novo.
- `janela 'x' → '...' FALHOU ao registrar` → o atalho conflita com outro app;
  escolha outra combinação.
- Nenhuma linha `perform(...)` ao apertar → o atalho não foi reconhecido; confira
  a grafia no `config.toml` (ex.: tecla suportada em `HotkeyParser`).

**O app pede Acessibilidade toda vez que recompilo.**
Você está com assinatura ad-hoc. Rode `./scripts/create-codesign-cert.sh` uma vez
e reinstale — a permissão passa a sobreviver às recompilações.

**`Permission denied` ao gravar o LaunchAgent durante o `install.sh`.**
A pasta `~/Library/LaunchAgents` ficou com dono `root` (resquício de algum
instalador antigo com `sudo`). Devolva a posse a você e reinstale:

```bash
sudo chown -R "$(whoami)":staff ~/Library/LaunchAgents
./install.sh
```

**`./scripts/create-codesign-cert.sh` falha com "MAC verification failed".**
Versão antiga do script. A atual já gera o PKCS12 no formato legado
(`-legacy -macalg sha1`) compatível com o `security` da Apple — use a do repo.

**Mover entre monitores.** `next-monitor`/`prev-monitor` movem a janela em foco
para o display adjacente preservando posição/tamanho relativos. Com 2 monitores,
ambos alternam para o outro.

---

## Como contribuir

1. Fork → branch → mudança pequena e focada.
2. `swift build` sem warnings.
3. Abra um PR descrevendo o comportamento.

---

## Licença

MIT.
