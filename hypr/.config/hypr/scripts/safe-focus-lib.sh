#!/usr/bin/env bash
# Bypassa il dispatcher movefocus di Hyprland per evitare il crash
# CReservedArea con split-monitor-workspaces.
# Usa focuswindow con rilevamento direzionale manuale.

# Trova e focalizza la finestra tiled piu' vicina in una direzione.
# Se non trova candidati, usa focusmonitor per il cross-monitor.
# Uso: safe_movefocus <dir> [cross_monitor_name]
#   dir: l, r, u, d
#   cross_monitor_name: monitor su cui saltare se siamo al bordo (opzionale)
safe_movefocus() {
    local dir="$1"
    local cross_target="$2"

    local active_json
    active_json=$(hyprctl activewindow -j 2>/dev/null)
    local active_addr
    active_addr=$(echo "$active_json" | jq -r '.address // empty')

    # Nessuna finestra attiva — cross-monitor se possibile
    if [ -z "$active_addr" ] || [ "$active_addr" = "null" ]; then
        [ -n "$cross_target" ] && hyprctl dispatch focusmonitor "$cross_target"
        return
    fi

    local ws_id ax ay aw ah
    ws_id=$(echo "$active_json" | jq -r '.workspace.id')
    ax=$(echo "$active_json" | jq '.at[0]')
    ay=$(echo "$active_json" | jq '.at[1]')
    aw=$(echo "$active_json" | jq '.size[0]')
    ah=$(echo "$active_json" | jq '.size[1]')

    local cx=$((ax + aw / 2))
    local cy=$((ay + ah / 2))

    # Trova la finestra tiled piu' vicina nella direzione richiesta.
    # Ordina per distanza primaria (asse del movimento), poi per distanza
    # perpendicolare al quadrato come tiebreaker.
    local candidate
    candidate=$(hyprctl clients -j 2>/dev/null | jq -r \
        --argjson ws "$ws_id" \
        --arg addr "$active_addr" \
        --argjson cx "$cx" --argjson cy "$cy" \
        --arg dir "$dir" '
        [.[] | select(.workspace.id == $ws and .mapped == true and .hidden == false
               and .floating == false and .address != $addr)
         | (.at[0] + .size[0]/2) as $tx
         | (.at[1] + .size[1]/2) as $ty
         | if   $dir == "l" and $tx < $cx then {a: .address, p: ($cx-$tx), s: (($cy-$ty)*($cy-$ty))}
           elif $dir == "r" and $tx > $cx then {a: .address, p: ($tx-$cx), s: (($cy-$ty)*($cy-$ty))}
           elif $dir == "u" and $ty < $cy then {a: .address, p: ($cy-$ty), s: (($cx-$tx)*($cx-$tx))}
           elif $dir == "d" and $ty > $cy then {a: .address, p: ($ty-$cy), s: (($cx-$tx)*($cx-$tx))}
           else empty end
        ] | sort_by([.p, .s]) | first | .a // empty')

    if [ -n "$candidate" ]; then
        hyprctl dispatch focuswindow "address:$candidate"
    elif [ -n "$cross_target" ]; then
        hyprctl dispatch focusmonitor "$cross_target"
    fi
}

# Monitor adiacente al monitor focused in una direzione orizzontale.
# Ritorna il nome del monitor, o vuoto se non esiste.
get_adjacent_monitor() {
    local dir="$1"  # l o r
    local mon_x
    mon_x=$(hyprctl monitors -j 2>/dev/null \
        | jq -r '.[] | select(.focused) | .x')

    if [ "$dir" = "l" ]; then
        hyprctl monitors -j 2>/dev/null | jq -r \
            --argjson cur "$mon_x" \
            '[.[] | select(.x < $cur)] | sort_by(.x) | last | .name // empty'
    else
        hyprctl monitors -j 2>/dev/null | jq -r \
            --argjson cur "$mon_x" \
            '[.[] | select(.x > $cur)] | sort_by(.x) | first | .name // empty'
    fi
}
