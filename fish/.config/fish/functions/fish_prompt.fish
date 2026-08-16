function fish_prompt
    set -l last_status $status
    set -l _norm (set_color normal)
    set -l _y    (set_color FCEC0C)     # yellow corpo
    set -l _c    (set_color 25E1ED)     # cyan netrunner
    set -l _m    (set_color EA00D9)     # magenta
    set -l _r    (set_color C5003C)     # red danger
    set -l _g    (set_color 00FF9F)     # neon green ok
    set -l _d    (set_color 808080)     # dim
    set -l _b    (set_color --bold)

    # ── NODE ────────────────────────────────────────
    echo -n -s $_y$_b "▌ " $_y "NODE " $_norm $_c (prompt_hostname) "  "

    # ── CWD ─────────────────────────────────────────
    echo -n -s $_y$_b "▌ " $_y "CWD " $_norm $_c (prompt_pwd) "  "

    # ── GIT (se in repo) ────────────────────────────
    set -l git_branch (command git symbolic-ref --short HEAD 2>/dev/null; or command git rev-parse --short HEAD 2>/dev/null)
    if test -n "$git_branch"
        set -l git_dirty ""
        if not command git diff --quiet --ignore-submodules HEAD 2>/dev/null
            set git_dirty " $_r✗"
        end
        echo -n -s $_m$_b "▌ " $_m "GIT " $_norm $_y $git_branch $git_dirty $_norm "  "
    end

    # ── ERR (solo se exit != 0) ─────────────────────
    if test $last_status -ne 0
        echo -n -s $_r$_b "▌ " $_r "ERR " $_norm $_r $last_status "  "
    end

    echo

    # ── Riga 2: prompt arrow ────────────────────────
    if fish_is_root_user
        echo -n -s $_r$_b "▌ ❯ " $_norm
    else
        echo -n -s $_y$_b "▌ ❯ " $_norm
    end
end
