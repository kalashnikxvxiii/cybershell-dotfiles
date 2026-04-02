#!/usr/bin/env bash
#
# wallpaper.sh — rotazione e sync wallpaper per hyprpaper
# Uso: wallpaper.sh {rotate|toggle-sync}

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
STATE_DIR="$HOME/.local/share/hyprpaper"
SYNC_FILE="$STATE_DIR/sync"

# Monitor ordinati: il primo è il primario
MONITORS=("HDMI-A-1" "DP-1")
PRIMARY="${MONITORS[0]}"

# Lista wallpaper in ordine alfabetico
mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | sort)
TOTAL="${#WALLPAPERS[@]}"

# ── Funzioni di stato ──────────────────────────

init() {
    mkdir -p "$STATE_DIR"
    # Sync attivo di default
    [[ -f "$SYNC_FILE" ]] || echo "synced" > "$SYNC_FILE"
    # Inizializza indice monitor trovando il wallpaper attuale
    local current_wp="/home/kalashnikxv/Pictures/wallpapers/wallhaven-kxwp7q.jpg"
    local default_idx=0
    for i in "${!WALLPAPERS[@]}"; do
        [[ "${WALLPAPERS[$i]}" == "$current_wp" ]] && default_idx=$i && break
    done
    for mon in "${MONITORS[@]}"; do
        [[ -f "$STATE_DIR/$mon" ]] || echo "$default_idx" > "$STATE_DIR/$mon"
    done
}

get_index() {
    cat "$STATE_DIR/$1" 2>/dev/null || echo "0"
}

next_index() {
    echo $(( ($1 + 1) % TOTAL ))
}

set_wallpaper() {
    local monitor="$1"
    local idx="$2"
    local wp="${WALLPAPERS[$idx]}"
    hyprctl hyprpaper wallpaper "$monitor,$wp" > /dev/null 2>&1
    echo "$idx" > "$STATE_DIR/$monitor"
}

# ── Rileva monitor sotto il cursore ───────────

get_monitor_at_cursor() {
    local pos cx cy
    pos=$(hyprctl cursorpos -j)
    cx=$(echo "$pos" | jq '.x')
    cy=$(echo "$pos" | jq '.y')

    hyprctl monitors -j | jq -r \
        --argjson cx "$cx" --argjson cy "$cy" \
        '.[] | select(
            .x <= $cx and $cx < (.x + .width) and
            .y <= $cy and $cy < (.y + .height)
        ) | .name' | head -1
}

# ── Rotazione ─────────────────────────────────

rotate() {
    local sync
    sync=$(cat "$SYNC_FILE")

    if [[ "$sync" == "synced" ]]; then
        # Ruota tutti i monitor insieme
        local idx next
        idx=$(get_index "$PRIMARY")
        next=$(next_index "$idx")
        for mon in "${MONITORS[@]}"; do
            set_wallpaper "$mon" "$next"
        done
        local wp_name
        wp_name=$(basename "${WALLPAPERS[$next]}")
        notify-send -t 2000 -i image-x-generic \
            "Wallpaper" "$wp_name"
    else
        # Ruota solo il monitor con il cursore
        local mon
        mon=$(get_monitor_at_cursor)
        [[ -z "$mon" ]] && mon="$PRIMARY"

        local idx next
        idx=$(get_index "$mon")
        next=$(next_index "$idx")
        set_wallpaper "$mon" "$next"

        local wp_name
        wp_name=$(basename "${WALLPAPERS[$next]}")
        notify-send -t 2000 -i image-x-generic \
            "Wallpaper [$mon]" "$wp_name"
    fi
}

# ── Toggle sync ───────────────────────────────

toggle_sync() {
    local sync
    sync=$(cat "$SYNC_FILE")

    if [[ "$sync" == "synced" ]]; then
        echo "unsynced" > "$SYNC_FILE"
        notify-send -t 3000 -i preferences-desktop-wallpaper \
            "Wallpaper Sync" "OFF — ogni monitor è indipendente"
    else
        echo "synced" > "$SYNC_FILE"
        # Sincronizza tutti al wallpaper del monitor primario
        local idx
        idx=$(get_index "$PRIMARY")
        for mon in "${MONITORS[@]}"; do
            set_wallpaper "$mon" "$idx"
        done
        notify-send -t 3000 -i preferences-desktop-wallpaper \
            "Wallpaper Sync" "ON — monitor sincronizzati"
    fi
}

# ── Main ──────────────────────────────────────

init

case "$1" in
    rotate)      rotate ;;
    toggle-sync) toggle_sync ;;
    *)
        echo "Uso: $0 {rotate|toggle-sync}"
        echo "  rotate       — prossimo wallpaper (monitor attivo o tutti)"
        echo "  toggle-sync  — attiva/disattiva sincronizzazione monitor"
        exit 1
        ;;
esac
