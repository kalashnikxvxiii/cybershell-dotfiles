#!/bin/bash

STEAM_BASE="/home/kalashnikxv/.var/app/com.valvesoftware.Steam"
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
WPE_DIR="$STEAM_BASE/.local/share/Steam/steamapps/workshop/content/431960"
WALLUST="$HOME/.cargo/bin/wallust"
STATE_DIR="$HOME/.cache/wallpaper-themer"
AUTO_INTERVAL=300
DAEMON_PID_FILE="$STATE_DIR/daemon.pid"
AUDIO_VOLUME_FILE="$STATE_DIR/audio_volume"
AUDIO_LAST_VOL_FILE="$STATE_DIR/audio_last_volume"
FULLSCREEN_WHITELIST=("discord" "kitty" "foot" "alacritty")

mkdir -p "$STATE_DIR"

# ---------------------------------------------------------------------------
# Pool management
# ---------------------------------------------------------------------------

get_pool() {
    cat "$STATE_DIR/pool" 2>/dev/null || echo "static"
}

toggle_pool() {
    local current
    current=$(get_pool)
    case "$current" in
        static) echo "wpe" > "$STATE_DIR/pool";   notify-send "Wallpaper" "Pool: Wallpaper Engine" ;;
        wpe)    echo "mixed" > "$STATE_DIR/pool";  notify-send "Wallpaper" "Pool: misto — statici + WPE" ;;
        mixed)  echo "static" > "$STATE_DIR/pool"; notify-send "Wallpaper" "Pool: statici" ;;
    esac
}

# ---------------------------------------------------------------------------
# Wallpaper sources
# ---------------------------------------------------------------------------

get_static_wallpapers() {
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
           -o -iname "*.gif" -o -iname "*.webp" \)
}

get_wpe_wallpapers() {
    find "$WPE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
}

get_wallpapers() {
    local pool
    pool=$(get_pool)
    case "$pool" in
        static) get_static_wallpapers ;;
        wpe)    get_wpe_wallpapers ;;
        mixed)  get_static_wallpapers; get_wpe_wallpapers ;;
    esac
}

is_wpe() {
    local entry="$1"
    [ -d "$entry" ] && [ -f "$entry/project.json" ]
}

get_wpe_id() {
    basename "$1"
}

get_wp_title() {
    local entry="$1"
    if is_wpe "$entry"; then
        jq -r '.title // ""' "$entry/project.json" 2>/dev/null
    else
        basename "$entry"
    fi
}

get_wpe_type() {
    local entry="$1"
    jq -r '.type // "scene"' "$entry/project.json" 2>/dev/null || echo "scene"
}

get_wpe_preview() {
    local entry="$1"
    if [ -f "$entry/preview.jpg" ]; then
        echo "$entry/preview.jpg"
    else
        find "$entry" -name "preview.*" -type f 2>/dev/null | head -1
    fi
}

# ---------------------------------------------------------------------------
# WPE process management
# ---------------------------------------------------------------------------

kill_wpe_on_screen() {
    local screen="$1"
    local pid_file="$STATE_DIR/pid_${screen}"
    # Kill il PID tracciato
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
        rm -f "$pid_file"
    fi
    # Kill tutti i WPE orfani sullo stesso screen
    if pkill -f "linux-wallpaperengine.*--screen-root $screen" 2>/dev/null; then
        sleep 0.3
    fi
}

start_wpe_on_screen() {
    local screen="$1"
    local entry="$2"
    local wpe_id
    wpe_id=$(get_wpe_id "$entry")

    kill_wpe_on_screen "$screen"

    local wpe_args=(
        --screen-root "$screen"
        --bg "$wpe_id"
        --volume 100
        --noautomute
        --mpvparam=hwdec=auto
        --mpvparam=demuxer-max-bytes=150MiB
        --mpvparam=demuxer-max-back-bytes=50MiB
    )
    local app
    for app in "${FULLSCREEN_WHITELIST[@]}"; do
        wpe_args+=(--fullscreen-pause-ignore-appid "$app")
    done

    linux-wallpaperengine "${wpe_args[@]}" &
    local new_pid=$!
    echo "$new_pid" > "$STATE_DIR/pid_${screen}"
}

