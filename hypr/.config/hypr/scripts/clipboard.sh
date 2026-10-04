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
        # La selezione va catturata PRIMA di passarla a wl-copy: se wofi viene
        # annullato (Esc, click fuori, o il pkill del toggle qui sopra) non
        # produce output, e `cliphist decode | wl-copy` riceve stdin vuoto ->
        # wl-copy prende possesso della selezione con contenuto VUOTO e
        # distrugge il clipboard. Da fuori sembra "Ctrl+V non incolla piu'
        # nulla", mentre lo scroll continua a incollare perche' la PRIMARY
        # resta intatta.
        sel=$(cliphist list | wofi --dmenu --prompt "// CLIPBOARD  ·  INVIO incolla")
        [ -n "$sel" ] || exit 0
        printf '%s\n' "$sel" | cliphist decode | wl-copy
        ;;

    delete)
        sel=$(cliphist list | wofi --dmenu --prompt "// CLIPBOARD  ·  INVIO elimina")
        [ -n "$sel" ] || exit 0
        printf '%s\n' "$sel" | cliphist delete
        ;;

    wipe)
        cliphist wipe
        notify-send "Clipboard" "Cronologia svuotata." -t 2000
        ;;
esac
