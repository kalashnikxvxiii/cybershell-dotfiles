#!/usr/bin/env bash
# scratchpad.sh — pull-one | pull-all
# Estrae finestre dallo scratchpad (special:magic) al workspace regolare corrente.

ACTION="${1:-pull-one}"
SPECIAL="special:magic"

# Restituisce l'ID del workspace regolare (> 0) sul monitor focalizzato.
# Quando lo scratchpad è aperto, il monitor potrebbe riportare un id negativo
# (workspace speciale): in quel caso cerca l'ultimo workspace regolare su
# quel monitor, oppure cade su 1.
get_target_workspace() {
    local mon_name ws_id

    mon_name=$(hyprctl monitors -j | jq -r '[.[] | select(.focused == true)][0].name')
    ws_id=$(hyprctl monitors -j   | jq -r '[.[] | select(.focused == true)][0].activeWorkspace.id')

    if [ "$ws_id" -gt 0 ] 2>/dev/null; then
        echo "$ws_id"
    else
        # scratchpad aperto: trova l'ultimo workspace regolare sul monitor
        hyprctl workspaces -j | jq --arg mon "$mon_name" \
            '[.[] | select(.monitor == $mon and .id > 0)] |
             if length > 0 then sort_by(.id) | last | .id else 1 end'
    fi
}

# Estrae la finestra focalizzata dallo scratchpad al workspace corrente.
pull_one() {
    local target
    target=$(get_target_workspace)

    # Verifica che la finestra attiva sia davvero nello scratchpad
    local cur_ws
    cur_ws=$(hyprctl activewindow -j | jq -r '.workspace.name')

    if [ "$cur_ws" != "$SPECIAL" ]; then
        notify-send "Scratchpad" "La finestra attiva non è nello scratchpad." -t 2000
        return 1
    fi

    hyprctl dispatch movetoworkspace "$target"
}

# Estrae tutte le finestre dallo scratchpad al workspace corrente.
pull_all() {
    local target
    target=$(get_target_workspace)

    local addresses
    mapfile -t addresses < <(
        hyprctl clients -j | jq -r --arg sp "$SPECIAL" \
            '.[] | select(.workspace.name == $sp) | .address'
    )

    if [ "${#addresses[@]}" -eq 0 ]; then
        notify-send "Scratchpad" "Scratchpad già vuoto." -t 1500
        return
    fi

    for addr in "${addresses[@]}"; do
        hyprctl dispatch movetoworkspacesilent "${target},address:${addr}"
    done

    notify-send "Scratchpad" "${#addresses[@]} finestra/e spostata/e al workspace ${target}." -t 2000
}

case "$ACTION" in
    pull-one) pull_one ;;
    pull-all) pull_all ;;
    *)        echo "Uso: $0 pull-one|pull-all" ;;
esac
