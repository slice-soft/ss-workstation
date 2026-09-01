#!/usr/bin/env bash
# SliceSoft — Capturas de pantalla (Hyprland / Wayland)
#
# Uso: screenshot.sh <modo>
#   region   selecciona un área con el ratón      (≈ Cmd+Shift+4 en macOS)
#   full     el monitor donde está el foco        (≈ Cmd+Shift+3)
#   window   la ventana enfocada
#   edit     selecciona un área y la abre para anotar  (≈ Cmd+Shift+5)
#
# Toda captura hace las DOS cosas: se guarda en <Imágenes>/Capturas y se copia
# al portapapeles. Es lo que uno quiere el 90% de las veces — pegarla de una en
# Slack/Notion sin perder el archivo por si hace falta más tarde.

set -euo pipefail

MODE="${1:-region}"

# ─── Destino ─────────────────────────────────────────────────────────────────
# xdg-user-dir respeta el idioma del sistema (~/Imágenes en es, ~/Pictures en en),
# así que la misma config sirve en cualquier máquina del equipo.
PICTURES="$(xdg-user-dir PICTURES 2>/dev/null || true)"
[ -n "$PICTURES" ] || PICTURES="$HOME/Pictures"
DEST_DIR="$PICTURES/Capturas"
mkdir -p "$DEST_DIR"
DEST="$DEST_DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

# ─── Notificaciones (opcionales) ─────────────────────────────────────────────
# Sin daemon (dunst/mako/swaync) notify-send se queda esperando a que D-Bus
# active un servicio que no existe: al fondo y con timeout, para que la captura
# nunca se bloquee solo por no tener notificaciones.
notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    ( timeout 2 notify-send -a "Capturas" -i "${2:-}" "$1" >/dev/null 2>&1 || true ) &
}

die() { notify "$1" dialog-error; exit 1; }

# ─── Geometría, según el modo ────────────────────────────────────────────────
# Ojo: esto va aquí y no dentro de $( ) en la llamada a grim. Un `exit` dentro
# de una sustitución de comandos solo mata la subshell — cancelar slurp con Esc
# seguiría capturando, con geometría vacía.
GEOM=""
MONITOR=""

case "$MODE" in
    region|edit)
        # slurp devuelve !=0 al cancelar con Esc o clic derecho. Eso no es un
        # fallo: es que te arrepentiste. Salimos limpio y sin dejar archivos.
        GEOM="$(slurp -d 2>/dev/null)" || { notify "Captura cancelada" dialog-information; exit 0; }
        [ -n "$GEOM" ] || exit 0
        ;;
    window)
        GEOM="$(hyprctl -j activewindow 2>/dev/null \
                | jq -er '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" \
            || die "No hay ventana enfocada"
        ;;
    full)
        MONITOR="$(hyprctl -j activeworkspace 2>/dev/null | jq -er '.monitor')" \
            || die "No detecto el monitor activo"
        ;;
    *)
        echo "Modo desconocido: $MODE (usa: region | full | window | edit)" >&2
        exit 2
        ;;
esac

# ─── Captura ─────────────────────────────────────────────────────────────────
if [ "$MODE" = "edit" ]; then
    # El editor se encarga de guardar y copiar cuando confirmas (Ctrl+S / Ctrl+C).
    if command -v satty >/dev/null 2>&1; then
        grim -g "$GEOM" - | satty --filename - \
                                  --output-filename "$DEST" \
                                  --copy-command wl-copy \
                                  --early-exit
        exit 0
    elif command -v swappy >/dev/null 2>&1; then
        grim -g "$GEOM" - | swappy -f - -o "$DEST"
        exit 0
    fi
    # Sin editor instalado no perdemos la captura: cae a guardar + copiar.
    grim -g "$GEOM" "$DEST"
    notify "Sin editor (instala satty) — guardada sin anotar" dialog-warning
elif [ -n "$MONITOR" ]; then
    grim -o "$MONITOR" "$DEST"
else
    grim -g "$GEOM" "$DEST"
fi

wl-copy --type image/png < "$DEST"
notify "Captura copiada — $(basename "$DEST")" "$DEST"
