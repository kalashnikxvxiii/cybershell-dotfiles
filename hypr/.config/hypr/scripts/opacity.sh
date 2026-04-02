#!/usr/bin/env bash
# opacity.sh — toggle / increase / decrease active window opacity (Hyprland 0.53+)
#   toggle  → 1.0 ↔ 0.6
#   up      → +0.1  (max 1.0)
#   down    → -0.1  (min 0.1)

STATE_DIR="/tmp/hypr-opacity"
mkdir -p "$STATE_DIR"

ADDR=$(hyprctl activewindow -j | jq -r '.address')
[ -z "$ADDR" ] || [ "$ADDR" = "null" ] && exit 1

STATE_FILE="$STATE_DIR/$ADDR"

get_opacity() {
    [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "1.0"
}

set_opacity() {
    local val
    val=$(awk -v v="$1" 'BEGIN { x=v+0; if(x<0.1) x=0.1; else if(x>1.0) x=1.0; printf "%.1f", x }')
    echo "$val" > "$STATE_FILE"
    hyprctl dispatch setprop address:"$ADDR" opacity "$val"
    hyprctl notify 1 1500 "rgb(0abdc6)" " opacity: $(awk -v v="$val" 'BEGIN{printf "%d%%", v*100}')"
}

case "$1" in
    toggle)
        current=$(get_opacity)
        if [ "$current" = "1.0" ]; then
            set_opacity "0.9"
        else
            set_opacity "1.0"
            rm -f "$STATE_FILE"
        fi
        ;;
    up)
        current=$(get_opacity)
        new=$(awk -v v="$current" 'BEGIN { printf "%.1f", v + 0.1 }')
        set_opacity "$new"
        ;;
    down)
        current=$(get_opacity)
        new=$(awk -v v="$current" 'BEGIN { printf "%.1f", v - 0.1 }')
        set_opacity "$new"
        ;;
    *)
        echo "Usage: $0 toggle|up|down" >&2
        exit 1
        ;;
esac
