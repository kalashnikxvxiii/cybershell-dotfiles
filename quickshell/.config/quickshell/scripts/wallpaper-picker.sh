#!/bin/bash
# wallpaper-picker.sh - Catalog generation + toggle + preview for wallpaper picker

WPE_DIR="$HOME/.config/steamcmd-isolated/.steam/SteamApps/workshop/content/431960"
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
CACHE_DIR="$HOME/.cache/wallpaper-picker"
METADATA_FILE="$CACHE_DIR/metadata.json"
CATALOG_FILE="$CACHE_DIR/catalog.jsonl"
TOGGLE_FILE="/tmp/qs-wallpicker-toggle"
THUMB_DIR="$CACHE_DIR/thumbs"
COLOR_DIR="$CACHE_DIR/colors"

[ -f "$METADATA_FILE" ] || echo '{}' > "$METADATA_FILE"

mkdir -p "$THUMB_DIR" "$COLOR_DIR"

# ── Helpers ───────────────────────────────────────────────────

get_thumb_key() {
    local entry="$1"
    if [ -d "$entry" ]; then
        basename "$entry"
    else
        local base; base=$(basename "$entry")
        echo "${base%.*}"
    fi
}

get_type_static() {
    case "${1##*.}" in
        gif|GIF) echo "gif" ;;
        *)       echo "image" ;;
    esac
}

get_title() {
    local key="$1"
    # Check metadata file first
    local meta_title
    meta_title=$(jq -r --arg k "$key" '.[$k] // ""' "$METADATA_FILE" 2>/dev/null)
    if [ -n "$meta_title" ]; then
        echo "$meta_title"
        return
    fi
    # Clean up filename: remove wallhaven- prefix, resolution suffix, replace -_ with spaces
    local clean="$key"
    clean="${clean#wallhaven-}"
    clean=$(echo "$clean" | sed -E 's/[_-]([0-9]{3,5}x[0-9]{3,5})$//')
    clean=$(echo "$clean" | tr '_-' '  ')
    echo "$clean"
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g'
}

# ── Thumbnail Generation ─────────────────────────────────────────────

generate_thumb() {
    local entry="$1" key="$2"
    local thumb="$THUMB_DIR/${key}.jpg"

    # Skip if thumbnail is newer than source
    if [ -f "$thumb" ] && [ "$thumb" -nt "$entry" ] 2>/dev/null; then
        echo "$thumb"; return
    fi

    if [ -d "$entry" ]; then
        # WPE entry
        local wpe_type
        wpe_type=$(jq -r '.type // "scene"' "$entry/project.json" 2>/dev/null)
        case "$wpe_type" in
            video)
                local file
                file=$(jq -r '.file // ""' "$entry/project.json" 2>/dev/null)
                if [ -n "$file" ] && [ -f "$entry/$file" ]; then
                    ffmpeg -y -ss 5 -i "$entry/$file" -vframes 1 -q:v 2 \
                        -vf "scale=-1:420" "$thumb" 2>/dev/null
                elif [ -f "$entry/preview.jpg" ]; then
                    magick "$entry/preview.jpg[0]" -resize x600 -quality 95 "$thumb" 2>/dev/null || \
                    ffmpeg -y -i "$entry/preview.jpg" -vframes 1 -q:v 2 -vf "scale=-1:420" "$thumb" 2>/dev/null
                fi ;;
            *)
                local preview=""
                [ -f "$entry/preview.jpg" ] && preview="$entry/preview.jpg"
                [ -z "$preview" ] && preview=$(find "$entry" -name "preview.*" -type f 2>/dev/null | head -1)
                if [ -n "$preview" ]; then
                    magick "${preview}[0]" -resize x600 -quality 95 "$thumb" 2>/dev/null || \
                    ffmpeg -y -i "$preview" -vframes 1 -q:v 2 -vf "scale=-1:420" "$thumb" 2>/dev/null
                fi ;;
        esac
    else
        # Static file
        case "${entry##*.}" in
            gif|GIF) magick "${entry}[0]" -resize x600 -quality 95 "$thumb" 2>/dev/null ;;
            *)       magick "$entry" -resize x600 -quality 95 "$thumb" 2>/dev/null ;;
        esac
    fi

    [ -f "$thumb" ] && echo "$thumb" || echo ""
}

# ── Color Extraction ─────────────────────────────────────────────────

extract_color() {
    local key="$1" thumb="$2"

    # Check existing marker
    local existing
    existing=$(find "$COLOR_DIR" -maxdepth 1 -name "${key}_HEX_*" -print -quit 2>/dev/null)
    if [ -n "$existing" ]; then
        echo "#${existing##*_HEX_}"; return
    fi

    # Extract dominant color (saturation-boosted single pixel)
    if [ -f "$thumb" ]; then
        local hex
        hex=$(magick "$thumb" -modulate 100,200 -resize 1x1^ \
            -depth 8 -format "%[hex:p{0,0}]" info:- 2>/dev/null)
        if [ -n "$hex" ]; then
            hex="${hex:0:6}"
            touch "$COLOR_DIR/${key}_HEX_${hex}"
            echo "#${hex}"; return
        fi
    fi
    echo "#888888"
}

# ── Commands ───────────────────────────────────────────────────────

