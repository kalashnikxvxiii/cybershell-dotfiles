function fish_right_prompt
    set -l _c    (set_color 25E1ED)
    set -l _d    (set_color 808080)
    set -l _norm (set_color normal)

    # Last cmd duration (solo se > 1s)
    if test "$CMD_DURATION" -gt 1000
        set -l dur (math --scale=1 "$CMD_DURATION / 1000")
        echo -n -s $_d "took " $_c $dur "s  "
    end

    # Ora corrente
    echo -n -s $_d (date "+%H:%M:%S") $_norm
end
