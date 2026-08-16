function _cp2077_onefetch_on_cd --on-variable PWD
    # Skip al primo invocation (startup shell — il greeting già copre)
    if not set -q _cp2077_onefetch_inited
        set -g _cp2077_onefetch_inited 1
        return
    end

    set -l new_toplevel (command git rev-parse --show-toplevel 2>/dev/null)
    if test -n "$new_toplevel"; and test "$new_toplevel" != "$_cp2077_last_repo"
        set -g _cp2077_last_repo $new_toplevel
        if command -v onefetch >/dev/null
            command onefetch 2>/dev/null
        end
    end
end
