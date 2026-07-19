#!/usr/bin/env bash
# SliceSoft — Workstation Installer (macOS)
#
# One-liner (vía dispatcher, auto-detecta SO, sin autenticación):
#   bash <(curl -fsSL https://raw.githubusercontent.com/slice-soft/ss-workstation/main/install.sh)
#
# O directamente desde un clon:
#   bash ~/dev/slicesoft/ss-workstation/macos/install.sh

set -euo pipefail

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
log()  { echo -e "${GREEN}[SS]${NC} $*"; }
info() { echo -e "${BLUE}[SS]${NC} $*"; }
warn() { echo -e "${YELLOW}[SS]${NC} $*"; }
err()  { echo -e "${RED}[SS]${NC} $*" >&2; }
step() { echo -e "\n${BOLD}${BLUE}━━━ $* ${NC}"; }
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }

# ─── Config ───────────────────────────────────────────────────────────────────
# Raíz del repo (este script vive en <repo>/macos/install.sh).
WORKSTATION_DIR="${SS_WORKSTATION_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}"
SHARED_CONFIGS="$WORKSTATION_DIR/shared/configs"
BREWFILE="$WORKSTATION_DIR/macos/Brewfile"
SLICESOFT_DIR="$HOME/dev/slicesoft"

# ─── Guards ───────────────────────────────────────────────────────────────────
if [ "$(uname -s)" != "Darwin" ]; then
    err "Este instalador es solo para macOS. En Linux usa linux/install.sh."
    exit 1
fi

if [ ! -d "$SHARED_CONFIGS" ] || [ ! -f "$BREWFILE" ]; then
    err "No encuentro el contenido del repo en: $WORKSTATION_DIR"
    err "Usa el one-liner del dispatcher, o clónalo primero:"
    err "  git clone https://github.com/slice-soft/ss-workstation.git ~/dev/slicesoft/ss-workstation"
    exit 1
fi

echo ""
echo -e "${BOLD}  SliceSoft Workstation Setup${NC}"
echo -e "  macOS | $(date '+%Y-%m-%d')"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# FASE 1 — Homebrew
# ═══════════════════════════════════════════════════════════════════════════════
step "Fase 1 — Homebrew"

if ! command -v brew &>/dev/null; then
    log "Instalando Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# Cargar brew en la sesión actual (Apple Silicon o Intel)
if   [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ];    then eval "$(/usr/local/bin/brew shellenv)"
fi
command -v brew &>/dev/null || { err "Homebrew no quedó en PATH."; exit 1; }
ok "Homebrew listo"

# ═══════════════════════════════════════════════════════════════════════════════
# FASE 2 — Paquetes (Brewfile, fuente única)
# ═══════════════════════════════════════════════════════════════════════════════
step "Fase 2 — Paquetes (brew bundle)"

log "Actualizando Homebrew..."
brew update
log "Instalando paquetes del Brewfile..."
brew bundle --file="$BREWFILE"
ok "Paquetes instalados"
info "Docker corre vía colima: ejecuta 'colima start' cuando lo necesites."

# ═══════════════════════════════════════════════════════════════════════════════
# FASE 3 — Shell (zsh por defecto)
# ═══════════════════════════════════════════════════════════════════════════════
step "Fase 3 — Shell"

ZSH_BIN="$(brew --prefix)/bin/zsh"
[ -x "$ZSH_BIN" ] || ZSH_BIN="$(command -v zsh)"
if [ "$SHELL" != "$ZSH_BIN" ]; then
    log "Configurando zsh ($ZSH_BIN) como shell por defecto..."
    grep -qxF "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
    chsh -s "$ZSH_BIN" || warn "chsh falló — cámbialo manualmente: chsh -s $ZSH_BIN"
    ok "Shell por defecto: zsh"
else
    ok "zsh ya es el shell por defecto"
fi

# lazygit-smart
mkdir -p "$HOME/.local/bin"
LAZYGIT_SMART="$HOME/.local/bin/lazygit-smart"
if [ ! -f "$LAZYGIT_SMART" ]; then
    log "Instalando lazygit-smart..."
    cp "$SHARED_CONFIGS/zsh/lazygit-smart" "$LAZYGIT_SMART"
    chmod +x "$LAZYGIT_SMART"
    ok "lazygit-smart instalado en ~/.local/bin/"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FASE 4 — Runtimes via mise (Node LTS + Go + Python)
# ═══════════════════════════════════════════════════════════════════════════════
step "Fase 4 — Runtimes (mise)"

eval "$(mise activate bash)" 2>/dev/null || true
MISE_CONFIG="$HOME/.config/mise/config.toml"
mkdir -p "$(dirname "$MISE_CONFIG")"
if [ ! -f "$MISE_CONFIG" ]; then
    cat > "$MISE_CONFIG" << 'MISE_EOF'
