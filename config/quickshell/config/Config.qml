pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "Wallpapers.js" as Walls

Singleton {
    id: root

    readonly property string path:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
        + "/quickshell/settings.json"

    property alias theme: adapter.theme
    property alias apps: adapter.apps
    property alias input: adapter.input
    property alias display: adapter.display
    property alias bar: adapter.bar
    property alias windows: adapter.windows
    property alias wallpaper: adapter.wallpaper
    property alias launcher: adapter.launcher
    property alias notifications: adapter.notifications
    property alias power: adapter.power
    property alias idle: adapter.idle
    property alias battery: adapter.battery
    property alias nightLight: adapter.nightLight
    property alias lock: adapter.lock
    property alias accessibility: adapter.accessibility
    property alias startup: adapter.startup
    property alias live: adapter.live
    property alias edges: adapter.edges
    property alias gameMode: adapter.gameMode
    property alias phone: adapter.phone
    property alias cloudBackup: adapter.cloudBackup
    property alias audio: adapter.audio
    property alias weather: adapter.weather
    property alias life: adapter.life

    property bool leader: true

    function save() {
        file.writeAdapter();
        hyprReload.restart();
    }
    function setBirthday(text) {
        const t = String(text).trim();
        let m = t.match(/^(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{4})\.?$/), y, mo, d;
        if (m) { d = +m[1]; mo = +m[2]; y = +m[3]; }
        else if ((m = t.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/))) { y = +m[1]; mo = +m[2]; d = +m[3]; }
        const date = m ? new Date(y, mo - 1, d) : null;
        const ok = date && date.getMonth() === mo - 1 && date.getDate() === d && date < new Date() && y > 1900;
        life.birthday = ok ? y + "-" + String(mo).padStart(2, "0") + "-" + String(d).padStart(2, "0") : "";
        saveSoon();
    }
    function lifeText() {
        const m = (life.birthday || "").match(/^(\d{4})-(\d{2})-(\d{2})$/);
        return m ? m[3] + "." + m[2] + "." + m[1] : "";
    }

    function saveSoon() { saveLater.restart(); }
    Timer { id: saveLater; interval: 400; onTriggered: root.save() }

    function dropDim() {
        const dim = ["frappe", "macchiato"];
        if (!dim.includes(theme.flavor) && !dim.includes(theme.darkFlavor)) return;
        if (dim.includes(theme.flavor)) theme.flavor = "mocha";
        theme.darkFlavor = "mocha";
        saveSoon();
    }

    function setAccent(name) {
        theme.wallpaperAccent = false;
        if (theme.flavor === "latte") theme.accentLight = name;
        else theme.accent = name;
        saveSoon();
    }
    Timer {
        id: hyprReload
        interval: 150
        onTriggered: {
            const sig = JSON.stringify([root.display.scale, root.display.monitors]);
            Quickshell.execDetached(sig === root.displaySig ? ["hyprctl", "reload", "config-only"] : ["hyprctl", "reload"]);
            root.displaySig = sig;
        }
    }
    property string displaySig: ""
    Component.onCompleted: displaySig = JSON.stringify([display.scale, display.monitors])

    function launch(command) {
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet", "--collect", "--slice=app.slice", "--"]
            .concat(command));
    }

    function openEntry(entry) {
        const dir = entry.workingDirectory;
        launch(dir ? ["sh", "-c", 'cd "$1" && shift && exec "$@"', "sh", dir].concat(entry.command) : entry.command);
    }

    function enterToClose(done) {
        const text = done ? Tr.t("Done. Press Enter to close…") : Tr.t("Press Enter to close…");
        return "echo; read -rp '" + text.replace(/'/g, "'\\''") + "'";
    }

    function runInTerminal(script) {
        launch(["sh", "-c", `${apps.terminalRun} sh -c "$1"`, "sh", script]);
    }

    readonly property var loginSounds: ["chime", "bloom", "halo"]
    function loginSoundPath(name) {
        return Quickshell.shellPath("assets/sounds/" + (loginSounds.includes(name) ? name : "chime") + ".wav");
    }
    readonly property var notificationSounds: ["ding", "pop", "drop", "tick"]
    function notificationSoundPath(name) {
        const n = notificationSounds.includes(name) ? name : "pop";
        return Quickshell.shellPath("assets/sounds/notification" + (n === "ding" ? "" : "-" + n) + ".wav");
    }

    property bool loaded: false
    readonly property real maxVolume: audio.boost ? 1.5 : 1
    readonly property string defaultWallpaper: "/usr/share/backgrounds/vyntaris/default.jpg"
    SystemClock { id: wallpaperClock; precision: SystemClock.Minutes }
    readonly property int minuteOfDay: wallpaperClock.date.getHours() * 60 + wallpaperClock.date.getMinutes()
    readonly property string wallpaperPath: !wallpaper.path || wallpaper.path.startsWith("vyntaris:") || wallpaper.path.startsWith("/usr/share/backgrounds/vyntaris/default.") ? defaultWallpaper : expandHome(wallpaper.path)
    function wallpaperFileOf(path) {
        if (path === defaultWallpaper) return AccentWallpaper.file;
        return path.startsWith("heic:") ? (DynamicWallpaper.fileAt(path, minuteOfDay) || defaultWallpaper) : Walls.fileAt(path, minuteOfDay);
    }
    function wallpaperFile() {
        return wallpaperFileOf(wallpaperPath);
    }
    function wallpaperPending() {
        if (!loaded) return true;
        const path = wallpaperPath;
        return path === defaultWallpaper ? AccentWallpaper.pending : path.startsWith("heic:") && !DynamicWallpaper.known(path);
    }

    function expandHome(p) {
        return p && p.startsWith("~/") ? Quickshell.env("HOME") + p.slice(1) : p;
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr/user.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: if (root.leader) Quickshell.execDetached(["hyprctl", "reload", "config-only"])
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        blockLoading: true

        onFileChanged: {
            reload();
            if (root.leader) hyprReload.restart();
        }
        onLoadFailed: error => {
            root.loaded = true;
            if (error === FileViewError.FileNotFound) writeAdapter();
        }
        onLoaded: {
            root.loaded = true;
            let ok = false;
            try { const d = JSON.parse(text()); ok = d !== null && typeof d === "object" && !Array.isArray(d); } catch (e) {}
            if (ok) { if (root.leader) Qt.callLater(root.dropDim); return; }
            if (!root.leader) return;
            Quickshell.execDetached(["sh", "-c",
                'cp -f "$1" "$1.broken" && notify-send -a Vyntaris -i dialog-warning "Your settings couldn\'t be read" '
                + '"The defaults are in use. What the file held is kept in $1.broken"', "sh", root.path]);
        }

        JsonAdapter {
            id: adapter

            property JsonObject theme: JsonObject {
                property string flavor: "mocha"
                property bool autoFlavor: false
                property string darkFlavor: "mocha"
                property string lightFrom: "07:00"
                property string darkFrom: "19:00"
                property string accent: "mauve"
                property string accentLight: "mauve"
                property string fontFamily: "Inter"
                property string monoFamily: "JetBrains Mono"
                property int fontSize: 13
                property real animationSpeed: 1.5
                property string animationStyle: "snappy"

                property bool syncApps: true
                property string gtkThemeDark: "adw-gtk3-dark"
                property string gtkThemeLight: "adw-gtk3"
                property string iconThemeDark: "Papirus-Dark"
                property string iconThemeLight: "Papirus-Light"
                property string cursorTheme: "Bibata-Modern-Ice"
                property int cursorSize: 24
                property bool sounds: true
                property string loginSound: "chime"
                property string notificationSound: "pop"
                property bool wallpaperAccent: false
            }

            property JsonObject apps: JsonObject {
                property string terminal: "kitty"
                property string terminalRun: "kitty"
                property string fileManager: "thunar"
                property string browser: "firefox"
                property string editor: "code"
                property bool aur: false
            }

            property JsonObject input: JsonObject {
                property string kbLayout: "us"
                property string kbVariant: ""
                property string kbOptions: ""
                property bool naturalScroll: true
                property bool tapToClick: true
                property real sensitivity: 0
                property bool mouseAccel: false
            }

            property JsonObject windows: JsonObject {
                property int rounding: 10
                property int gapsIn: 5
                property int border: 2
            }

            property JsonObject display: JsonObject {
                property var scale: 1
                property var monitors: []
            }

            property JsonObject bar: JsonObject {
                property int height: 28
                property int endCurve: 16
                property bool endCorners: false
                property string notchStyle: "slant"
                property string corners: "round"
                property bool flatIsland: false
                property string inside: "rounded"
                property int windowGap: 8
                property string clockFormat: "HH:mm"
                property string clockShow: "both"
                property bool showWindowTitle: true
                property bool workspaceIcons: false
                property bool workspaceIconsAccent: true
                property bool privacy: true
                property bool gpu: true
            }

            property JsonObject wallpaper: JsonObject {
                property string directory: "~/Pictures/Wallpapers"
                property string path: ""
                property string fillMode: "crop"
            }

            property JsonObject launcher: JsonObject {
                property int maxVisible: 8
            }

            property JsonObject notifications: JsonObject {
                property int timeout: 6000
            }

            property JsonObject idle: JsonObject {
                property int dimAfter: 150
                property int lockAfter: 300
                property int screenOffAfter: 330
                property int suspendAfter: 1800
            }

            property JsonObject battery: JsonObject {
                property int low: 20
                property int critical: 5
                property bool autoPowerSaver: true
                property bool performanceOnAC: true
            }

            property JsonObject nightLight: JsonObject {
                property bool automatic: false
                property string start: "20:00"
                property string end: "07:00"
                property int temperature: 4000
            }

            property JsonObject live: JsonObject {
                property int countdown: 3
            }

            property JsonObject gameMode: JsonObject {
                property bool auto: true
                property bool silence: true
                property bool performance: true
                property bool stats: true
            }

            property JsonObject phone: JsonObject {
                property bool enabled: false
            }

            property JsonObject cloudBackup: JsonObject {
                property string folders: "documents,pictures,desktop"
                property string when: "startup"
            }

            property JsonObject weather: JsonObject {
                property bool enabled: true
                property string city: ""
                property real lat: 0
                property real lon: 0
            }

            property JsonObject life: JsonObject {
                property string birthday: ""
                property int years: 70
            }

            property JsonObject audio: JsonObject {
                property bool boost: false
                property int noise: 0
                property string noiseMic: ""
            }

            property JsonObject edges: JsonObject {
                property bool volume: true
                property bool brightness: true
                property string corner: "bottom-left"
            }

            property JsonObject startup: JsonObject {
                property var apps: []
            }

            property JsonObject accessibility: JsonObject {
                property bool highContrast: false
            }

            property JsonObject lock: JsonObject {
                property bool widgets: true
            }

            property JsonObject power: JsonObject {
                property string lock: "loginctl lock-session"
                property string shutdown: "systemctl poweroff"
                property string reboot: "systemctl reboot"
                property string suspend: "systemctl suspend"
                property string hibernate: "systemctl hibernate"
                property string lidAction: "suspend"
                property string logout: "hyprctl dispatch 'hl.dsp.exit()'"
            }
        }
    }
}
