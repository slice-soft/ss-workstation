#!/usr/bin/env bash
# Control de volumen + dispositivo para Waybar (PipeWire / wpctl)
# Uso:
#   volume.sh          -> imprime JSON para el modulo custom/volume
#   volume.sh up|down  -> ajusta volumen (paso 5%) y refresca la barra
#   volume.sh mute     -> alterna silencio y refresca la barra
#   volume.sh menu     -> abre el selector de dispositivo (audio-menu.sh)

SINK="@DEFAULT_AUDIO_SINK@"
STEP="5"            # paso por notch de scroll, en % (sube/baja de 5 en 5)
MAX="1.5"           # 150% tope al subir con scroll
BARS=10             # segmentos de la barra visual
SIGNAL=8            # debe coincidir con "signal" del modulo en config.jsonc

refresh() { pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null; }

case "$1" in
  up)   wpctl set-volume -l "$MAX" "$SINK" "${STEP}%+" ; refresh ; exit ;;
  down) wpctl set-volume "$SINK" "${STEP}%-" ; refresh ; exit ;;
  mute) wpctl set-mute "$SINK" toggle ; refresh ; exit ;;
  menu) exec "$(dirname "$0")/audio-menu.sh" ;;
esac

# --- Estado actual ---
read -r _ raw muted < <(wpctl get-volume "$SINK" 2>/dev/null)
# raw viene como "0.85"; muted añade "[MUTED]"
vol=$(awk -v v="$raw" 'BEGIN{printf "%d", v*100 + 0.5}')
[ -z "$vol" ] && vol=0

# Nombre amigable del dispositivo activo
default_name=$(pactl get-default-sink 2>/dev/null)
desc=$(pactl list sinks 2>/dev/null | awk -v n="$default_name" '
  $1=="Name:" {cur=($2==n)}
  cur && $1=="Description:" {sub(/^[^:]*: /,""); print; exit}')
[ -z "$desc" ] && desc="$default_name"

# Barra de bloques (slider visual)
filled=$(( (vol * BARS + 99) / 100 ))
[ "$filled" -gt "$BARS" ] && filled="$BARS"
[ "$filled" -lt 0 ] && filled=0
bar=""
for ((i=0; i<BARS; i++)); do
  if [ "$i" -lt "$filled" ]; then bar+="▮"; else bar+="▯"; fi
done

# Icono / clase segun estado
if [ "$muted" = "[MUTED]" ]; then
  icon="󰝟"; class="muted"; text="$icon  MUTE"
else
  if   [ "$vol" -eq 0 ];  then icon="󰸈"
  elif [ "$vol" -lt 34 ]; then icon="󰕿"
  elif [ "$vol" -lt 67 ]; then icon="󰖀"
  else                          icon="󰕾"; fi
  class="unmuted"; text="$icon  $bar $vol%"
fi

tooltip="$desc\n$vol%  ·  scroll: volumen · clic izq: mute · clic der: dispositivo · clic med: pavucontrol"

printf '{"text":"%s","tooltip":"%s","percentage":%d,"class":"%s"}\n' \
  "$text" "$tooltip" "$vol" "$class"