_generate_impl() {
    # Clean orphaned thumbnails
    for thumb_file in "$THUMB_DIR"/*.jpg; do
        [ -f "$thumb_file" ] || continue
        local key; key=$(basename "$thumb_file" .jpg)
        local found=false
        for ext in jpg jpeg png gif webp JPG JPEG PNG GIF WEBP; do
            [ -f "$WALLPAPER_DIR/${key}.${ext}" ] && { found=true; break; }
        done
        [ -d "$WPE_DIR/$key" ] && found=true
        $found || rm -f "$thumb_file" "$COLOR_DIR/${key}_HEX_"*
    done

    # Static wallpapers
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
            -o -iname "*.gif" -o -iname "*.webp" \) | sort | \
    while IFS= read -r entry; do
        local key; key=$(get_thumb_key "$entry")
        local thumb; thumb=$(generate_thumb "$entry" "$key")
        [ -z "$thumb" ] && continue
        local color; color=$(extract_color "$key" "$thumb")
        local raw_title; raw_title=$(get_title "$key")
        local title; title=$(json_escape "$raw_title")
        local etype; etype=$(get_type_static "$entry")
        local videoFile=""
        [ "$etype" = "gif" ] && videoFile="$entry"
        printf '{"path":"%s","thumb":"%s","title":"%s","source":"awww","type":"%s","color":"%s","videoFile":"%s"}\n' \
            "$entry" "$thumb" "$title" "$etype" "$color" "$videoFile"
    done

    # WPE wallpapers
    [ -d "$WPE_DIR" ] && find "$WPE_DIR" -mindepth 1 -maxdepth 1 -type d | sort | \
    while IFS= read -r entry; do
        [ -f "$entry/project.json" ] || continue
        local key; key=$(get_thumb_key "$entry")
        local thumb; thumb=$(generate_thumb "$entry" "$key")
        [ -z "$thumb" ] && continue
        local color; color=$(extract_color "$key" "$thumb")
        local raw_title
        raw_title=$(jq -r '.title // ""' "$entry/project.json" 2>/dev/null)
        [ -z "$raw_title" ] && raw_title="$key"
        local title; title=$(json_escape "$raw_title")
        local etype
        etype=$(jq -r '.type // "scene"' "$entry/project.json" 2>/dev/null | tr '[:upper:]' '[:lower:]')
        local videoFile=""
        if [ "$etype" = "video" ]; then
            videoFile=$(jq -r '.file // ""' "$entry/project.json" 2>/dev/null)
            [ -n "$videoFile" ] && videoFile="$entry/$videoFile"
        fi
        printf '{"path":"%s","thumb":"%s","title":"%s","source":"wpe","type":"%s","color":"%s","videoFile":"%s"}\n' \
            "$entry" "$thumb" "$title" "$etype" "$color" "$videoFile"
    done
}

cmd_toggle() {
    local screen
    screen=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    [ -z "$screen" ] && screen="DP-1"
    echo "${screen}_$(date +%s%N)" > "$TOGGLE_FILE"
}

cmd_preview() {
    local screen="$1" entry="$2"
    # Kill WPE on this screen so awww preview is visible
    local pid_file="$HOME/.cache/wallpaper-themer/pid_${screen}"
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
        rm -f "$pid_file"
    fi
    pkill -f "linux-wallpaperengine.*--screen-root $screen" 2>/dev/null

    if [ -d "$entry" ]; then
        local preview=""
        [ -f "$entry/preview.jpg" ] && preview="$entry/preview.jpg"
        [ -z "$preview" ] && preview=$(find "$entry" -name "preview.*" -type f 2>/dev/null | head -1)
        [ -n "$preview" ] && awww img "$preview" --outputs "$screen" --transition-type none
    else
        awww img "$entry" --outputs "$screen" --transition-type none
    fi
}

cmd_generate() {
    _generate_impl > "$CATALOG_FILE.tmp"
    mv "$CATALOG_FILE.tmp" "$CATALOG_FILE"
    cat "$CATALOG_FILE"
}

cmd_catalog() {
    if [ -f "$CATALOG_FILE" ]; then
        cat "$CATALOG_FILE"
    else
        cmd_generate
    fi
}

cmd_preview_wpe() {
    local screen="$1" entry="$2"
    [ -d "$entry" ] && [ -f "$entry/project.json" ] || return

    local wpe_id
    wpe_id=$(basename "$entry")

    # Set preview of the new WPE immediately to avoid flash of old wallpaper
    local preview=""
    [ -f "$entry/preview.jpg" ] && preview="$entry/preview.jpg"
    [ -z "$preview" ] && preview=$(find "$entry" -name "preview.*" -type f 2>/dev/null | head -1)
    [ -n "$preview" ] && awww img "$preview" --outputs "$screen" --transition-type none

    # Kill existing WPE on this screen
    local pid_file="$HOME/.cache/wallpaper-themer/pid_${screen}"
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
    fi
    pkill -f "linux-wallpaperengine.*--screen-root $screen" 2>/dev/null
    sleep 0.3

    linux-wallpaperengine \
        --screen-root "$screen" \
        --bg "$wpe_id" \
        --volume 0 \
        --noautomute \
        --no-fullscreen-pause \
        --mpvparam=hwdec=auto &
    local new_pid=$!

    # Save as preview pid, NOT as wallpaper-themer state
    echo "$new_pid" > "/tmp/qs-wpe-preview-pid-${screen}"
}

cmd_stop_preview_wpe() {
    local screen="$1"
    local pid_file="/tmp/qs-wpe-preview-pid-${screen}"
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
        rm -f "$pid_file"
    fi
    pkill -f "linux-wallpaperengine.*--screen-root $screen" 2>/dev/null
}

case "${1:-}" in
    generate)           cmd_generate ;;
    toggle)             cmd_toggle ;;
    preview)            cmd_preview "$2" "$3" ;;
    catalog)            cmd_catalog ;;
    preview-wpe)        cmd_preview_wpe "$2" "$3" ;;
    stop-preview-wpe)   cmd_stop_preview_wpe "$2" ;;
    *)                  echo "Usage: wallpaper-picker.sh {generate|toggle|preview}" >&2 ;;
esac