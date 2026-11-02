#!/bin/bash
# The README's screenshots, from this tree's shell in a nested Hyprland with its own home and runtime folder,
# in your theme but without your name, network or place. It needs a running Hyprland, so it runs on a desktop.
set -u
R="$(cd "$(dirname "$0")/.." && pwd)"
S="$(mktemp -d "${TMPDIR:-/tmp}/vyntaris-readme.XXXXXX")"
rm -rf "$S"; mkdir -p "$S/nest" "$S/shots"
Q=$S/q; H=$S/home; O=$S/shots
cp -r "$R/config/quickshell" "$Q"
grep -rl '/usr/share/backgrounds/vyntaris' "$Q" | xargs sed -i "s|/usr/share/backgrounds/vyntaris|$Q/assets/wallpapers|g"
sed -i 's|readonly property string me: Quickshell.env("USER")|readonly property string me: "Vyntaris"|' "$Q/services/Accounts.qml"
sed -i 's#(Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/shell-locked"#Quickshell.env("HOME") + "/shell-locked"#' "$Q/services/LockState.qml"
sed -i 's#text: bar.wifiNetwork?.name ?? ""#text: bar.wifiNetwork ? "Home" : ""#' "$Q/modules/bar/Bar.qml"
sed -i 's#root.wifiNetwork?.name ?? Tr.t("Not connected")#(root.wifiNetwork ? "Home" : Tr.t("Not connected"))#' "$Q/modules/island/ControlView.qml"
grep -q '"Home"' "$Q/modules/bar/Bar.qml" && grep -q '"Home"' "$Q/modules/island/ControlView.qml" || { echo "the network name isn't hidden" >&2; exit 1; }
grep -q 'Quickshell.env("HOME") + "/shell-locked"' "$Q/services/LockState.qml" || { echo "the lock marker isn't moved out of the real session" >&2; exit 1; }

cat > "$S/nest/site.lua" <<'LUA'
hl.monitor({ output = "", mode = "1920x1080", position = "auto", scale = 1 })
hl.config({
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0,
             disable_watchdog_warning = true, enable_anr_dialog = false },
    debug = { suppress_errors = true },
    general = { gaps_in = 5, gaps_out = 8, border_size = 2, layout = "dwindle",
                col = { active_border = { colors = { "rgba(cba6f7ff)", "rgba(cba6f740)" }, angle = 135 }, inactive_border = "rgba(313244cc)" } },
    decoration = { rounding = 12, rounding_power = 2, shadow = { enabled = false }, blur = { enabled = false } },
    animations = { enabled = false },
    input = { follow_mouse = 0 },
    cursor = { invisible = true },
})
hl.layer_rule({ name = "qs-no-anim", match = { namespace = "^quickshell" }, no_anim = true })
LUA

mkdir -p "$H/.config/quickshell" "$H/.config/qt6ct" "$H/.local/state/quickshell/by-shell/vyntaris" "$H/.local/state/vyntaris" \
    "$H/Pictures" "$H/Documents" "$H/Downloads" "$H/Music" "$H/Videos" "$H/.mozilla-shots" "$H/.config/kitty"
touch "$H/.local/state/quickshell/by-shell/vyntaris/welcome-done"
for f in crashes-seen errors-seen; do echo $(( $(date +%s) * 1000000 )) > "$H/.local/state/vyntaris/$f"; done
ln -s "$HOME/.local/share/applications" "$H/.local/share-apps" 2>/dev/null
mkdir -p "$H/.local/share"; ln -s "$HOME/.local/share/icons" "$H/.local/share/icons" 2>/dev/null
cp "$HOME/.config/kitty/"* "$H/.config/kitty/" 2>/dev/null
cp -r "$HOME/.config/qt6ct/." "$H/.config/qt6ct/"
mkdir -p "$H/.config/gtk-3.0" "$H/.config/gtk-4.0" "$H/.config/dconf"
cp "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/settings.ini" "$H/.config/gtk-3.0/" 2>/dev/null
cp "$HOME/.config/gtk-4.0/"* "$H/.config/gtk-4.0/" 2>/dev/null
cp "$HOME/.config/dconf/user" "$H/.config/dconf/user"
chrome="$(find "$HOME/.config/mozilla" "$HOME/.mozilla" -maxdepth 4 -name chrome -type d 2>/dev/null | head -n1)"
[ -n "$chrome" ] && cp -r "$chrome" "$H/.mozilla-shots/chrome"
python3 -I - "$H" "$HOME/.config/quickshell/settings.json" <<'PYEND'
import json, sys
h, mine = sys.argv[1], sys.argv[2]
d = json.load(open(mine))
d["wallpaper"] = {"path": "", "directory": "~/Pictures", "fillMode": "crop"}
d["weather"] = {"enabled": True, "city": "Belgrade", "lat": 44.8125, "lon": 20.4612}
for k in ("life", "phone", "cloudBackup"):
    d.pop(k, None)
d["theme"].update({"sounds": False, "loginSound": "off", "syncApps": False})
json.dump(d, open(h + "/.config/quickshell/settings.json", "w"), indent=2)
PYEND
printf 'user_pref("browser.shell.checkDefaultBrowser", false);\nuser_pref("browser.aboutwelcome.enabled", false);\nuser_pref("datareporting.policy.dataSubmissionEnabled", false);\nuser_pref("toolkit.telemetry.reportingpolicy.firstRun", false);\nuser_pref("browser.startup.homepage_override.mstone", "ignore");\nuser_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n' > "$H/.mozilla-shots/user.js"

