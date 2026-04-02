#!/usr/bin/env bash
# recorder.sh — toggle registrazione schermo con wf-recorder

OUTPUT_DIR="$HOME/Video"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
OUTPUT_FILE="$OUTPUT_DIR/rec_$TIMESTAMP.mp4"
PIDFILE="/tmp/wf-recorder.pid"

mkdir -p "$OUTPUT_DIR"

if pgrep -x wf-recorder > /dev/null; then
    pkill -INT wf-recorder
    rm -f "$PIDFILE"
    notify-send "Registrazione" "Salvata in ~/Video" -i media-record -t 3000
else
    # Scegli monitor se ce ne sono più di uno
    MONITOR=$(hyprctl monitors -j | jq -r '.[].name' | \
        wofi --dmenu --prompt "// REGISTRA MONITOR" --lines 3)
    [ -z "$MONITOR" ] && exit 0

    wf-recorder -o "$MONITOR" -f "$OUTPUT_FILE" --codec libx264 &
    echo $! > "$PIDFILE"
    notify-send "Registrazione" "Avviata su $MONITOR" -i media-record -t 2000
fi
