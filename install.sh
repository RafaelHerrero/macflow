#!/usr/bin/env bash
#
# Macflow — instalador
#
# O que ele faz:
#   1. Compila o binário em modo release.
#   2. Copia o binário para ~/.local/bin/macflow.
#   3. Cria ~/.config/macflow/ e linka o config.toml (estilo dotfiles).
#   4. Instala e carrega o LaunchAgent (inicia no login).
#
# Uso:  ./install.sh
set -euo pipefail

# ── Caminhos ──────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/macflow"
CONFIG_DIR="$HOME/.config/macflow"
CONFIG_FILE="$CONFIG_DIR/config.toml"
REPO_CONFIG="$REPO_DIR/config.toml"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_NAME="com.macflow.agent.plist"
PLIST_PATH="$LAUNCH_AGENTS/$PLIST_NAME"
LABEL="com.macflow.agent"

say() { printf "\033[1;34m▸\033[0m %s\n" "$1"; }

# ── 1. Compilar ────────────────────────────────────────────────────────────
say "Compilando Macflow (release)…"
cd "$REPO_DIR"
swift build -c release
BUILT_BIN="$(swift build -c release --show-bin-path)/Macflow"

# ── 2. Instalar binário ────────────────────────────────────────────────────
say "Instalando binário em $BIN_PATH"
mkdir -p "$BIN_DIR"
install -m 755 "$BUILT_BIN" "$BIN_PATH"

# ── 2b. Assinatura de código ───────────────────────────────────────────────
# A permissão de Acessibilidade é amarrada à assinatura. Com a assinatura
# ad-hoc padrão, o cdhash muda a cada build e a permissão é perdida (re-prompt).
# Se existir um certificado self-signed "macflow-codesign" no chaveiro, assinamos
# com ele: a permissão passa a valer para qualquer build futuro.
CODESIGN_CERT="macflow-codesign"
signed_with_cert=false
if security find-certificate -c "$CODESIGN_CERT" >/dev/null 2>&1; then
    say "Assinando com o certificado '$CODESIGN_CERT' (permissão persistente)"
    if codesign --force --sign "$CODESIGN_CERT" --identifier com.macflow.agent "$BIN_PATH" 2>/dev/null; then
        signed_with_cert=true
    else
        echo "  ⚠ Falha ao assinar com '$CODESIGN_CERT' — caindo para ad-hoc."
    fi
fi
if [[ "$signed_with_cert" == false ]]; then
    codesign --force --sign - --identifier com.macflow.agent "$BIN_PATH" 2>/dev/null || true
    echo "  ⚠ Assinatura ad-hoc: a permissão de Acessibilidade precisará ser"
    echo "    re-concedida após cada recompilação. Para torná-la permanente,"
    echo "    rode uma vez: ./scripts/create-codesign-cert.sh"
fi

# ── 3. Configuração (dotfiles-friendly) ────────────────────────────────────
mkdir -p "$CONFIG_DIR"
# Mantém o config "fonte" dentro do repo para versionar no Git.
if [[ ! -e "$REPO_CONFIG" ]]; then
    say "Criando config inicial a partir do template"
    cp "$REPO_DIR/config.toml.example" "$REPO_CONFIG"
fi
# Symlink: ~/.config/macflow/config.toml -> <repo>/config.toml
if [[ -L "$CONFIG_FILE" || ! -e "$CONFIG_FILE" ]]; then
    say "Linkando config: $CONFIG_FILE -> $REPO_CONFIG"
    ln -sf "$REPO_CONFIG" "$CONFIG_FILE"
else
    say "Já existe um config.toml real (não-symlink) — preservando o seu."
fi

# ── 4. LaunchAgent ─────────────────────────────────────────────────────────
say "Instalando LaunchAgent"
mkdir -p "$LAUNCH_AGENTS" 2>/dev/null || true

# ~/Library/LaunchAgents deve pertencer a VOCÊ. Se um instalador antigo a criou
# como root, a escrita falha. Detectamos e orientamos em vez de pedir sudo no
# script todo (instalar o agent como root o faria rodar na sessão errada).
if [[ ! -w "$LAUNCH_AGENTS" ]]; then
    echo
    echo "  ✗ Sem permissão de escrita em $LAUNCH_AGENTS"
    echo "    (dono atual: $(stat -f '%Su' "$LAUNCH_AGENTS"))."
    echo
    echo "    Essa pasta deveria ser sua. Corrija a posse UMA vez com:"
    echo
    echo "        sudo chown -R \"\$(whoami)\":staff \"$LAUNCH_AGENTS\""
    echo
    echo "    Depois rode ./install.sh novamente (sem sudo)."
    exit 1
fi

sed "s|__BINARY_PATH__|$BIN_PATH|g" "$REPO_DIR/LaunchAgent/$PLIST_NAME" > "$PLIST_PATH"

# Recarrega o agent (bootout do antigo, bootstrap do novo).
GUI_DOMAIN="gui/$(id -u)"
launchctl bootout "$GUI_DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$GUI_DOMAIN" "$PLIST_PATH"
launchctl enable "$GUI_DOMAIN/$LABEL" 2>/dev/null || true

say "Pronto! O Macflow está rodando na barra de menus."
echo
echo "  • Conceda permissão de Acessibilidade quando solicitado"
echo "    (Ajustes do Sistema → Privacidade e Segurança → Acessibilidade)."
echo "  • Edite seus atalhos em: $REPO_CONFIG"
echo "  • Adicione ~/.local/bin ao PATH se ainda não estiver."
