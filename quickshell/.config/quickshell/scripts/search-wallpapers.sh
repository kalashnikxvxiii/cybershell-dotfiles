#!/bin/bash
# search-wallpapers.sh — Download wallpaper thumbnails from search results
# Usage: search-wallpapers.sh "<query>"    (Wallhaven)
#        search-wallpapers.sh "@g <query>" (Google Images)

QUERY="$1"
PAGE="${2:-1}"
[ -z "$QUERY" ] && { echo "Usage: search-wallpapers.sh <query> [page]" >&2; exit 1; }

CACHE_DIR="$HOME/.cache/wallpaper-picker"
SEARCH_THUMBS="$CACHE_DIR/search_thumbs"
MAP_FILE="$CACHE_DIR/search_map.txt"
CONTROL="/tmp/wallpaper_search_control"
SCRIPTS_DIR="$(dirname "$0")"

mkdir -p "$SEARCH_THUMBS"
rm -f "$CONTROL"

# Clear previous search results
if [ "$PAGE" = "1" ]; then
    rm -f "$SEARCH_THUMBS"/*
    > "$MAP_FILE"
fi

python3 "$SCRIPTS_DIR/search-wallpapers.py" "$QUERY" "$PAGE" | while IFS= read -r line; do
    # Check control file
    if [ -f "$CONTROL" ]; then
        ctrl=$(cat "$CONTROL" 2>/dev/null)
        [ "$ctrl" = "stop" ] && break
        while [ "$ctrl" = "pause" ]; do
            sleep 0.5
            ctrl=$(cat "$CONTROL" 2>/dev/null)
            [ "$ctrl" = "stop" ] && break 2
        done
    fi

    url=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin)['url'])")
    thumb_url=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('thumb',''))")
    [ -z "$url" ] && continue

    fname=$(echo "$url" | md5sum | cut -c1-16)
    thumb="$SEARCH_THUMBS/${fname}.jpg"

    # Try thumbnail URL first (Wallhaven provides them), fallback to full image
    dl_url="${thumb_url:-$url}"

    if curl -sL --max-time 10 -o "$thumb.tmp" "$dl_url" 2>/dev/null; then
        mime=$(file -b --mime-type "$thumb.tmp" 2>/dev/null)
        case "$mime" in
            image/jpeg|image/png|image/webp|image/gif)
                magick "$thumb.tmp" -quality 85 "$thumb" 2>/dev/null
                rm -f "$thumb.tmp"
                echo "${fname}|${url}" >> "$MAP_FILE"
                echo "THUMB:${fname}|${thumb}|${url}"
                ;;
            *)
                rm -f "$thumb.tmp" ;;
        esac
    fi
done

echo "DONE"
