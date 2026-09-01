#!/bin/bash
# SliceSoft — Workstation Installer
# CachyOS / Arch Linux
#
# One-liner (auto-detección de SO vía el dispatcher, sin autenticación):
#   bash <(curl -fsSL https://raw.githubusercontent.com/slice-soft/ss-workstation/main/install.sh)
#
# O directamente desde un clon:
#   bash ~/dev/slicesoft/ss-workstation/linux/install.sh

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
# Raíz del repo (este script vive en <repo>/linux/install.sh).
WORKSTATION_DIR="${SS_WORKSTATION_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}"
SHARED_CONFIGS="$WORKSTATION_DIR/shared/configs"
LINUX_CONFIGS="$WORKSTATION_DIR/linux/configs"
PKGS_FILE="$WORKSTATION_DIR/linux/packages.txt"
SLICESOFT_DIR="$HOME/dev/slicesoft"

# ─── Guards ───────────────────────────────────────────────────────────────────
if ! command -v pacman &>/dev/null; then
    err "Este instalador requiere un sistema Arch (CachyOS, Arch Linux)."
    exit 1
fi

if [ "$EUID" -eq 0 ]; then
    err "No ejecutes este script como root."
    exit 1
fi

if [ ! -d "$SHARED_CONFIGS" ] || [ ! -f "$PKGS_FILE" ]; then
    err "No encuentro el contenido del repo en: $WORKSTATION_DIR"
    err "Usa el one-liner del dispatcher, o clónalo primero:"
    err "  git clone https://github.com/slice-soft/ss-workstation.git ~/dev/slicesoft/ss-workstation"
    exit 1
fi

echo ""
echo -e "${BOLD}  SliceSoft Workstation Setup${NC}"
echo -e "  CachyOS / Arch Linux | $(date '+%Y-%m-%d')"
echo ""

# ─── Lista de paquetes (fuente única: packages.txt) ──────────────────────────
parse_pkgs() { awk -v tag="[$1]" '$1==tag { $1=""; sub(/#.*/,""); gsub(/^[ \t]+|[ \t]+$/,""); if ($0!="") print }' "$PKGS_FILE"; }
mapfile -t PACMAN_PKGS < <(parse_pkgs pacman)
mapfile -t AUR_PKGS    < <(parse_pkgs aur)
mapfile -t NPM_PKGS    < <(parse_pkgs npm)

# ═══════════════════════════════════════════════════════════════════════════════
# FASE 1 — Paquetes del sistema
# ═══════════════════════════════════════════════════════════════════════════════
step "Fase 1 — Paquetes del sistema"

log "Actualizando sistema..."
sudo pacman -Syu --noconfirm

log "Instalando paquetes pacman..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
ok "Paquetes pacman instalados"

# yay (AUR helper)
if ! command -v yay &>/dev/null; then
    log "Instalando yay..."
    TMP_YAY="$(mktemp -d)"
    git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$TMP_YAY"
    (cd "$TMP_YAY" && makepkg -si --noconfirm)
    rm -rf "$TMP_YAY"
    ok "yay instalado"
else
    ok "yay ya presente"
fi

log "Instalando paquetes AUR..."
yay -S --needed --noconfirm "${AUR_PKGS[@]}"
ok "AUR packages instalados"

# Docker group
if ! groups "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    warn "Usuario añadido al grupo docker — efectivo en el próximo login"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FASE 2 — Shell (zsh por defecto; prompt starship vía zshrc compartido)
# ═══════════════════════════════════════════════════════════════════════════════
step "Fase 2 — Shell"

ZSH_BIN="$(command -v zsh)"
if [ "$SHELL" != "$ZSH_BIN" ]; then
    log "Configurando zsh como shell por defecto..."
    chsh -s "$ZSH_BIN"
    ok "Shell por defecto: zsh"
else
    ok "zsh ya es el shell por defecto"
fi

# ~/.zshrc se enlaza en la Fase 5 (Dotfiles) desde shared/configs/zsh/zshrc,
# fuente única portable (starship, mise, atuin, plugins zsh, devenv/lg).
ok "shell base lista — el .zshrc se enlaza en la Fase 5"

# lazygit-smart
mkdir -p "$HOME/.local/bin"
LAZYGIT_SMART="$HOME/.local/bin/lazygit-smart"
if [ ! -f "$LAZYGIT_SMART" ]; then
    log "Instalando lazygit-smart..."
    cp "$SHARED_CONFIGS/zsh/lazygit-smart" "$LAZYGIT_SMART"
    chmod +x "$LAZYGIT_SMART"
    ok "lazygit-smart instalado en ~/.local/bin/"
