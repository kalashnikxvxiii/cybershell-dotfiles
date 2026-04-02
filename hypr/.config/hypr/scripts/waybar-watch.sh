#!/usr/bin/env bash
# waybar-watch.sh — ricarica waybar CSS in tempo reale al salvataggio
# Usage: waybar-watch.sh [css|config|all]

TARGET="${1:-css}"

case "$TARGET" in
    css)    FILES=("$HOME/.config/waybar/style.css") ;;
    config) FILES=("$HOME/.config/waybar/config") ;;
    all)    FILES=("$HOME/.config/waybar/style.css" "$HOME/.config/waybar/config") ;;
    *)      echo "Usage: $0 [css|config|all]"; exit 1 ;;
esac

echo "Watching: ${FILES[*]}"
echo "Press Ctrl+C to stop."

while inotifywait -e close_write "${FILES[@]}" 2>/dev/null; do
    pkill -SIGUSR2 waybar
    echo "[$(date +%H:%M:%S)] Reloaded"
done
