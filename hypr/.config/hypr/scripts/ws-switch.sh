#!/usr/bin/env bash
# ws-switch.sh — workspace switch per-monitor con animazione casuale
#
# Usa split-monitor-workspaces (plugin nativo Hyprland) per goto e move.
# Il plugin gestisce autonomamente il mapping per-monitor.
#
# Uso:
#   ws-switch.sh goto <1..10>
#   ws-switch.sh move <1..10>
#   ws-switch.sh next
#   ws-switch.sh prev

ANIMATIONS=(
    "slide,easeInOutQuart,6"
    "slide,easeOutExpo,5"
    "slide,overshot,7"
    "slide,snap,4"
    "slide top,easeOutBack,6"
    "slide top,overshot,7"
    "slide top,easeOutExpo,5"
    "slide bottom,easeInOutQuart,6"
    "slide bottom,easeOutExpo,5"
    "slide bottom,snap,4"
    "slidevert,easeOutExpo,6"
    "slidevert,easeOutBack,7"
    "slidevert,overshot,6"
    "slidevert,snap,4"
    "slidevert,easeInOutQuart,5"
    "fade,easeInOutQuart,5"
    "fade,easeOutExpo,4"
    "fade,overshot,6"
    "slidefade,easeOutExpo,6"
    "slidefade,easeInOutQuart,7"
    "slidefade,overshot,7"
    "slidefade top,easeOutBack,6"
    "slidefade top,overshot,7"
    "slidefade bottom,easeOutExpo,5"
    "slidefade bottom,easeInOutQuart,6"
)