[tools]
node   = "22"   # LTS (requerido por claude-code y codex)
go     = "1.24"
python = "3.12"
MISE_EOF
    ok "mise config creada: node 22 (LTS), go 1.24, python 3.12"
else
    ok "mise config ya existe (respetando versiones actuales)"
fi
log "Instalando runtimes..."
mise install || warn "mise install falló — ejecuta 'mise install' manualmente después"
ok "Runtimes instalados"

# ═══════════════════════════════════════════════════════════════════════════════
# FASE 5 — npm globals: Claude Code + Codex
# ═══════════════════════════════════════════════════════════════════════════════
step "Fase 5 — Claude Code + Codex"

eval "$(mise activate bash)" 2>/dev/null || true
MISE_NODE_BIN="$HOME/.local/share/mise/installs/node/$(mise current node 2>/dev/null | head -1)/bin"
[ -d "$MISE_NODE_BIN" ] && export PATH="$MISE_NODE_BIN:$PATH"

if ! command -v npm &>/dev/null; then
    warn "npm no encontrado — corre 'mise install' y reintenta."
    warn "Luego instala manualmente: npm install -g @anthropic-ai/claude-code @openai/codex"
else
    log "Instalando claude-code y codex..."
    npm install -g @anthropic-ai/claude-code @openai/codex
    ok "claude $(claude --version 2>/dev/null | head -1)"
    ok "codex instalado"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FASE 6 — Dotfiles (symlinks — solo capa compartida en macOS)
# ═══════════════════════════════════════════════════════════════════════════════
step "Fase 6 — Dotfiles"

link_config() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "Backup: $dst → $dst.bak"
        mv "$dst" "$dst.bak"
    fi
    ln -sf "$src" "$dst"
    ok "$(basename "$dst")"
}

# Zsh (fuente única — editar shared/configs/zsh/zshrc)
link_config "$SHARED_CONFIGS/zsh/zshrc"              "$HOME/.zshrc"
# Starship prompt
link_config "$SHARED_CONFIGS/starship/starship.toml" "$HOME/.config/starship.toml"
# Kitty
link_config "$SHARED_CONFIGS/kitty/kitty.conf"       "$HOME/.config/kitty/kitty.conf"
# Zellij
link_config "$SHARED_CONFIGS/zellij/config.kdl"      "$HOME/.config/zellij/config.kdl"
link_config "$SHARED_CONFIGS/zellij/layouts/dev.kdl" "$HOME/.config/zellij/layouts/dev.kdl"
# Neovim (modular)
link_config "$SHARED_CONFIGS/nvim/init.lua"          "$HOME/.config/nvim/init.lua"
link_config "$SHARED_CONFIGS/nvim/lua/options.lua"   "$HOME/.config/nvim/lua/options.lua"
link_config "$SHARED_CONFIGS/nvim/lua/keymaps.lua"   "$HOME/.config/nvim/lua/keymaps.lua"
link_config "$SHARED_CONFIGS/nvim/lua/plugins.lua"   "$HOME/.config/nvim/lua/plugins.lua"
# Tooling de build compartido — base.mk que incluye el Makefile de cada repo
link_config "$WORKSTATION_DIR/shared/makefiles/base.mk" "$HOME/.config/slicesoft/base.mk"

# ═══════════════════════════════════════════════════════════════════════════════
# LISTO
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}  ¡Máquina lista!${NC}"
echo ""
echo -e "  ${BOLD}Para unirte al ecosistema SliceSoft (repos + docs):${NC}"
echo ""
echo -e "  ${YELLOW}1.${NC} Autentícate en GitHub:"
echo -e "     ${BLUE}gh auth login${NC}"
echo ""
echo -e "  ${YELLOW}2.${NC} Clona el meta-repo (docs, estándares, setup):"
echo -e "     ${BLUE}mkdir -p $SLICESOFT_DIR && gh repo clone slice-soft/slice-soft $SLICESOFT_DIR/slice-soft${NC}"
echo ""
echo -e "  ${YELLOW}3.${NC} Clona todos los repos accesibles de la org:"
echo -e "     ${BLUE}bash $SLICESOFT_DIR/slice-soft/setup.sh${NC}"
echo ""
echo -e "  ${BOLD}Ajustes de la máquina:${NC}"
echo ""
echo -e "  ${YELLOW}4.${NC} Abre una terminal nueva (o ejecuta: source ~/.zshrc)"
echo -e "  ${YELLOW}5.${NC} Activa Copilot en nvim:  :Copilot setup"
echo -e "  ${YELLOW}6.${NC} Para Docker: ejecuta 'colima start'"
echo ""
echo -e "  ${YELLOW}→${NC} Inicia entorno de desarrollo: devenv ~/dev/slicesoft/\$REPO"
echo ""
