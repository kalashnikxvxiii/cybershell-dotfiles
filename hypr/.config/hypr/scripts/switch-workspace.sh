#!/usr/bin/env bash
# switch-workspace.sh [workspace_assoluto]
# Imposta l'animazione in base alla posizione relativa (1-10) e switcha.

CURVE="easeInOutQuart"
SPEED="6"

anim_style() {
    case "$1" in
        1)  echo "slide"         ;;
        2)  echo "slidevert"     ;;
        3)  echo "slidefade"     ;;
        4)  echo "slidevert"     ;;
        5)  echo "slide"         ;;
        6)  echo "slidevert"     ;;
        7)  echo "slidefadevert" ;;
        8)  echo "slide"         ;;
        9)  echo "slidevert"     ;;
        10) echo "slidefade"     ;;
        *)  echo "slide"         ;;
    esac
}

TARGET="$1"

# Posizione relativa 1-10 (ws 11→1, 12→2, … 20→10)
REL=$(( (TARGET - 1) % 10 + 1 ))

STYLE=$(anim_style "$REL")
hyprctl keyword animation "workspaces,1,${SPEED},${CURVE},${STYLE}"
hyprctl dispatch workspace "$TARGET"
