#!/bin/sh
since="$1"
[ -n "$since" ] || since="$(stat -c %Y /var/lib/pacman/db.lck 2>/dev/null || date +%s)"
busy=0
{ [ -e /var/lib/pacman/db.lck ] || pgrep -x 'yay|paru|makepkg|pikaur|trizen|pamac' >/dev/null \
    || pgrep -a -x pacman | grep -qv -- '--dbpath'; } && busy=1
from="$(date -d "@$((since - 1))" +%Y-%m-%dT%H:%M:%S)"

window_screen() {
    for p in $(pgrep -a -x pacman | grep -v -- '--dbpath' | cut -d' ' -f1; pgrep -x 'yay|paru|makepkg|pikaur|trizen'); do
        cur="$p"
        while [ -n "$cur" ] && [ "$cur" -gt 1 ]; do
            parent="$(awk '{ print $4 }' "/proc/$cur/stat" 2>/dev/null)" || break
            if [ "$(cat "/proc/$parent/comm" 2>/dev/null)" = kitty ]; then
                sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/kitty-$parent"
                [ -S "$sock" ] && kitty @ --to "unix:$sock" get-text --match "pid:$cur" --extent screen 2>/dev/null && return 0
                break
            fi
            cur="$parent"
        done
    done
    return 1
}
run_dir="${XDG_RUNTIME_DIR:-/tmp}"
screen="$(window_screen)" && source=terminal || source=log
if [ "$source" = log ]; then
    run="$(find "$run_dir/vyntaris-upgrade" "$run_dir/vyntaris-aur" -maxdepth 1 -name '*log' -newermt "@$((since - 1))" -type f 2>/dev/null | head -1)"
    # As written, carriage returns and colours too: the view draws it like a terminal (Terminal.screen), so a
    # progress line that redraws itself stays one line.
    [ -n "$run" ] && screen="$(tail -c 24000 "$run")" && source=run
fi
tail -n 4000 /var/log/pacman.log 2>/dev/null | awk -v from="$from" -v since="$since" -v busy="$busy" -v source="$source" '
    substr($1, 2, 19) < from { next }
    { line = $0; sub(/^\[[^]]*\] /, "", line); lines[++nl] = line }
    /\[PACMAN\] Running / { if (open) failed = 1; open = 0 }
    /\[ALPM\] transaction started/ { open = 1 }
    /\[ALPM\] transaction completed/ { open = 0; done++ }
    /\[ALPM\] transaction (failed|interrupted)/ { open = 0; failed = 1 }
    /\[ALPM\] (upgraded|installed|removed|reinstalled|downgraded) / { n++; last = $4 }
    /\[ALPM\] removed / { removed++ }
    END {
        state = open ? "running" : failed ? "failed" : done > 0 ? "done" : "none"
        print since, state, n + 0, busy, (last == "" ? "-" : last), source, removed + 0
        if (source == "log") for (i = (nl > 80 ? nl - 79 : 1); i <= nl; i++) print lines[i]
    }'
[ "$source" != log ] && printf '%s\n' "$screen" | sed 's/[[:space:]]*$//'
exit 0