start_wpe_direct() {
    local screen="$1"
    local entry="$2"
    local wpe_id
    wpe_id=$(get_wpe_id "$entry")

    local wpe_args=(
        --screen-root "$screen"
        --bg "$wpe_id"
        --volume 100
        --noautomute
        --mpvparam=hwdec=auto
        --mpvparam=demuxer-max-bytes=150MiB
        --mpvparam=demuxer-max-back-bytes=50MiB
    )
    local app
    for app in "${FULLSCREEN_WHITELIST[@]}"; do
        wpe_args+=(--fullscreen-pause-ignore-appid "$app")
    done

    linux-wallpaperengine "${wpe_args[@]}" &
    local new_pid=$!
    echo "$new_pid" > "$STATE_DIR/pid_${screen}"
    if kill -0 "$new_pid" 2>/dev/null; then
        apply_audio_for_screen_async "$screen" "$entry" "$new_pid" "$(get_audio_volume)"
    fi
}

is_wpe_running_on_screen() {
    local screen="$1"
    local pid_file="$STATE_DIR/pid_${screen}"
    [ -f "$pid_file" ] || return 1
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

# ---------------------------------------------------------------------------
# PipeWire audio control
# ---------------------------------------------------------------------------

get_audio_volume() {
    cat "$AUDIO_VOLUME_FILE" 2>/dev/null || echo "0"
}

get_pw_clients_for_pid() {
    local target_pid="$1"
    pw-cli ls Client 2>/dev/null | awk -v pid="$target_pid" '
        /object.serial/ { serial = $NF; gsub(/"/, "", serial) }
        /pipewire.sec.pid/ {
            p = $NF; gsub(/"/, "", p)
            if (p == pid) print serial
        }
    '
}

get_inputs_for_clients() {
    local clients_str="$1"
    [ -z "$clients_str" ] && return
    pactl list sink-inputs 2>/dev/null | awk -v clients="$clients_str" '
        BEGIN { n = split(clients, ca); for (i=1; i<=n; i++) cset[ca[i]] = 1 }
        /^Sink Input #/ {
            if (cur_id != "" && cur_client in cset) print cur_id
            cur_id = substr($3, 2); cur_client = ""
        }
        /Client:/ { if ($1 == "Client:") cur_client = $2 }
        END { if (cur_id != "" && cur_client in cset) print cur_id }
    '
}

get_inputs_for_pid() {
    local pid="$1"
    local clients
    clients=$(get_pw_clients_for_pid "$pid" | tr '\n' ' ')
    [ -n "$clients" ] && get_inputs_for_clients "$clients"
}

get_wpe_inputs_for_screen() {
    local screen="$1"
    local pid_file="$STATE_DIR/pid_${screen}"
    [ -f "$pid_file" ] || return
    local wpe_pid
    wpe_pid=$(cat "$pid_file" 2>/dev/null) || return

    local all_inputs=""
    all_inputs+=$(get_inputs_for_pid "$wpe_pid")$'\n'

    # Video wallpapers: mpv child process
    local entry
    entry=$(get_current_wp "$screen")
    if is_wpe "$entry" && [ "$(get_wpe_type "$entry")" = "video" ]; then
        local mpv_pid
        while IFS= read -r mpv_pid; do
            all_inputs+=$(get_inputs_for_pid "$mpv_pid")$'\n'
        done < <(pgrep -f "$WPE_DIR/$(get_wpe_id "$entry")" 2>/dev/null)
    fi

    echo "$all_inputs" | grep -v '^$' | sort -u
}

apply_audio_for_screen_async() {
    local screen="$1"
    local entry="$2"
    local wpe_pid="$3"
    local vol="$4"
    local wpe_type
    wpe_type=$(get_wpe_type "$entry")
    local wpe_id
    wpe_id=$(get_wpe_id "$entry")

    (
        local attempt all_clients clients mpv_pid inputs
        for attempt in $(seq 1 50); do
            all_clients=""
            clients=$(get_pw_clients_for_pid "$wpe_pid" | tr '\n' ' ')
            [ -n "$clients" ] && all_clients+="$clients "

            if [ "$wpe_type" = "video" ]; then
                while IFS= read -r mpv_pid; do
                    clients=$(get_pw_clients_for_pid "$mpv_pid" | tr '\n' ' ')
                    [ -n "$clients" ] && all_clients+="$clients "
                done < <(pgrep -f "$WPE_DIR/$wpe_id" 2>/dev/null)
            fi

            if [ -n "$all_clients" ]; then
                inputs=$(get_inputs_for_clients "$all_clients")
                if [ -n "$(echo "$inputs" | tr -d '[:space:]')" ]; then
                    while IFS= read -r sid; do
                        [ -n "$sid" ] && pactl set-sink-input-volume "$sid" "${vol}%"
                    done <<< "$inputs"
                    return
                fi
            fi
            sleep 0.1
        done
    ) &
}

pick_random_wp() {
    local exclude="${1:-}"
    local wps=()
    mapfile -t wps < <(get_wallpapers)
    local count=${#wps[@]}
    [ "$count" -eq 0 ] && return 1
    local wp attempts=0
    while true; do
        wp="${wps[$((RANDOM % count))]}"
        [ -n "$wp" ] && { [ -z "$exclude" ] || [ "$wp" != "$exclude" ]; } && break
        attempts=$((attempts + 1))
        [ $attempts -gt 20 ] && break
    done
    echo "$wp"
}

get_order() {
    cat "$STATE_DIR/order" 2>/dev/null || echo "random"
}

toggle_order() {
    if [ "$(get_order)" = "random" ]; then
        echo "alpha" > "$STATE_DIR/order"
        notify-send "Wallpaper" "Ordine: alfabetico"
    else
        echo "random" > "$STATE_DIR/order"
        notify-send "Wallpaper" "Ordine: casuale"
    fi
}

_sorted_wps() {
    local entry
    while IFS= read -r entry; do
        local title
        title=$(get_wp_title "$entry")
        [ -z "$title" ] && title="$entry"
        printf '%s\t%s\n' "$title" "$entry"
    done < <(get_wallpapers) | sort -f | cut -f2
}

pick_next_wp() {
    local exclude="${1:-}"
    if [ "$(get_order)" = "random" ]; then
        pick_random_wp "$exclude"
        return
    fi
    local sorted=()
    mapfile -t sorted < <(_sorted_wps)
    local count=${#sorted[@]}
    [ "$count" -eq 0 ] && return 1
    local pos=0
    if [ -n "$exclude" ]; then
        for i in "${!sorted[@]}"; do
            if [ "${sorted[$i]}" = "$exclude" ]; then
                pos=$(( (i + 1) % count ))
                break
            fi
        done
    fi
    echo "${sorted[$pos]}"
}

save_state() {
    echo "$2" > "$STATE_DIR/current_${1}"
    date +%s > "$STATE_DIR/start_time_${1}"
}

get_current_wp() {
    cat "$STATE_DIR/current_${1}" 2>/dev/null || echo ""
}

# ---------------------------------------------------------------------------
# awww helpers
# ---------------------------------------------------------------------------

wait_for_awww() {
    awww wait 2>/dev/null || true
}

awww_transition() {
    local screen="$1"
    local img="$2"
    awww img "$img" \
        --outputs "$screen" \
        --transition-type wipe \
        --transition-angle 30 \
        --transition-duration 1.5 \
        --transition-fps 60
}

# ---------------------------------------------------------------------------
# Color theming
# ---------------------------------------------------------------------------

apply_colors() {
    local dp1_wp
    dp1_wp=$(get_current_wp "DP-1")
    [ -z "$dp1_wp" ] && return

    local color_source
    if is_wpe "$dp1_wp"; then
        color_source=$(get_wpe_preview "$dp1_wp")
    else
        color_source="$dp1_wp"
    fi

    [ -n "$color_source" ] && [ -f "$color_source" ] && "$WALLUST" run "$color_source" &>/dev/null
}

# ---------------------------------------------------------------------------
# Wallpaper change
# ---------------------------------------------------------------------------

_wpe_health_check() {
    local screen="$1"
    local expected_entry="$2"
    sleep 3
    # Se l'utente ha cambiato wallpaper nel frattempo, abortisci
    local current
    current=$(get_current_wp "$screen")
    [ "$current" != "$expected_entry" ] && return
    # Se il processo è ancora vivo, tutto ok
    local pid
    pid=$(cat "$STATE_DIR/pid_${screen}" 2>/dev/null)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && return
    # WPE crashato — riprova con un altro wallpaper (max 3 tentativi)
    local exclude="$expected_entry"
    local attempt
    for attempt in 1 2 3; do
        local new_entry
        new_entry=$(pick_next_wp "$exclude")
        [ -z "$new_entry" ] && return
        if is_wpe "$new_entry"; then
            save_state "$screen" "$new_entry"
            start_wpe_on_screen "$screen" "$new_entry"
            sleep 3
            # Controlla di nuovo che nessuno abbia cambiato
            current=$(get_current_wp "$screen")
            [ "$current" != "$new_entry" ] && return
            pid=$(cat "$STATE_DIR/pid_${screen}" 2>/dev/null)
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                return
            fi
            exclude="$new_entry"
        else
            save_state "$screen" "$new_entry"
            kill_wpe_on_screen "$screen"
            awww_transition "$screen" "$new_entry"
            return
        fi
    done
}

start_screen() {
    local screen="$1"
    local entry="$2"

    local was_wpe=false
    local current_wp
    current_wp=$(get_current_wp "$screen")
    is_wpe "$current_wp" && was_wpe=true

    save_state "$screen" "$entry"

    if is_wpe "$entry"; then
        local preview
        preview=$(get_wpe_preview "$entry")
        if $was_wpe; then
            [ -n "$preview" ] && awww img "$preview" --outputs "$screen" --transition-type none &
        else
            [ -n "$preview" ] && awww_transition "$screen" "$preview"
        fi
        start_wpe_on_screen "$screen" "$entry"
        local wpe_pid
        wpe_pid=$(cat "$STATE_DIR/pid_${screen}" 2>/dev/null)
        if [ -n "$wpe_pid" ] && kill -0 "$wpe_pid" 2>/dev/null; then
            apply_audio_for_screen_async "$screen" "$entry" "$wpe_pid" "$(get_audio_volume)"
        fi

        # Health check: se WPE crasha entro 3s, riprova con un altro wallpaper
        _wpe_health_check "$screen" "$entry" &
    else
        kill_wpe_on_screen "$screen"
        awww_transition "$screen" "$entry"
    fi
}

LOCK_FILE="$STATE_DIR/change.lock"

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        # Stale lock (processo morto)
        if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
            return 1
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

change_both() {
    acquire_lock || return
    trap release_lock EXIT
    local dp1_wp hdmi_wp
    dp1_wp=$(pick_next_wp "$(get_current_wp "DP-1")")
    hdmi_wp=$(pick_next_wp "$dp1_wp")

    # Aggiorna awww con i preview prima di killare (evita preview stale)
    if is_wpe "$dp1_wp"; then
        local p; p=$(get_wpe_preview "$dp1_wp")
        [ -n "$p" ] && awww img "$p" --outputs "DP-1" --transition-type none &
    fi
    if is_wpe "$hdmi_wp"; then
        local p; p=$(get_wpe_preview "$hdmi_wp")
        [ -n "$p" ] && awww img "$p" --outputs "HDMI-A-1" --transition-type none &
    fi

    # Kill ALL WPE in un colpo, singolo wait (come vecchia implementazione)
    pkill -x linux-wallpaperengine 2>/dev/null
    rm -f "$STATE_DIR"/pid_*
    sleep 0.5

    # Avvia entrambi
    save_state "DP-1" "$dp1_wp"
    save_state "HDMI-A-1" "$hdmi_wp"
    if is_wpe "$dp1_wp"; then
        start_wpe_direct "DP-1" "$dp1_wp"
        _wpe_health_check "DP-1" "$dp1_wp" &
    else
        awww_transition "DP-1" "$dp1_wp"
    fi
    if is_wpe "$hdmi_wp"; then
        start_wpe_direct "HDMI-A-1" "$hdmi_wp"
        _wpe_health_check "HDMI-A-1" "$hdmi_wp" &
    else
        awww_transition "HDMI-A-1" "$hdmi_wp"
    fi

    apply_colors
    local title
    title=$(get_wp_title "$dp1_wp")
    notify-send -t 2000 -i image-x-generic "Wallpaper" "$title"
    release_lock
    trap - EXIT
}

get_mode() {
    cat "$STATE_DIR/mode" 2>/dev/null || echo "both"
}

toggle_mode() {
    if [ "$(get_mode)" = "both" ]; then
        echo "cursor" > "$STATE_DIR/mode"
        notify-send "Wallpaper" "Modalità: indipendente — Super+W cambia solo il monitor col cursore"
    else
        echo "both" > "$STATE_DIR/mode"
        notify-send "Wallpaper" "Modalità: entrambi i monitor"
    fi
}

get_cursor_screen() {
    local cursor cx cy
    cursor=$(hyprctl cursorpos)
    cx=$(echo "$cursor" | cut -d',' -f1 | tr -d ' ')
    cy=$(echo "$cursor" | cut -d',' -f2 | tr -d ' ')
    hyprctl monitors -j | jq -r \
        ".[] | select(.x <= ($cx | tonumber) and (.x + .width) > ($cx | tonumber) and .y <= ($cy | tonumber) and (.y + .height) > ($cy | tonumber)) | .name"
}

change_cursor() {
    acquire_lock || return
    trap release_lock EXIT
    local screen
    screen=$(get_cursor_screen)
    if [ -z "$screen" ]; then
        release_lock; trap - EXIT; return
    fi
    local wp
    wp=$(pick_next_wp "$(get_current_wp "$screen")")
    start_screen "$screen" "$wp"
    [ "$screen" = "DP-1" ] && apply_colors
    local title
    title=$(get_wp_title "$wp")
    notify-send -t 2000 -i image-x-generic "Wallpaper [$screen]" "$title"
    release_lock
    trap - EXIT
}

change_smart() {
    if [ "$(get_mode)" = "cursor" ]; then
        change_cursor
    else
        change_both
    fi
}

restore() {
    wait_for_awww
    local dp1_wp hdmi_wp
    dp1_wp=$(get_current_wp "DP-1")
    hdmi_wp=$(get_current_wp "HDMI-A-1")
    # Fallback: static wallpaper if saved state is invalid
    if [ -z "$dp1_wp" ] || { ! is_wpe "$dp1_wp" && [ ! -f "$dp1_wp" ]; }; then
        dp1_wp=$(pick_random_wp)
    fi
    if [ -z "$hdmi_wp" ] || { ! is_wpe "$hdmi_wp" && [ ! -f "$hdmi_wp" ]; }; then
        hdmi_wp=$(pick_random_wp)
    fi
    start_screen "DP-1" "$dp1_wp"
    start_screen "HDMI-A-1" "$hdmi_wp"
    apply_colors
}

set_wallpaper() {
    local screen="$1" entry="$2"
    [ -z "$screen" ] || [ -z "$entry" ] && { echo "Usage: wallpaper-themer.sh set <screen> <entry>" >&2; return 1; }
    acquire_lock || return
    trap release_lock EXIT
    start_screen "$screen" "$entry"
    [ "$screen" = "DP-1" ] && apply_colors &
    release_lock
    trap - EXIT
}

# ---------------------------------------------------------------------------
# Auto daemon
# ---------------------------------------------------------------------------

run_daemon() {
    while true; do
        sleep "$AUTO_INTERVAL"
        local remaining
        remaining=$(get_video_remaining "DP-1")
        if [ "$remaining" -gt 0 ]; then
            sleep "$remaining"
        fi
        change_both
    done
}

toggle_auto() {
    if [ -f "$DAEMON_PID_FILE" ]; then
        local pid
        pid=$(cat "$DAEMON_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$DAEMON_PID_FILE"
            notify-send "Wallpaper" "Auto-change disattivato"
            return
        fi
    fi
    bash "$0" daemon &
    echo $! > "$DAEMON_PID_FILE"
    notify-send "Wallpaper" "Auto-change attivato (${AUTO_INTERVAL}s)"
}

# ---------------------------------------------------------------------------
# Audio control
# ---------------------------------------------------------------------------

audio_toggle() {
    local screen
    screen=$(get_cursor_screen)
    [ -z "$screen" ] && return
    is_wpe_running_on_screen "$screen" || return
    local vol
    vol=$(get_audio_volume)
    if [ "$vol" -eq 0 ]; then
        local new_vol
        new_vol=$(cat "$AUDIO_LAST_VOL_FILE" 2>/dev/null || echo "30")
        echo "$new_vol" > "$AUDIO_VOLUME_FILE"
        while IFS= read -r sid; do
            [ -n "$sid" ] && pactl set-sink-input-volume "$sid" "${new_vol}%"
        done < <(get_wpe_inputs_for_screen "$screen")
        notify-send "Wallpaper Audio" "Volume: ${new_vol}% [$screen]"
    else
        echo "$vol" > "$AUDIO_LAST_VOL_FILE"
        echo "0" > "$AUDIO_VOLUME_FILE"
        while IFS= read -r sid; do
            [ -n "$sid" ] && pactl set-sink-input-volume "$sid" "0%"
        done < <(get_wpe_inputs_for_screen "$screen")
        notify-send "Wallpaper Audio" "Muto [$screen]"
    fi
}

audio_volume_up() {
    local screen
    screen=$(get_cursor_screen)
    [ -z "$screen" ] && return
    is_wpe_running_on_screen "$screen" || return
    local vol
    vol=$(get_audio_volume)
    [ "$vol" -eq 0 ] && vol=$(cat "$AUDIO_LAST_VOL_FILE" 2>/dev/null || echo "20")
    vol=$((vol + 10))
    [ "$vol" -gt 100 ] && vol=100
    echo "$vol" > "$AUDIO_VOLUME_FILE"
    echo "$vol" > "$AUDIO_LAST_VOL_FILE"
    while IFS= read -r sid; do
        [ -n "$sid" ] && pactl set-sink-input-volume "$sid" "${vol}%"
    done < <(get_wpe_inputs_for_screen "$screen")
    notify-send "Wallpaper Audio" "Volume: ${vol}% [$screen]"
}

audio_volume_down() {
    local screen
    screen=$(get_cursor_screen)
    [ -z "$screen" ] && return
    is_wpe_running_on_screen "$screen" || return
    local vol
    vol=$(get_audio_volume)
    vol=$((vol - 10))
    [ "$vol" -lt 0 ] && vol=0
    echo "$vol" > "$AUDIO_VOLUME_FILE"
    if [ "$vol" -gt 0 ]; then
        echo "$vol" > "$AUDIO_LAST_VOL_FILE"
        notify-send "Wallpaper Audio" "Volume: ${vol}% [$screen]"
    else
        notify-send "Wallpaper Audio" "Muto [$screen]"
    fi
    while IFS= read -r sid; do
        [ -n "$sid" ] && pactl set-sink-input-volume "$sid" "${vol}%"
    done < <(get_wpe_inputs_for_screen "$screen")
}

# ---------------------------------------------------------------------------
# Video duration tracking
# ---------------------------------------------------------------------------

get_video_duration() {
    local entry="$1"
    is_wpe "$entry" || { echo "0"; return; }
    [ "$(get_wpe_type "$entry")" = "video" ] || { echo "0"; return; }
    local file
    file=$(jq -r '.file // ""' "$entry/project.json" 2>/dev/null)
    local video_path="$entry/$file"
    if [ -n "$file" ] && [ -f "$video_path" ]; then
        ffprobe -v quiet -print_format json -show_format "$video_path" 2>/dev/null \
            | jq '.format.duration | tonumber | ceil' 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_video_remaining() {
    local screen="$1"
    local entry
    entry=$(get_current_wp "$screen")
    [ -z "$entry" ] && { echo "0"; return; }
    local duration
    duration=$(get_video_duration "$entry")
    if ! [[ "$duration" =~ ^[0-9]+$ ]] || [ "$duration" -le 0 ]; then
        echo "0"; return
    fi
    local start_time now elapsed remaining
    start_time=$(cat "$STATE_DIR/start_time_${screen}" 2>/dev/null || echo "0")
    now=$(date +%s)
    elapsed=$(( (now - start_time) % duration ))
    remaining=$((duration - elapsed))
    [ "$remaining" -le 3 ] && echo "0" || echo "$remaining"
}

# ---------------------------------------------------------------------------

case "${1:-restore}" in
    restore)      restore ;;
    smart)        change_smart ;;
    both)         change_both ;;
    cursor)       change_cursor ;;
    toggle-mode)  toggle_mode ;;
    toggle-order) toggle_order ;;
    toggle-auto)  toggle_auto ;;
    toggle-pool)  toggle_pool ;;
    daemon)       run_daemon ;;
    audio-toggle) audio_toggle ;;
    audio-up)     audio_volume_up ;;
    audio-down)   audio_volume_down ;;
    set)          set_wallpaper "$2" "$3" ;;
    *)            change_smart ;;
esac
