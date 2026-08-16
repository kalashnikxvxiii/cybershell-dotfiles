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

source "$(dirname "$0")/hyprctl-lua-compat.sh"
# smw è il global esposto da hyprland.lua dopo `require("split-monitor-workspaces")`.
# I metodi smw.workspace(N), smw.move_to_workspace(N), smw.cycle_workspaces(dir)
# ritornano CLOSURES (function() ... end) — vanno passate a hl.dispatch() per fire-and-forget.

IDX=$((RANDOM % ${#ANIMATIONS[@]}))
ENTRY="${ANIMATIONS[$IDX]}"
STYLE=$(echo "$ENTRY" | cut -d, -f1)
CURVE=$(echo "$ENTRY" | cut -d, -f2)
SPEED=$(echo "$ENTRY" | cut -d, -f3)
he "hl.animation({leaf=\"workspaces\", enabled=true, speed=$SPEED, bezier=\"$CURVE\", style=\"$STYLE\"})" 2>/dev/null

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
    he "hl.config({general = {layout = \"$layout\"}})" >/dev/null 2>&1
    local ws_name
    ws_name=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.name // empty')
    [ -n "$ws_name" ] && \
        he "hl.workspace_rule({workspace = \"name:${ws_name}\", layout = \"${layout}\"})" >/dev/null 2>&1
    local monitor
    monitor=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' | head -1)
    [ -n "$monitor" ] && echo "$layout" > "/tmp/hypr-layout-${monitor}"
}

# ── Rilevamento monitor ───────────────────────────────────────────────────────

get_focused_monitor() {
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name'
}

# Workspace number with at least one window on specific monitor
get_occupied_count() {
    local monitor="$1"
    hyprctl workspaces -j 2>/dev/null | jq -r --arg mon "$monitor" \
        '[.[] | select(.monitor == $mon and .windows > 0)] | length'
}

# Destination slot: cycle in range [1..min(occupied+1, max_ws)]
# Forward -> +1, wrap to 1 over the final "makeable"
# Bakcward -> -1, wrap to "extra slot" (occupied+1, capped on max_ws)
WS_MAX=10   # match with smw workspace_count

compute_next_slot() {
    local cur=$1
    local occ=$2
    local cap=$(( occ + 1 < WS_MAX ? occ + 1 : WS_MAX ))
    local next=$(( cur + 1 ))
    (( next > cap )) && next=1
    echo "$next"
}

compute_prev_slot() {
    local cur=$1
    local occ=$2
    local cap=$(( occ + 1 < WS_MAX ? occ + 1 : WS_MAX ))
    local prev=$(( cur - 1 ))
    (( prev < 1 )) && prev=$cap
    echo "$prev"
}

# ── Workspace compactation ──────────────────────────────────────────────────
# After a switch, remove the gaps between enumeration moving the windows
# in lower slots. Es: ws 1 empty, ws 2 occupied → ws 2 become ws 1.
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

    # Workspace with windows on this monitor, ordered by ID
    local -a occupied
    readarray -t occupied < <(hyprctl workspaces -j 2>/dev/null | jq -r --arg mon "$monitor" \
        '[.[] | select(.monitor == $mon and .windows > 0)] | sort_by(.id) | .[].id')

    [[ ${#occupied[@]} -eq 0 ]] && return

    # Check if there are gaps
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

    # Default for the user's destination slot (3 cases):
    #   A) current_ws is in `occupied` → overwritten in the loop with its new position
    #   B) current_ws is an empty slot INSIDE the range [1..len(occupied)] (es. ws
    #      just emptied): the compaction will fill that slot with the content of the above
    #      ws → user remain on its own slot.
    #   C) current_ws is an empty slot ABOVE all others occupied (es. SUPER+N with
    #      N > last_occupied — the user wants "a new workspace after the last")
    #      → land on the first ewmpty slot post-compaction = len(occupied)+1.
    #
    # Bug fix: before the default was hardcoded at 1, so in the C case the user was
    # moved on the first workspace ("jump" effect noted).
    local current_slot=$((current_ws - offset))
    local new_current_slot
    if (( current_slot > ${#occupied[@]} )); then
        new_current_slot=$((${#occupied[@]} + 1))
    else
        new_current_slot=$current_slot
    fi

    # Execute compacting: move windows to fill gaps
    slot=1
    for ws_id in "${occupied[@]}"; do
        local target_id=$((offset + slot))
        [[ "$ws_id" == "$current_ws" ]] && new_current_slot=$slot
        if [[ "$ws_id" -ne "$target_id" ]]; then
            local -a addrs
            readarray -t addrs < <(hyprctl clients -j 2>/dev/null | jq -r --argjson ws "$ws_id" \
                '.[] | select(.workspace.id == $ws) | .address')
            for addr in "${addrs[@]}"; do
                # movetoworkspacesilent N,address:X — window selector is called `window`,
                # NOT `address` (the API error is: "Expected: direction, x+y(+relative),
                # workspace, into_group, out_of_group" — address not exist and gets IGNORED,
                # making moves the ACTIVE window instead of the specified one).
                hd "hl.dsp.window.move({workspace = ${target_id}, window = \"address:${addr}\"})" >/dev/null 2>&1
            done
        fi
        slot=$((slot + 1))
    done

    # Go to final slot (no-op if already there)
    hp "hl.dispatch(smw.workspace(\"$new_current_slot\"))" >/dev/null 2>&1
}

# ── Parse args ───────────────────────────────────────────────────────────
CMD="$1"
SLOT="${2:-1}"

# ── Dispatch ─────────────────────────────────────────────────────────────────
case "$CMD" in
    goto)
        TARGET_MONITOR=$(get_focused_monitor)
        OCC=$(get_occupied_count "$TARGET_MONITOR")
        CAP=$(( OCC + 1 < WS_MAX ? OCC + 1 : WS_MAX ))
        (( SLOT > CAP )) && SLOT=$CAP
        hp "hl.dispatch(smw.workspace(\"$SLOT\"))"
        cleanup_and_compact "$TARGET_MONITOR"
        # Apply layout based on compacted slot
        CUR_SLOT=$(get_current_slot)
        TARGET_LAYOUT=$(get_layout "$TARGET_MONITOR" "$CUR_SLOT")
        GOTO_WS_NAME=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.name // empty')
        [ -n "$GOTO_WS_NAME" ] && \
            he "hl.workspace_rule({workspace = \"name:${GOTO_WS_NAME}\", layout = \"${TARGET_LAYOUT}\"})" >/dev/null 2>&1
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
        hp "hl.dispatch(smw.move_to_workspace(\"$SLOT\"))"
        cleanup_and_compact "$TARGET_MONITOR"
        ;;
    next)
        TARGET_MONITOR=$(get_focused_monitor)
        CUR_SLOT=$(get_current_slot)
        OCC=$(get_occupied_count "$TARGET_MONITOR")
        TARGET_SLOT=$(compute_next_slot "$CUR_SLOT" "$OCC")
        hp "hl.dispatch(smw.workspace(\"$TARGET_SLOT\"))"
        cleanup_and_compact "$TARGET_MONITOR"
        CUR_SLOT=$(get_current_slot)
        [[ -n "$CUR_SLOT" && "$CUR_SLOT" != "0" ]] && \
            apply_layout "$(get_layout "$TARGET_MONITOR" "$CUR_SLOT")"
        ;;
    prev)
        TARGET_MONITOR=$(get_focused_monitor)
        CUR_SLOT=$(get_current_slot)
        OCC=$(get_occupied_count "$TARGET_MONITOR")
        TARGET_SLOT=$(compute_prev_slot "$CUR_SLOT" "$OCC")
        hp "hl.dispatch(smw.workspace(\"$TARGET_SLOT\"))"
        cleanup_and_compact "$TARGET_MONITOR"
        CUR_SLOT=$(get_current_slot)
        [[ -n "$CUR_SLOT" && "$CUR_SLOT" != "0" ]] && \
            apply_layout "$(get_layout "$TARGET_MONITOR" "$CUR_SLOT")"
        ;;
    insert)
        TARGET_MONITOR=$(get_focused_monitor)
        CUR_SLOT=$(get_current_slot)
        OCC=$(get_occupied_count "$TARGET_MONITOR")

        # Cap: no space if already at limit
        if (( OCC >= WS_MAX )); then
            hyprctl notify 1 2000 "rgb(c5003c)" " Max workspace ($WS_MAX) reached"
            exit 0
        fi

        # Destination slot: from ws 1 -> 2 (after first), otherwise current slot
        if (( CUR_SLOT == 1 )); then
            NEW_SLOT=2
        else
            NEW_SLOT=$CUR_SLOT
        fi

        # Offset monitor
        case "$TARGET_MONITOR" in
            DP-1)       OFFSET=0 ;;
            HDMI-A-1)   OFFSET=10 ;;
            *)          exit 0 ;;
        esac

        # Shift forward workspaces from NEW_SLOT..OCC to slot+1
        # In reverse order (from last) to not overlap
        for (( slot=OCC; slot>=NEW_SLOT; slot-- )); do
            src_id=$((OFFSET + slot))
            tgt_id=$((OFFSET + slot + 1))
            readarray -t addrs < <(hyprctl clients -j 2>/dev/null | jq -r --argjson ws "$src_id" \
                '.[] | select(.workspace.id == $ws) | .address')
            for addr in "${addrs[@]}"; do
                hd "hl.dsp.window.move({workspace = ${tgt_id}, window = \"address:${addr}\"})" >/dev/null 2>&1
            done
        done

        # Go to new empty slot
        hp "hl.dispatch(smw.workspace(\"$NEW_SLOT\"))"

        # Apply default layout for new slot
        CUR_SLOT=$(get_current_slot)
        [[ -n "$CUR_SLOT" && "$CUR_SLOT" != "0" ]] && \
            apply_layout "$(get_layout "$TARGET_MONITOR" "$CUR_SLOT")"
        ;;
    movesilent)
        TARGET_MONITOR=$(get_focused_monitor)
        win_count=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.windows // 0')
        [[ "$win_count" -le 0 ]] && exit 0

        # Monitor offset
        case "$TARGET_MONITOR" in
            DP-1)       target_offset=0 ;;
            HDMI-A-1)   target_offset=10 ;;
            *)          target_offset=0 ;;
        esac
        target_id=$((target_offset + SLOT))

        # Move silent: the window go to ws target, focus keep where we at
        hd "hl.dsp.window.move({workspace = ${target_id}, follow = false})"
        ;;
esac
