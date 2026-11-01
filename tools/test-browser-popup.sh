#!/usr/bin/env bash
# Firefox in a nested Hyprland with the real window handling: a popup never touches the tiles, a full window does.
# It needs a running Hyprland and Firefox, so it runs on a desktop and not in CI.
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
S="$(mktemp -d "${TMPDIR:-/tmp}/vyntaris-popup.XXXXXX")"
PORT=18765
FAILED=0

check() {
    if [ "$2" = "$3" ]; then echo "  ok    $1"
    else echo "  FAIL  $1: wanted '$3', got '$2'"; FAILED=1; fi
}
window() {
    hyprctl clients -j | python3 -I -c "
import json,sys
for c in json.load(sys.stdin):
    if sys.argv[1] in c['title']: print('floating' if c['floating'] else 'tiled', 'x'.join(map(str, c['size'])))" "$1" | head -1
}
wait_for() { for _ in $(seq 150); do [ -n "$(window "$1")" ] && return; sleep 0.1; done; }

mkdir -p "$S/www" "$S/profile" "$S/home"
echo "<title>Opener</title><script>setTimeout(() => window.open('/popup.html', 'x', 'width=500,height=600'), 1500)</script>" > "$S/www/opener.html"
echo "<title>Plain popup</title>" > "$S/www/popup.html"
echo 'user_pref("dom.disable_open_during_load", false);' > "$S/profile/user.js"
python3 -I - "$R/config/hypr/hyprland.lua" > "$S/windows.lua" <<'PY'
import sys
s = open(sys.argv[1]).read()
print(s[s.index("local browserWindows = {}"):s.index("do\n    local mine")])
PY
cat > "$S/nested.lua" <<LUA
hl.monitor({ output = "", mode = "1920x1080", position = "auto", scale = 1 })
hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0,
                     disable_watchdog_warning = true, enable_anr_dialog = false },
            debug = { suppress_errors = true }, animations = { enabled = false } })
dofile("$S/windows.lua")
LUA

before="$(hyprctl instances -j | python3 -I -c "import json,sys;print(' '.join(i['instance'] for i in json.load(sys.stdin)))")"
(env -u HYPRLAND_INSTANCE_SIGNATURE Hyprland --config "$S/nested.lua" > "$S/hyprland.log" 2>&1 < /dev/null &)
sleep 4
read -r sig wl pid < <(BEFORE="$before" hyprctl instances -j | BEFORE="$before" python3 -I -c "
import json,os,sys
[print(i['instance'], i['wl_socket'], i['pid']) for i in json.load(sys.stdin) if i['instance'] not in os.environ['BEFORE'].split()]")
[ -n "${sig:-}" ] || { echo "  FAIL  no nested Hyprland"; exit 1; }
export HYPRLAND_INSTANCE_SIGNATURE=$sig WAYLAND_DISPLAY=$wl HOME=$S/home
hyprctl output create headless CHK > /dev/null; sleep 0.5
hyprctl eval 'hl.monitor({ output = "CHK", mode = "1920x1080@60", position = "0x0", scale = 1 })' > /dev/null
hyprctl eval 'hl.monitor({ output = "WAYLAND-1", disabled = true })' > /dev/null
sleep 1

python3 -I -m http.server --bind 127.0.0.1 --directory "$S/www" "$PORT" > /dev/null 2>&1 &
SERVER=$!
firefox --profile "$S/profile" --new-instance "http://127.0.0.1:$PORT/opener.html" > "$S/firefox.log" 2>&1 &
FIREFOX=$!

wait_for "Opener"
alone="$(window "Opener")"
wait_for "Plain popup"; sleep 1
check "a popup opens floating at its size" "$(window "Plain popup")" "floating 520x720"
check "the window behind a popup keeps its size" "$(window "Opener")" "$alone"

hyprctl dispatch 'hl.dsp.focus({ window = "title:Opener" })' > /dev/null 2>&1; sleep 0.3
wtype -M ctrl n -m ctrl
for _ in $(seq 100); do [ "$(hyprctl clients -j | python3 -I -c "import json,sys;print(len(json.load(sys.stdin)))")" -ge 3 ] && break; sleep 0.1; done
sleep 1
check "a new window goes to the tiles" "$(hyprctl clients -j | python3 -I -c "
import json,sys
print(sum(not c['floating'] for c in json.load(sys.stdin)))")" 2

kill "$FIREFOX" "$SERVER" 2>/dev/null; sleep 1; kill "$pid" 2>/dev/null
pkill -f "$S/profile" 2>/dev/null
rm -rf "$S"
exit "$FAILED"
