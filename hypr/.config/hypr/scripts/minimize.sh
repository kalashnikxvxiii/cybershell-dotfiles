#!/usr/bin/env bash
# minimize.sh — gestione finestre minimizzate
# Usage: minimize.sh [minimize|restore|status]

SPECIAL="special:minimized"

get_minimized() {
    hyprctl clients -j | jq "[.[] | select(.workspace.name == \"$SPECIAL\")]"
}

case "${1:-status}" in

    minimize)
        ACTIVE_MON=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
        hyprctl dispatch movetoworkspacesilent special:minimized
        hyprctl dispatch focusmonitor "$ACTIVE_MON"
        # special:minimized corrompe lo stato interno di hypr-local-workspaces —
        # riavvialo in background per resettarlo (< 150ms, trasparente all'utente)
        (pkill -f hypr-local-workspaces 2>/dev/null; sleep 0.1; hypr-local-workspaces init &) &
        ;;

    restore)
        if pgrep -x wofi > /dev/null; then pkill -x wofi; exit 0; fi

        WINDOWS_JSON=$(get_minimized)
        COUNT=$(echo "$WINDOWS_JSON" | jq 'length')

        if [ "$COUNT" -eq 0 ]; then
            notify-send "Nessuna finestra minimizzata" -t 2000
            exit 0
        fi

        # Mostra lista in wofi: "classe — titolo"
        SELECTED=$(echo "$WINDOWS_JSON" | \
            jq -r '.[] | .class + " — " + .title' | \
            wofi --dmenu --prompt "// RIPRISTINA FINESTRA")

        if [ -n "$SELECTED" ]; then
            ADDR=$(echo "$WINDOWS_JSON" | \
                jq -r --arg sel "$SELECTED" \
                '.[] | select((.class + " — " + .title) == $sel) | .address' | head -1)
            ACTIVE_WS=$(hyprctl activeworkspace -j | jq -r '.id')
            hyprctl dispatch movetoworkspace "$ACTIVE_WS,address:$ADDR"
            hyprctl dispatch focuswindow "address:$ADDR"
        fi
        ;;

    status)
        WINDOWS_JSON=$(get_minimized)
        COUNT=$(echo "$WINDOWS_JSON" | jq 'length')

        if [ "$COUNT" -gt 0 ]; then
            TOOLTIP=$(echo "$WINDOWS_JSON" | jq -r '[.[] | "• " + .class + ": " + .title] | join("\n")')
            jq -n --arg text "󰘸  $COUNT" --arg tooltip "$TOOLTIP" \
                '{"text": $text, "tooltip": $tooltip, "class": "active"}'
        else
            echo '{"text": "", "class": "empty"}'
        fi
        ;;

esac
