# Macflow

A lightweight manager for **global shortcuts** and **window management** on macOS,
configured by a single `config.toml` file in dotfiles style.

- ⚡️ **Lightweight**: ~200 KB binary, no external dependencies, ~0% CPU when idle.
- 🎯 **App switcher**: `Ctrl+1`, `Ctrl+2`… open or focus your favorite apps.
- 🪟 **Window management**: halves, thirds, quadrants, maximize, center, and move between monitors.
- 🔁 **Hot-reload**: save the `config.toml` and the shortcuts are reapplied instantly.
- 🍫 **Menu bar only**: no Dock icon, no noise.
- 🖥️ **Full multi-monitor** support.

---

## How it works

| Layer | Technology |
|---|---|
| Global hotkeys | Carbon `RegisterEventHotKey` (zero dependencies) |
| Window management | Accessibility API (`AXUIElement`) |
| App switching | `NSWorkspace` + search in `/Applications` |
| Config | Custom TOML parser + `DispatchSource` for hot-reload |
| UI | AppKit menu bar (`NSStatusItem`), `.accessory` app |

---

## Requirements

- macOS 13 (Ventura) or later
- Swift 6 toolchain (Xcode 16+ or Command Line Tools)

---

## Installation

```bash
git clone <your-fork> macflow
cd macflow

# 1. (recommended) Create a stable signing certificate — ONCE only.
#    Without it, the Accessibility permission must be re-granted on every build.
./scripts/create-codesign-cert.sh

# 2. Build, install, and start the app.
./install.sh
```

`install.sh`:

