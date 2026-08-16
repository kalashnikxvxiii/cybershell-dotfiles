#!/usr/bin/env bash
# Subscribe events to Hyprland and enable/disable DND of swaync
# on fullscreen state (game/film/etc.)

set -u

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Wait swaync to be up
until swaync-client -D 2>/dev/null; do sleep 1; done

handle() {
    local event="${1%%>>*}"
    local value="${1##*>>}"

    case "$event" in
        fullscreen)
            if [[ "$value" == "1" ]]; then
                swaync-client --dnd-on -sw 2>/dev/null
            else
                swaync-client --dnd-off -sw 2>/dev/null
            fi
            ;;
    esac
}

socat -U - "UNIX-CONNECT:$SOCKET" 2>/dev/null | while read -r line; do
    handle "$line"
done