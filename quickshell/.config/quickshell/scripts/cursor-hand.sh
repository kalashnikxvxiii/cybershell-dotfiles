#!/usr/bin/env bash
# cursor-hand.sh hand|pulse -- what the Cyberpunk cursor theme shows over links and buttons:
# the pointing hand, or CyberArch's pulsing arrow. Both files stay; only the links move.
set -euo pipefail
dir="$HOME/.local/share/icons/Cyberpunk/cursors"
case "${1:-}" in
    hand)  target=".pulse-backup/hand1" ;;
    pulse) target="pointer_pulse" ;;
    *)     echo "usage: $0 hand|pulse" >&2; exit 2 ;;
esac
[ -f "$dir/$target" ] || { echo "cursor-hand: $dir/$target missing" >&2; exit 1; }
for n in pointer hand hand1 hand2 link_cursor; do
    ln -sfn "$target" "$dir/$n"
done
# Running apps keep the old shape until the theme is set again
# Hyprland keeps a theme it already has: through another one, so it reads the files again
hyprctl setcursor Adwaita "${XCURSOR_SIZE:-24}" >/dev/null
hyprctl setcursor "${XCURSOR_THEME:-Cyberpunk}" "${XCURSOR_SIZE:-24}" >/dev/null