IDX=$((RANDOM % ${#ANIMATIONS[@]}))
ENTRY="${ANIMATIONS[$IDX]}"
STYLE=$(echo "$ENTRY" | cut -d, -f1)
CURVE=$(echo "$ENTRY" | cut -d, -f2)
SPEED=$(echo "$ENTRY" | cut -d, -f3)
hyprctl keyword animation "workspaces,1,$SPEED,$CURVE,$STYLE" 2>/dev/null

# ── Layout per-workspace ───────────────────────────────────────────────────────
# Chiave: "MONITOR_NAME:SLOT" -> nome layout
# Slot non presenti nella mappa -> "DEFAULT_LAYOUT"
declare -A LAYOUT_MAP=(
    ["DP-1:1"]="scrolling"
    ["DP-1:2"]="scrolling"
    ["HDMI-A-1:1"]="monocle"
    ["HDMI-A-1:3"]="master"
)
DEFAULT_LAYOUT="dwindle"

get_layout() {
    local key="${1}:${2}"
    echo "${LAYOUT_MAP[$key]:-$DEFAULT_LAYOUT}"
}

# Estrarre il numero slot dal workspace attivo (con split-monitor-workspaces il
# workspace ID interno è monitor_index * count + slot, ma il nome è il numero diretto)
get_current_slot() {
    local ws_id
    ws_id=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 0')
    echo $(( ((ws_id - 1) % 10) + 1 ))
}

# Applica il layout al workspace corrente:
# 1. Imposta general:layout (ereditato da workspace nuovi)
# 2. Inietta workspace rule con il nome esatto (effettivo su workspace esistenti)
apply_layout() {
    local layout="$1"
    hyprctl keyword general:layout "$layout" >/dev/null 2>&1
    local ws_name
    ws_name=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.name // empty')
    [ -n "$ws_name" ] && \
        hyprctl keyword workspace "name:${ws_name}, layout:${layout}" >/dev/null 2>&1
    local monitor
    monitor=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' | head -1)
    [ -n "$monitor" ] && echo "$layout" > "/tmp/hypr-layout-${monitor}"
}

# ── Rilevamento monitor ───────────────────────────────────────────────────────

get_focused_monitor() {
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name'
}

# ── Compattazione workspace ──────────────────────────────────────────────────
# Dopo uno switch, rimuove i gap nella numerazione spostando le finestre
# verso slot più bassi. Es: ws 1 vuoto, ws 3 occupato → ws 3 diventa ws 1.
cleanup_and_compact() {
    local monitor="$1"
    local count=10
    local offset
    case "$monitor" in
        DP-1)     offset=0 ;;
        HDMI-A-1) offset=$count ;;
        *)        return ;;
    esac

    local current_ws
    current_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id')

    # Workspace con finestre su questo monitor, ordinati per ID
    local -a occupied
    readarray -t occupied < <(hyprctl workspaces -j 2>/dev/null | jq -r --arg mon "$monitor" \
        '[.[] | select(.monitor == $mon and .windows > 0)] | sort_by(.id) | .[].id')

    [[ ${#occupied[@]} -eq 0 ]] && return

    # Controlla se ci sono gap
    local needs_compact=false
    local slot=1
    for ws_id in "${occupied[@]}"; do
        if [[ "$ws_id" -ne $((offset + slot)) ]]; then
            needs_compact=true
            break
        fi
        slot=$((slot + 1))
    done

    [[ "$needs_compact" == "false" ]] && return

    # Esegui compattazione: sposta finestre per riempire i gap
    local new_current_slot=1
    slot=1
    for ws_id in "${occupied[@]}"; do
        local target_id=$((offset + slot))
        [[ "$ws_id" == "$current_ws" ]] && new_current_slot=$slot
        if [[ "$ws_id" -ne "$target_id" ]]; then
            local -a addrs
            readarray -t addrs < <(hyprctl clients -j 2>/dev/null | jq -r --argjson ws "$ws_id" \
                '.[] | select(.workspace.id == $ws) | .address')
            for addr in "${addrs[@]}"; do
                hyprctl dispatch movetoworkspacesilent "${target_id},address:${addr}" >/dev/null 2>&1
            done
        fi
        slot=$((slot + 1))
    done

    # Vai allo slot compattato
    hyprctl dispatch split-workspace "$new_current_slot" >/dev/null 2>&1
}

# ── Parse argomenti ───────────────────────────────────────────────────────────
CMD="$1"
SLOT="${2:-1}"

# ── Dispatch ─────────────────────────────────────────────────────────────────
case "$CMD" in
    goto)
        TARGET_MONITOR=$(get_focused_monitor)
        hyprctl dispatch split-workspace "$SLOT"
        cleanup_and_compact "$TARGET_MONITOR"
        # Applica layout basato sullo slot compattato
        CUR_SLOT=$(get_current_slot)
        TARGET_LAYOUT=$(get_layout "$TARGET_MONITOR" "$CUR_SLOT")
        GOTO_WS_NAME=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.name // empty')
        [ -n "$GOTO_WS_NAME" ] && \
            hyprctl keyword workspace "name:${GOTO_WS_NAME}, layout:${TARGET_LAYOUT}" >/dev/null 2>&1
        echo "$TARGET_LAYOUT" > "/tmp/hypr-layout-${TARGET_MONITOR}"
        ;;
    move)
        TARGET_MONITOR=$(get_focused_monitor)
        local win_count target_offset target_id target_wins
        win_count=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.windows // 0')
        # Se è l'unica finestra, blocca solo se il ws di destinazione è vuoto
        if [[ "$win_count" -le 1 ]]; then
            case "$TARGET_MONITOR" in
                DP-1)     target_offset=0 ;;
                HDMI-A-1) target_offset=10 ;;
                *)        target_offset=0 ;;
            esac
            target_id=$((target_offset + SLOT))
            target_wins=$(hyprctl workspaces -j 2>/dev/null | jq -r --argjson id "$target_id" \
                '[.[] | select(.id == $id)] | .[0].windows // 0')
            [[ "$target_wins" -eq 0 ]] && exit 0
        fi
        hyprctl dispatch split-movetoworkspace "$SLOT"
        cleanup_and_compact "$TARGET_MONITOR"
        ;;
    next)
        TARGET_MONITOR=$(get_focused_monitor)
        hyprctl dispatch split-cycleworkspaces next
        cleanup_and_compact "$TARGET_MONITOR"
        CUR_SLOT=$(get_current_slot)
        [[ -n "$CUR_SLOT" && "$CUR_SLOT" != "0" ]] && \
            apply_layout "$(get_layout "$TARGET_MONITOR" "$CUR_SLOT")"
        ;;
    prev)
        TARGET_MONITOR=$(get_focused_monitor)
        hyprctl dispatch split-cycleworkspaces prev
        cleanup_and_compact "$TARGET_MONITOR"
        CUR_SLOT=$(get_current_slot)
        [[ -n "$CUR_SLOT" && "$CUR_SLOT" != "0" ]] && \
            apply_layout "$(get_layout "$TARGET_MONITOR" "$CUR_SLOT")"
        ;;
esac
