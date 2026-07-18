#!/usr/bin/env bash
# SliceSoft — Workstation Installer (dispatcher)
# Detecta el sistema operativo, clona este repo PÚBLICO si hace falta y ejecuta
# el instalador correspondiente.
#
# One-liner (auto-detecta CachyOS/Arch o macOS, sin autenticación):
#   bash <(curl -fsSL https://raw.githubusercontent.com/slice-soft/ss-workstation/main/install.sh)

set -euo pipefail

ORG="slice-soft"
REPO="ss-workstation"
WORKSTATION_DIR="${SS_WORKSTATION_DIR:-$HOME/dev/slicesoft/$REPO}"

case "$(uname -s)" in
    Linux)  OS="linux" ;;
    Darwin) OS="macos" ;;
    *) echo "SO no soportado: $(uname -s). Soportados: Linux (CachyOS/Arch), macOS." >&2; exit 1 ;;
esac

# Si corre desde un clon del repo, úsalo directamente.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/$OS/install.sh" ]; then
    exec bash "$SELF_DIR/$OS/install.sh" "$@"
fi

# One-liner: este repo es PÚBLICO, así que se clona sin credenciales.
if ! command -v git >/dev/null 2>&1; then
    echo "[SS] git no está instalado; instalándolo..."
    if [ "$OS" = "linux" ]; then
        sudo pacman -S --needed --noconfirm git
    else
        xcode-select --install 2>/dev/null || true
        command -v git >/dev/null 2>&1 || {
            echo "[SS] Acepta la instalación de las Command Line Tools y reejecuta el one-liner." >&2
            exit 1
        }
    fi
fi

mkdir -p "$(dirname "$WORKSTATION_DIR")"
if [ ! -d "$WORKSTATION_DIR/.git" ]; then
    echo "[SS] Clonando $ORG/$REPO en $WORKSTATION_DIR ..."
    git clone "https://github.com/$ORG/$REPO.git" "$WORKSTATION_DIR"
else
    git -C "$WORKSTATION_DIR" pull --ff-only 2>/dev/null || true
fi

exec bash "$WORKSTATION_DIR/$OS/install.sh" "$@"