1. Builds the binary in release mode.
2. Installs it to `~/.local/bin/macflow`.
3. Signs the binary (with the `macflow-codesign` certificate, if it exists).
4. Creates `~/.config/macflow/config.toml` (a symlink to the repo's `config.toml`).
5. Installs the LaunchAgent (`~/Library/LaunchAgents/com.macflow.agent.plist`) and starts the app.

### 3. Grant Accessibility permission

The **window** shortcuts use the Accessibility API and require permission (the app
switcher works without it). After installing:

1. Press any window shortcut (e.g. `Ctrl+Option+Return`) — a prompt will appear.
2. Go to **System Settings → Privacy & Security → Accessibility**.
3. If there's an old **macflow** entry already, remove it with `−` (it may be stale).
4. Enable **macflow**.

> **Why the certificate matters.** macOS ties the Accessibility permission to the
> binary's signature. With the default ad-hoc signature, the hash changes on every
> rebuild and the permission is lost (the app asks for access again). By signing with
> a stable self-signed certificate (step 1), the permission is tied to the
> certificate and **survives all future rebuilds** — the same technique used by
> yabai/skhd. You only need to grant Accessibility once.

### Accessibility shortcuts

If you skip step 1 (the certificate), the app still works, but you'll have to
re-grant Accessibility every time you rebuild. To create the certificate later,
run `./scripts/create-codesign-cert.sh` and then `./install.sh`.

### Uninstall

```bash
./uninstall.sh   # removes the binary and LaunchAgent; preserves your config
```

---

## Editing the configuration

The file lives at `~/.config/macflow/config.toml` (or in the repo, via symlink).
Edit it from the menu (**Edit config.toml**) or directly in your editor. On save,
Macflow reloads on its own — no need to restart.

### Apps

```toml
[settings]
app_modifier = "Ctrl"      # modifier shared by all apps

[apps]
"1" = "Safari"             # Ctrl+1
"2" = "Visual Studio Code" # Ctrl+2
"3" = "iTerm"
"4" = "com.apple.Terminal" # bundle id works too
```

App already open → it's focused. App closed → it's opened (searches `/Applications`,
`~/Applications`, `/System/Applications`, and finally via bundle id).

### Windows

```toml
[windows]
left   = "Ctrl+Option+Left"
right  = "Ctrl+Option+Right"
maximize = "Ctrl+Option+Return"
next-monitor = "Ctrl+Option+Shift+Right"
```

**Available actions:**

| Category | Actions |
|---|---|
| Halves | `left`, `right`, `top`, `bottom` |
| Quadrants | `top-left`, `top-right`, `bottom-left`, `bottom-right` |
| Thirds | `left-third`, `center-third`, `right-third`, `left-two-thirds`, `right-two-thirds` |
| Screen | `maximize`, `center` |
| Monitors | `next-monitor`, `prev-monitor` |

**Modifiers:** `Ctrl`, `Option` (or `Alt`), `Cmd`, `Shift`.
**Keys:** arrows (`Left`/`Right`/`Up`/`Down`), letters, digits, `F1`–`F12`,
`Return`, `Space`, `Tab`, `Escape`.

See the fully commented [`config.toml.example`](./config.toml.example).

---

## Syncing via Git (dotfiles)

`install.sh` keeps the `config.toml` **inside the repository** and creates a symlink
at `~/.config/macflow/config.toml`. This way you version-control your shortcuts:

```bash
cd macflow
git add config.toml
git commit -m "my shortcuts"
git push
```

On another machine, just clone and run `./install.sh` again.

---

## Project structure

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
│   └── create-codesign-cert.sh   # creates the stable signing certificate
├── config.toml.example
├── install.sh
├── uninstall.sh
└── README.md
```

---

## Adding new actions

The code is modular and easy to extend.

**New window action** (e.g. `almost-maximize`):

1. Add the `case` in [`WindowAction`](./Sources/Macflow/WindowManager/WindowAction.swift)
   with its `rawValue` in kebab-case.
2. Implement the frame in `frame(in:)` (or handle it in `WindowManager` if you need
   extra context, as `center` does).
3. Use the action in `config.toml`: `almost-maximize = "Ctrl+Option+M"`.

**New shortcut/key type:** add the token to `keyMap`/`modifierMap` in
[`HotkeyParser`](./Sources/Macflow/Hotkeys/HotkeyParser.swift).

---

## Development

```bash
swift build              # debug
swift run Macflow        # run directly in the terminal
swift build -c release   # optimized binary
```

LaunchAgent logs: `/tmp/macflow.out.log` and `/tmp/macflow.err.log`.
Macflow records there what was loaded and every window action it ran —
useful for debugging shortcuts that "do nothing".

---

## Troubleshooting

**Window shortcuts do nothing.**
It's almost always the Accessibility permission. Check the log:

```bash
tail -f /tmp/macflow.err.log
```

- `perform(...) ignored: NO Accessibility permission` → grant/re-grant
  Accessibility (see [Installation](#3-grant-accessibility-permission)).
  If you rebuilt without the stable certificate, the old permission becomes "stale":
  remove the **macflow** entry under Accessibility and grant it again.
- `window 'x' → '...' FAILED to register` → the shortcut conflicts with another app;
  pick a different combination.
- No `perform(...)` line when you press → the shortcut wasn't recognized; check
  the spelling in `config.toml` (e.g. a key supported by `HotkeyParser`).

**The app asks for Accessibility every time I rebuild.**
You're using an ad-hoc signature. Run `./scripts/create-codesign-cert.sh` once
and reinstall — the permission will then survive rebuilds.

**`Permission denied` when writing the LaunchAgent during `install.sh`.**
The `~/Library/LaunchAgents` folder ended up owned by `root` (a leftover from some
old installer run with `sudo`). Return ownership to yourself and reinstall:

```bash
sudo chown -R "$(whoami)":staff ~/Library/LaunchAgents
./install.sh
```

**`./scripts/create-codesign-cert.sh` fails with "MAC verification failed".**
Old version of the script. The current one already generates the PKCS12 in the
legacy format (`-legacy -macalg sha1`) compatible with Apple's `security` — use the
one from the repo.

**Moving between monitors.** `next-monitor`/`prev-monitor` move the focused window
to the adjacent display, preserving its relative position/size. With 2 monitors,
both toggle to the other one.

---

## How to contribute

1. Fork → branch → small, focused change.
2. `swift build` with no warnings.
3. Open a PR describing the behavior.

---

## License

MIT.
