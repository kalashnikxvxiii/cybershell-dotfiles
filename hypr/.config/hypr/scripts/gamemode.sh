#!/usr/bin/env sh
# gamemode.sh — toggle effetti compositor per gaming
GAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')

if [ "$GAMEMODE" = 1 ]; then
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0"
    hyprctl notify 1 4000 "rgb(00ff9d)" "  GAMEMODE ON"
else
    hyprctl notify 1 4000 "rgb(ea00d9)" "  GAMEMODE OFF"
    hyprctl reload
fi
