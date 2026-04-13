#!/bin/bash
# backfill-titles.sh - Fetch titles for existing wallpapers from Wallhaven/Alphacoders
# Run once: ~/.config/quickshell/scripts/backfill-titles.sh

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
CACHE_DIR="$HOME/.cache/wallpaper-picker"
METADATA_FILE="$CACHE_DIR/metadata.json"

[ -f "$METADATA_FILE" ] || echo '{}' > "$METADATA_FILE"

fetch_wallhaven_title() {
    local id="$1"
    local wait=1
    while true; do
        local resp
        resp=$(curl -s --max-time 10 "https://wallhaven.cc/api/v1/w/$id" 2>/dev/null)
        if [ -n "$resp" ]; then
            local title
            title=$(echo "$resp" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin).get('data', {})
    tags = [t['name'] for t in d.get('tags', [])[:3]]
    print(' / '.join(tags) if tags else '')
except: pass
" 2>/dev/null)
            if [ -n "$title" ]; then
                echo "$title"
                return
            fi
        fi
        sleep "$wait"
        wait=$((wait < 8 ? wait * 2 : 8))
    done
}

fetch_alphacoders_title() {
    local id="$1"
    local wait=1
    while true; do
        local title
        title=$(curl -s --max-time 10 "https://wall.alphacoders.com/big.php?i=$id" \
            -H "User-Agent: Mozilla/5.0" 2>/dev/null | \
            grep -oP 'itemprop="name"\s+content="\K[^"]+' | head -1)
        title="${title%% |*Wallpaper Abyss}"
        if [ -n "$title" ]; then
            echo "$title"
            return
        fi
        sleep "$wait"
        wait=$((wait < 8 ? wait * 2 : 8))
    done
}

count=0
total=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)

for filepath in "$WALLPAPER_DIR"/*; do
    [ -f "$filepath" ] || continue
    fname=$(basename "$filepath")
    key="${fname%.*}"
    count=$((count + 1))

    # Skip if already in metadata
    existing=$(jq -r --arg k "$key" '.[$k] // ""' "$METADATA_FILE" 2>/dev/null)
    if [ -n "$existing" ]; then
        echo "[$count/$total] SKIP $key (already has: $existing)"
        continue
    fi

    title=""

    # Wallhaven: wallhaven-XXXXXX or Wallhaven-XXXXXX_1920x1080
    if [[ "$key" =~ ^wallhaven- ]]; then
        id="${key#wallhaven-}"
        id="${id%%_*}"
        echo -n "[$count/$total] WALLHAVEN $id ... "
        title=$(fetch_wallhaven_title "$id")
        sleep 1                                         # rate limit

    # Alphacoders: pure numeric ID
    elif [[ "$key" =~ ^[0-9]+$ ]]; then
    echo -n "[$count/$total] ALPHACODERS $key ... "
    title=$(fetch_alphacoders_title "$key")
    sleep 1                                             # rate limit

    else
        # Clean up filename as best-effort title
        clean="$key"
        clean="${clean#wallhaven-}"
        clean=$(echo "$clean" | sed -E 's/[_-]([0-9]{3,5}x[0-9]{3,5})$//')
        clean=$(echo "$clean" | tr '_-' '  ')
        echo "[$count/$total] CLEANED $key -> $clean"
        title="$clean"
    fi

    if [ -n "$title" ]; then
        echo "$title"
        # Save to metadata
        jq --arg k "$key" --arg v "$title" '. + {($k): $v}' \
            "$METADATA_FILE" > "$METADATA_FILE.tmp" && \
            mv "$METADATA_FILE.tmp" "$METADATA_FILE"
    else
        echo "(no title found)"
    fi
done

echo "Done. Regenrate catalog with: wallpaper-picker.sh generate"