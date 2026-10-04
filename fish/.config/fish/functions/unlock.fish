function unlock --description "Azzera il contatore faillock del proprio utente (sblocca sudo senza root)"
    # Perche' serve: pam_faillock blocca l'account dopo 3 auth fallite (deny=3,
    # unlock_time=600). Contano come fallimento anche i sudo NON interattivi, che
    # abortiscono senza TTY su cui digitare ("conversation failed" nel journal):
    # script, hook, agent. Risultato: sudo rifiuta la password giusta senza che tu
    # ne abbia mai sbagliata una.
    #
    # Il file dei tally e' di proprieta' dell'utente (0660 utente:root), quindi
    # troncarlo azzera il contatore senza passare da root -- che sarebbe un giro
    # a vuoto, visto che e' proprio sudo a essere bloccato.
    #
    # NB: solo builtin di fish, niente grep: qui grep e' aliasato a ripgrep.

    set -l dir /run/faillock
    if test -r /etc/security/faillock.conf
        for line in (cat /etc/security/faillock.conf)
            set -l m (string match -r '^\s*dir\s*=\s*(\S+)' -- $line)
            test (count $m) -ge 2; and set dir $m[2]
        end
    end

    set -l tally $dir/$USER

    if not test -e $tally
        echo "faillock: nessun contatore per $USER, sudo non e' bloccato"
        return 0
    end

    set -l fails (faillock --user $USER 2>/dev/null | string match -r '^[0-9]{4}-.*')

    if test -w $tally
        : >$tally
        echo "faillock: azzerati "(count $fails)" tentativi falliti per $USER"
    else
        echo "faillock: $tally non scrivibile, serve root" >&2
        sudo faillock --user $USER --reset
    end
end
