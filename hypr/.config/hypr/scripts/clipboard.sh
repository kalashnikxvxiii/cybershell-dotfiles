#!/usr/bin/env bash
# clipboard.sh — gestione cliphist + wofi
#
# Uso:
#   clipboard.sh           → apri picker (incolla)
#   clipboard.sh delete    → apri picker (elimina singola voce)
#   clipboard.sh wipe      → svuota tutta la cronologia

MODE="${1:-paste}"

# Toggle: se wofi è già aperto lo chiude
if pgrep -x wofi > /dev/null; then
    pkill -x wofi
    exit 0
fi

case "$MODE" in
    paste)
        cliphist list \
            | wofi --dmenu --prompt "// CLIPBOARD  ·  INVIO incolla" \
            | cliphist decode \
            | wl-copy
        ;;

    delete)
        cliphist list \
            | wofi --dmenu --prompt "// CLIPBOARD  ·  INVIO elimina" \
            | cliphist delete
        ;;

    wipe)
        cliphist wipe
        notify-send "Clipboard" "Cronologia svuotata." -t 2000
        ;;
esac
