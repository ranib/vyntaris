#!/bin/sh
helper="${1:-}"
state="${XDG_RUNTIME_DIR:-/tmp}/vyntaris-upgrade"
mkdir -p "$state" && : > "$state/log" && rm -f "$state/result"
log="$state/log"

T() { /usr/lib/vyntaris/json tr "$@" 2>/dev/null || printf '%s' "$1"; }

end() {
    echo "$1" > "$state/result"
    case "$1" in
        ok) notify-send -a "$(T "Updates")" -i system-software-update "$(T "Up to date")" "$2" ;;
        failed) notify-send -a "$(T "Updates")" -i dialog-warning -u critical "$(T "The update didn't finish")" \
            "${2:+$2. }$(T "Open Updates to see it through in a terminal.")" ;;
    esac
    exit 0
}
asked() {
    grep -q 'authentication agent' "$log" && end failed
    case "$1" in 126|127) end cancelled ;; esac
}

pkexec pacman -Syu --noconfirm >> "$log" 2>&1
code=$?; asked "$code"
[ "$code" -eq 0 ] || end failed "$(grep -m1 -iE '^error:' "$log" | sed 's/^error: *//')"

if [ -n "$helper" ] && command -v "$helper" >/dev/null && [ -n "$("$helper" -Qua 2>/dev/null)" ]; then
    if ! pacman -Q base-devel >/dev/null 2>&1; then
        pkexec pacman -S --needed --noconfirm base-devel >> "$log" 2>&1
        code=$?; asked "$code"; [ "$code" -eq 0 ] || end failed "$(T "The build tools couldn't be installed.")"
    fi
    case "$helper" in
        paru) paru -Sua --noconfirm --skipreview --sudo pkexec >> "$log" 2>&1 ;;
        *) yay -Sua --noconfirm --answerclean None --answerdiff None --answeredit None --removemake \
               --sudo pkexec >> "$log" 2>&1 ;;
    esac
    code=$?; asked "$code"
    [ "$code" -eq 0 ] || end failed "$(T "An app from the AUR couldn't be built.")"
fi
end ok "$(T "Everything is updated.")"
