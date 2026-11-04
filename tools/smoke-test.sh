#!/usr/bin/env bash
set -uo pipefail
out="${1:-/tmp/smoke}"
mkdir -p "$out"
fail=0
step() { printf '\n\033[1m:: %s\033[0m\n' "$*"; }
bad() { printf '   \033[31mFAIL\033[0m %s\n' "$*"; fail=1; }
ok() { printf '   ok %s\n' "$*"; }

user=smoke
id "$user" >/dev/null 2>&1 || useradd -m "$user"
chown "$user" "$out"
home="/home/$user"
rt="/tmp/smoke-runtime"
install -d -m700 -o "$user" -g "$user" "$rt"
as() { runuser -u "$user" -- env XDG_RUNTIME_DIR="$rt" HOME="$home" LANG=C.UTF-8 "$@"; }

plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
code_errors() {
    plain "$1" | grep -E "^ ERROR( scene| qml)?:|Failed to load configuration|is not a type|non-existent property|Invalid property|Expected token|is not installed|Non-existent attached|ReferenceError|SyntaxError|TypeError|Cannot assign to non-existent|Cannot assign object" || true
}
shell_run() {
    local name="$1" secs="$2"; shift 2
    as dbus-run-session -- env WAYLAND_DISPLAY="$display" QT_QPA_PLATFORM=wayland "$@" >"$out/$name.log" 2>&1 &
    local pid=$! waited=0
    while [ "$waited" -lt "$secs" ] || { [ "$waited" -lt 60 ] && ! plain "$out/$name.log" | grep -q "Configuration Loaded"; }; do
        sleep 1; waited=$((waited + 1))
    done
    as env WAYLAND_DISPLAY="$display" grim "$out/$name.png" >>"$out/grim.log" 2>&1 || echo "   (no screenshot, see grim.log)"
    pkill -u "$user" -f "qs " 2>/dev/null; kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    local errs; errs="$(code_errors "$out/$name.log")"
    plain "$out/$name.log" | grep -q "Configuration Loaded" && ok "$name loaded" || bad "$name never finished loading"
    if [ -n "$errs" ]; then bad "$name has code errors:"; echo "$errs" | sed 's/^/      /'; else ok "$name: no code errors"; fi
    printf '   %s warnings (see %s.log)\n' "$(plain "$out/$name.log" | grep -c "^  WARN")" "$name"
}

step "Package"
pacman -Q vyntaris hyprland quickshell || bad "not installed"
key="$(cut -d: -f1 /usr/share/pacman/keyrings/vyntaris-trusted)"
if pacman-key --list-keys "$key" >/dev/null 2>&1; then ok "pacman has Vyntaris's signing key"; else
    bad "the package didn't put its key in pacman's keyring; by hand:"
    pacman-key --populate vyntaris 2>&1 | tail -6 | sed 's/^/      /'
fi

step "Hyprland's configuration"
res="$(as Hyprland --verify-config --config /usr/share/vyntaris/hypr/hyprland.lua 2>&1)"
echo "$res" | tail -2 | sed 's/^/   /'
grep -q "config ok" <<<"$res" && ok "config" || bad "Hyprland's configuration has errors"

step "The user's first session setup"
as vyntaris-user-setup >"$out/user-setup.log" 2>&1 && ok "vyntaris-user-setup" || { bad "vyntaris-user-setup failed:"; tail -5 "$out/user-setup.log" | sed 's/^/      /'; }

step "A headless compositor"
as env WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 WLR_HEADLESS_OUTPUTS=1 \
    sway -c /dev/null >"$out/sway.log" 2>&1 &
sway=$!
display=""
for _ in $(seq 50); do
    for socket in "$rt"/wayland-*; do
        [ -e "$socket" ] && [[ "$socket" != *.lock ]] && { display="${socket##*/}"; break; }
    done
    [ -n "$display" ] && break
    sleep 0.2
done
[ -n "$display" ] && ok "sway on $display" || { bad "sway didn't start:"; tail -5 "$out/sway.log"; exit 1; }
as env WAYLAND_DISPLAY="$display" swaymsg -q output HEADLESS-1 resolution 1920x1080 2>/dev/null || true

step "The shell"
shell_run shell 20 qs -c vyntaris

step "The login screen"
g="$out/greeter"
rm -rf "$g"; mkdir -p "$g/config" "$g/components"
cp /usr/share/vyntaris/greeter/shell.qml "$g/"
cp /usr/share/vyntaris/greeter/config/Config.qml /etc/xdg/quickshell/vyntaris/config/Theme.qml \
    /etc/xdg/quickshell/vyntaris/config/Tr.qml /etc/xdg/quickshell/vyntaris/config/Palettes.js \
    /etc/xdg/quickshell/vyntaris/config/Motion.js "$g/config/"
cp /etc/xdg/quickshell/vyntaris/components/* "$g/components/"
cp /usr/share/backgrounds/vyntaris/default.jpg "$g/wallpaper.jpg"
printf '{"user":"%s","session":["vyntaris-session"],"wallpaper":"%s","flavor":"mocha","accent":"#655b94"}\n' \
    "$user" "$g/wallpaper.jpg" > "$g/greeter.json"
chown -R "$user:$user" "$g"
shell_run greeter 10 qs -p "$g"

kill "$sway" 2>/dev/null; wait "$sway" 2>/dev/null

step "The boot splash"
for accent in mauve "#655b94"; do
    d="$out/splash-${accent#\#}"
    if /usr/lib/vyntaris/splash-render "$d" mocha "$accent" 176 >"$d.log" 2>&1 \
        && [ "$(ls "$d"/*.png 2>/dev/null | wc -l)" -gt 100 ]; then
        ok "splash in $accent: $(ls "$d"/*.png | wc -l) frames"
    else
        bad "splash in $accent:"; tail -3 "$d.log" | sed 's/^/      /'
    fi
    rm -rf "$d"
done

echo
[ "$fail" = 0 ] && echo "SMOKE-RESULT=ok" || echo "SMOKE-RESULT=fail"
exit "$fail"
