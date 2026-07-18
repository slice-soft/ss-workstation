#!/usr/bin/env bash
# Selector de dispositivo de salida (sink) para Waybar, vía wofi.
# Lista los sinks disponibles, permite elegir el activo y mueve
# los streams que ya estaban sonando al nuevo dispositivo.

default_name=$(pactl get-default-sink 2>/dev/null)

# Construye lista: "Descripción amigable\tnombre_interno"
mapfile -t rows < <(pactl list sinks 2>/dev/null | awk '
  $1=="Name:"        {name=$2}
  $1=="Description:" {sub(/^[^:]*: /,""); print $0 "\t" name}')

# Menú visible (marca el activo con ●)
menu=""
for row in "${rows[@]}"; do
  desc="${row%%$'\t'*}"; name="${row##*$'\t'}"
  if [ "$name" = "$default_name" ]; then menu+="● $desc\n"; else menu+="  $desc\n"; fi
done

choice=$(printf "%b" "$menu" | wofi --dmenu --prompt "Salida de audio" --width 420 --height 260 2>/dev/null)
[ -z "$choice" ] && exit 0

# Limpia el marcador y espacios de la selección
choice="${choice#● }"; choice="${choice#  }"

# Resuelve el nombre interno a partir de la descripción elegida
sel_name=""
for row in "${rows[@]}"; do
  desc="${row%%$'\t'*}"; name="${row##*$'\t'}"
  [ "$desc" = "$choice" ] && sel_name="$name" && break
done
[ -z "$sel_name" ] && exit 0

# Cambia el default y arrastra los streams existentes
pactl set-default-sink "$sel_name"
for input in $(pactl list sink-inputs short 2>/dev/null | cut -f1); do
  pactl move-sink-input "$input" "$sel_name" 2>/dev/null
done

pkill -RTMIN+8 waybar 2>/dev/null
