#!/usr/bin/env bash
direction="$1"  # "l" o "r"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/safe-focus-lib.sh"

layout=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.tiledLayout // "dwindle"')

if [ "$layout" = "scrolling" ]; then
    # Scrolling: se c'e' un monitor nella direzione richiesta, vai direttamente li'.
    # Altrimenti scorri tra le finestre del workspace.
    cross=$(get_adjacent_monitor "$direction")
    if [ -n "$cross" ]; then
        hyprctl dispatch focusmonitor "$cross"
    else
        safe_movefocus "$direction"
    fi
else
    # dwindle / qualsiasi altro layout
    cross=$(get_adjacent_monitor "$direction")
    safe_movefocus "$direction" "$cross"
fi