else
    ok "lazygit-smart ya presente"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FASE 3 — Runtimes via mise (Node LTS + Go + Python)
# ═══════════════════════════════════════════════════════════════════════════════
step "Fase 3 — Runtimes (mise)"

# Activar mise en la sesión actual
export PATH="$HOME/.local/bin:$PATH"
eval "$(~/.local/bin/mise activate bash)" 2>/dev/null || true

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
~/.local/bin/mise install 2>/dev/null || mise install || warn "mise install falló — ejecuta 'mise install' manualmente después"
ok "Runtimes instalados"

# ═══════════════════════════════════════════════════════════════════════════════
# FASE 4 — npm globals: Claude Code + Codex
# ═══════════════════════════════════════════════════════════════════════════════
step "Fase 4 — Claude Code + Codex"

# Asegurar que npm de node 22 está en PATH
MISE_NODE_BIN="$HOME/.local/share/mise/installs/node/$(mise current node 2>/dev/null | head -1)/bin"
export PATH="$MISE_NODE_BIN:$PATH"

if ! command -v npm &>/dev/null; then
    warn "npm no encontrado — asegúrate de correr 'mise install' y luego reinstalar"
    warn "Luego instala manualmente: npm install -g @anthropic-ai/claude-code @openai/codex"
else
    log "Instalando claude-code y codex..."
    npm install -g "${NPM_PKGS[@]}"
    ok "claude $(claude --version 2>/dev/null | head -1)"
    ok "codex instalado"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FASE 5 — Dotfiles (symlinks)
# ═══════════════════════════════════════════════════════════════════════════════
step "Fase 5 — Dotfiles"

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

# ── Compartido (cross-OS) ─────────────────────────────────────────────────────
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

# ── Linux (Wayland WM) ────────────────────────────────────────────────────────
# Hyprland: local.conf por-máquina (monitores/GPU) desde el ejemplo si no existe
if [ ! -f "$HOME/.config/hypr/local.conf" ]; then
    mkdir -p "$HOME/.config/hypr"
    cp "$LINUX_CONFIGS/hyprland/local.conf.example" "$HOME/.config/hypr/local.conf"
    ok "local.conf creado — edita monitores/GPU ahí"
fi
link_config "$LINUX_CONFIGS/hyprland/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
# Waybar (+ estilo y scripts de audio custom)
link_config "$LINUX_CONFIGS/waybar/config.jsonc"    "$HOME/.config/waybar/config.jsonc"
link_config "$LINUX_CONFIGS/waybar/style.css"       "$HOME/.config/waybar/style.css"
if [ -e "$HOME/.config/waybar/scripts" ] && [ ! -L "$HOME/.config/waybar/scripts" ]; then
    mv "$HOME/.config/waybar/scripts" "$HOME/.config/waybar/scripts.bak"
fi
ln -sfn "$LINUX_CONFIGS/waybar/scripts" "$HOME/.config/waybar/scripts"
ok "waybar/scripts"

# ── Waybar como servicio de usuario ───────────────────────────────────────────
# Con "exec-once = waybar" la barra se lanzaba una sola vez y nadie la levantaba
# si se caía — y se cae al actualizar, porque pacman reemplaza glibc/gtk/wayland
# bajo el proceso vivo. Como servicio de graphical-session.target (que uwsm da
# por alcanzado vía "uwsm finalize") systemd la reinicia sola: Restart=on-failure.
link_config "$LINUX_CONFIGS/systemd/waybar.service.d/override.conf" \
            "$HOME/.config/systemd/user/waybar.service.d/override.conf"
systemctl --user daemon-reload
systemctl --user enable waybar.service &>/dev/null
ok "waybar.service habilitado (se reinicia solo)"

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
echo -e "  ${YELLOW}6.${NC} GPU NVIDIA / monitores: edita  ${BLUE}~/.config/hypr/local.conf${NC}"
echo ""
echo -e "  ${YELLOW}7.${NC} ${BOLD}En el próximo login, elige la sesión${NC} ${BLUE}\"Hyprland (uwsm-managed)\"${NC}"
echo -e "     (selector arriba a la derecha en SDDM). El display manager la recuerda,"
echo -e "     así que es una sola vez. Sin ella no se alcanza graphical-session.target"
echo -e "     y waybar.service no arranca — la config cae al modo clásico como respaldo."
echo ""
echo -e "  ${YELLOW}→${NC} Inicia entorno de desarrollo: devenv ~/dev/slicesoft/\$REPO"
echo ""
