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

cmd_prepare_composite() {
    local screen="$1" img="$2"
    [ -n "$img" ] && [ -f "$img" ] || return
    # Triggera il composite in background. Non scrive marker → niente auto-apply
    make_blur_composite "$screen" "$img" >/dev/null 2>&1
}

_compose_gif_bg() {
    local screen="$1" input="$2" out="$3" small="$4" res="$5"

    ls -t /tmp/qs-wp-${screen}-*.jpg /tmp/qs-wp-${screen}-*.gif 2>/dev/null | tail -n +6 | xargs -r rm -f

    local bg
    bg=$(mktemp /tmp/qs-wp-bg-XXXXXX.png)

    # Backdrop blurrato (single image, ~100ms)
    magick "${input}[0]" \
        -thumbnail "${small}^" -gravity center -extent "$small" \
        -blur 0x12 -modulate 85,75,100 \
        -resize "${res}!" \
        "$bg" 2>/dev/null

    local screen_w=${res%x*}
    local screen_h=${res#*x}

    # ffmpeg overlay: scale GIF a fit + composite su backdrop, tutto in una passata
    local tmp="${out}.tmp"
    local filter="[1:v]scale=w='min(${screen_w}\\,iw*${screen_h}/ih)':h='min(${screen_h}\\,ih*${screen_w}/iw)':flags=lanczos[fg];[0:v][fg]overlay=(W-w)/2:(H-h)/2"

    if ffmpeg -y -loglevel error \
        -i "$bg" -i "$input" \
        -filter_complex "$filter" \
        -loop 0 -f gif \
        "$tmp" 2>/dev/null \
        && [ -s "$tmp" ]; then
        mv "$tmp" "$out"
        local marker="/tmp/qs-wp-pending-${screen}"
        if [ "$(cat "$marker" 2>/dev/null)" = "$out" ]; then
            awww img "$out" --outputs "$screen" \
                --transition-type none \
                --resize fit --fill-color 00060eff
        fi
    fi

    rm -f "$bg" "$tmp"
}

make_blur_composite() {
    local screen="$1"
    local img="$2"

    local res
    res=$(hyprctl monitors -j 2>/dev/null \
        | jq -r --arg s "$screen" '.[] | select(.name==$s) | "\(.width)x\(.height)"')
    [ -z "$res" ] && { echo "$img"; return; }

    local mime
    mime=$(file -b --mime-type "$img" 2>/dev/null)

    local key
    key=$(printf '%s|%s' "$img" "$res" | sha1sum | awk '{print $1}')

    local screen_w=${res%x*}
    local screen_h=${res#*x}
    local small_w=480
    local small_h=$((screen_h * small_w / screen_w))
    local small="${small_w}x${small_h}"

    # GIF animati: composite animato (backdrop statico blurrato + GIF fit foreground)
    if [ "$mime" = "image/gif" ]; then
        local out="/tmp/qs-wp-${screen}-${key}.gif"
        [ -f "$out" ] && { echo "$out"; return; }

        local input="$img"
        if [[ "$img" != *.gif && "$img" != *.GIF ]]; then
            local with_ext="${img}.gif"
            cp -f "$img" "$with_ext" 2>/dev/null && input="$with_ext"
        fi

        # Background composite via subshell con I/O completamente staccati
        ( _compose_gif_bg "$screen" "$input" "$out" "$small" "$res" ) </dev/null >/dev/null 2>&1 &
        disown 2>/dev/null

        echo "$input"
        return
    fi

    # Static image: logica esistente
    local out="/tmp/qs-wp-${screen}-${key}.jpg"
    [ -f "$out" ] && { echo "$out"; return; }

    ls -t /tmp/qs-wp-${screen}-*.jpg /tmp/qs-wp-${screen}-*.gif 2>/dev/null | tail -n +6 | xargs -r rm -f

    if magick "$img" \
        \( -clone 0 -thumbnail "${small}^" -gravity center -extent "$small" \
           -blur 0x12 -modulate 85,75,100 \
           -resize "${res}!" \) \
        \( -clone 0 -resize "${res}" \) \
        -delete 0 \
        -gravity center -compose over -composite \
        -quality 88 "$out" 2>/dev/null; then
        echo "$out"
    else
        echo "$img"
    fi
}

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
    
    local img=""
    if [ -d "$entry" ]; then
        [ -f "$entry/preview.jpg" ] && img="$entry/preview.jpg"
        [ -z "$img" ] && img=$(find "$entry" -name "preview.*" -type f 2>/dev/null | head -1)
    else
        img="$entry"
    fi

    [ -n "$img" ] || return

    # Marker: cache path attesa per questa preview
    local res
    res=$(hyprctl monitors -j 2>/dev/null \
        | jq -r --arg s "$screen" '.[] | select(.name==$s) | "\(.width)x\(.height)"')
    if [ -n "$res" ]; then
        local key mime ext
        key=$(printf '%s|%s' "$img" "$res" | sha1sum | awk '{print $1}')
        mime=$(file -b --mime-type "$img" 2>/dev/null)
        ext="jpg"
        [ "$mime" = "image/gif" ] && ext="gif"
        echo "/tmp/qs-wp-${screen}-${key}.${ext}" > "/tmp/qs-wp-pending-${screen}"
    fi

    local final
    final=$(make_blur_composite "$screen" "$img")

    local final_mime
    final_mime=$(file -b --mime-type "$final" 2>/dev/null)
    if [ "$final_mime" = "image/gif" ]; then
        awww img "$final" --outputs "$screen" \
            --transition-type none \
            --resize fit --fill-color 00060eff
    else
        awww img "$final" --outputs "$screen" --transition-type none
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
    prepare-composite) cmd_prepare_composite "$2" "$3" ;;
    *)                  echo "Usage: wallpaper-picker.sh {generate|toggle|preview}" >&2 ;;
esac