before="$(hyprctl instances -j | python3 -I -c "import json,sys;print(' '.join(i['instance'] for i in json.load(sys.stdin)))")"
(env -u HYPRLAND_INSTANCE_SIGNATURE Hyprland --config "$S/nest/site.lua" > "$S/nest/hypr.log" 2>&1 < /dev/null &); sleep 4
read -r sig wl pid < <(BEFORE="$before" hyprctl instances -j | BEFORE="$before" python3 -I -c "
import json,os,sys
[print(i['instance'], i['wl_socket'], i['pid']) for i in json.load(sys.stdin) if i['instance'] not in os.environ['BEFORE'].split()]")
[ -n "${sig:-}" ] || { echo "no nested Hyprland"; exit 1; }
REAL_RT="$XDG_RUNTIME_DIR"
H_() { XDG_RUNTIME_DIR=$REAL_RT HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl "$@" > /dev/null; }
H_ output create headless SITE; sleep 0.5
H_ eval 'hl.monitor({ output = "SITE", mode = "1920x1080@60", position = "0x0", scale = 1 })'
H_ eval 'hl.monitor({ output = "WAYLAND-1", disabled = true })'
sleep 1
RUN="$REAL_RT/vyn-shots"; rm -rf "$RUN"; mkdir -m 700 "$RUN"
ln -s "$REAL_RT/$wl" "$RUN/$wl"; ln -s "$REAL_RT/$wl.lock" "$RUN/$wl.lock"; ln -s "$REAL_RT/hypr" "$RUN/hypr"; ln -s "$REAL_RT/pipewire-0" "$RUN/pipewire-0"
export XDG_RUNTIME_DIR="$RUN" WAYLAND_DISPLAY="$wl" HYPRLAND_INSTANCE_SIGNATURE=$sig HOME=$H XDG_CONFIG_HOME=$H/.config XDG_CACHE_HOME=$H/.cache \
    XDG_DATA_HOME=$H/.local/share XDG_STATE_HOME=$H/.local/state XDG_PICTURES_DIR=$H/Pictures \
    QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=qt6ct MOZ_ENABLE_WAYLAND=1
ipc() { qs -p "$Q/shell.qml" ipc call "$@" > /dev/null 2>&1; }
shot() { sleep "${2:-1.5}"; timeout 10 grim -o SITE "$O/$1.png" 2>> "$S/nest/grim.log"; echo "shot $1 rc=$?"; }

dbus-run-session -- bash -c '
    awww-daemon > "$0/nest/awww.log" 2>&1 &
    sleep 1
    qs -p "$1/shell.qml" > "$0/nest/shell.log" 2>&1 &
    sleep 14
    touch "$0/nest/ready"
    while [ ! -e "$0/nest/stop" ]; do sleep 1; done
' "$S" "$Q" &
DBUS=$!
for _ in $(seq 60); do [ -e "$S/nest/ready" ] && break; sleep 1; done
BUSADDR="$(tr '\0' '\n' < /proc/$(pgrep -f -n "qs -p $Q/shell.qml")/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')"
export DBUS_SESSION_BUS_ADDRESS="$BUSADDR"

ipc notifications clear; sleep 1
H_ dispatch "hl.dsp.cursor.move({ x = 1910, y = 1070 })"; sleep 0.3
ipc launcher query "fi"; shot launcher 2
ipc island close; ipc control open; shot control 5
ipc island close; sleep 1

firefox --profile "$H/.mozilla-shots" --new-instance "https://wiki.archlinux.org/title/Hyprland" > "$S/nest/ff.log" 2>&1 & FF=$!
sleep 16
wtype -M ctrl -k w -m ctrl
sleep 3
kitty zsh -c 'fastfetch --structure OS:Kernel:Packages:Shell:WM:Terminal:CPU:Memory:Disk; exec sleep 600' > /dev/null 2>&1 & K=$!
sleep 3
vyntaris-store > "$S/nest/store.log" 2>&1 & ST=$!
sleep 12
shot desk 2
kill $K $ST $FF 2>/dev/null; sleep 2

H_ eval 'hl.window_rule({ name = "vyntaris-apps", match = { class = "^org\\.vyntaris\\..+$" }, float = true, center = true })'
H_ eval 'hl.window_rule({ name = "shell-apps", match = { class = "^org\\.quickshell$" }, float = true, center = true })'
VYNTARIS_DOCTOR=/usr/lib/vyntaris/doctor vyntaris-health > "$S/nest/doctor.log" 2>&1 & p=$!; shot doctor 45; kill $p 2>/dev/null; sleep 1
vyntaris-store > "$S/nest/store.log" 2>&1 & p=$!; shot store 14; kill $p 2>/dev/null; sleep 1
VYNTARIS_APP_CALL=open VYNTARIS_APP_ARG=bar qs -p "$Q/settings.qml" > "$S/nest/settings.log" 2>&1 & p=$!; shot settings 5; kill $p 2>/dev/null; sleep 1

ipc notifications clear; ipc lock lock; shot lock 4

touch "$S/nest/stop"; sleep 2
pkill -f "qs -p $Q" 2>/dev/null; kill $DBUS 2>/dev/null
kill "$pid" 2>/dev/null
rm -rf "$RUN"
D="$R/docs/screenshots"
magick "$O/desk.png" -quality 86 "$D/desk.webp"
magick "$O/launcher.png" -crop 1216x760+352+0 +repage -quality 88 "$D/island-launcher.webp"
magick "$O/control.png" -quality 86 "$D/control.webp"
magick "$O/lock.png" -resize 1600x900 -quality 86 "$D/gallery-lock.webp"
for n in doctor:app-doctor store:app-store settings:app-settings; do
    magick "$O/${n%%:*}.png" -gravity center -crop 1728x1080+0+0 +repage -resize 1600x1000 -quality 88 "$D/${n#*:}.webp"
done
echo "screenshots in $D (the full pictures in $O)"
