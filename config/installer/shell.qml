import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.config
import qs.components

ShellRoot {
    id: root

    property string locale: "en_US.UTF-8"
    onLocaleChanged: Tr.chosen = locale
    property string keymap: "us"
    property string variant: ""
    property string timezone: "UTC"
    property string fullName: ""
    property string user: ""
    property bool userEdited: false
    property string host: "vyntaris"
    property string pass: ""
    property string pass2: ""
    property string disk: ""
    property string fs: "btrfs"
    property string mode: "erase"
    property string part: ""
    readonly property bool preview: Quickshell.env("USER") !== "root"
    readonly property var pages: ["Welcome", "Internet", "Language & keyboard", "Time zone", "You", "Disk", "Summary", "Installing"]
    property int page: 0

    readonly property var systemUsers: ["root", "bin", "daemon", "mail", "ftp", "http", "nobody", "dbus", "polkitd",
        "rtkit", "avahi", "colord", "git", "greeter", "uuidd", "dhcpcd", "tss", "alpm", "usbmux", "geoclue",
        "flatpak", "cups", "nm-openconnect", "nm-openvpn", "brltty", "saned", "sddm", "gdm", "live", "adm", "wheel",
        "games", "video", "audio", "users", "utmp", "kvm", "render", "input"]
    readonly property bool userTaken: systemUsers.includes(user) || user.startsWith("systemd-")
    readonly property bool userOk: /^[a-z_][a-z0-9_-]{0,31}$/.test(user) && !userTaken
    readonly property bool hostOk: /^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/.test(host)
    readonly property bool passOk: pass.length > 0 && pass === pass2
    function canLeave(p) {
        if (p === 1) return online || preview || offlineReady;
        if (p === 4) return userOk && hostOk && passOk;
        if (p === 5) return disk !== "" && (mode === "erase" || (diskTable === "gpt" && !foreignBoot && (mode === "free" ? freeBytes >= minRoom : part !== "")));
        return true;
    }
    function slugOf(name) {
        const s = name.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
                      .replace(/đ/g, "dj").split(/\s+/)[0].replace(/[^a-z0-9_-]/g, "");
        return /^[a-z_]/.test(s) ? s.slice(0, 32) : "";
    }

    readonly property var locales: [
        { value: "en_US.UTF-8", label: "English (US)" }, { value: "en_GB.UTF-8", label: "English (UK)" },
        { value: "sr_RS@latin", label: "Srpski (latinica)" }, { value: "sr_RS", label: "Српски (ћирилица)" },
        { value: "hr_HR.UTF-8", label: "Hrvatski" }, { value: "de_DE.UTF-8", label: "Deutsch" },
        { value: "fr_FR.UTF-8", label: "Français" }, { value: "es_ES.UTF-8", label: "Español" },
        { value: "it_IT.UTF-8", label: "Italiano" }, { value: "pl_PL.UTF-8", label: "Polski" },
        { value: "pt_BR.UTF-8", label: "Português (Brasil)" }, { value: "ru_RU.UTF-8", label: "Русский" }
    ]
    readonly property var keymaps: [
        { layout: "us", variant: "", label: "English (US)" }, { layout: "gb", variant: "", label: "English (UK)" },
        { layout: "rs", variant: "latin", label: "Srpski (latinica)" }, { layout: "rs", variant: "", label: "Српски (ћирилица)" },
        { layout: "hr", variant: "", label: "Hrvatski" }, { layout: "si", variant: "", label: "Slovenščina" },
        { layout: "ba", variant: "", label: "Bosanski" }, { layout: "de", variant: "", label: "Deutsch" },
        { layout: "ch", variant: "", label: "Schweiz" }, { layout: "fr", variant: "", label: "Français" },
        { layout: "es", variant: "", label: "Español" }, { layout: "it", variant: "", label: "Italiano" },
        { layout: "pt", variant: "", label: "Português" }, { layout: "br", variant: "", label: "Português (Brasil)" },
        { layout: "pl", variant: "", label: "Polski" }, { layout: "cz", variant: "", label: "Čeština" },
        { layout: "hu", variant: "", label: "Magyar" }, { layout: "nl", variant: "", label: "Nederlands" },
        { layout: "se", variant: "", label: "Svenska" }, { layout: "no", variant: "", label: "Norsk" },
        { layout: "dk", variant: "", label: "Dansk" }, { layout: "fi", variant: "", label: "Suomi" },
        { layout: "gr", variant: "", label: "Ελληνικά" }, { layout: "tr", variant: "", label: "Türkçe" },
        { layout: "ru", variant: "", label: "Русский" }, { layout: "ua", variant: "", label: "Українська" }
    ]
    function setKeymap(k) {
        keymap = k.layout; variant = k.variant;
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ input = { kb_layout = "${k.layout}", kb_variant = "${k.variant}" } })`]);
    }

    property bool online: false
    property bool offlineReady: false
    Process {
        running: true
        command: ["test", "-f", "/opt/vyntaris-offline/offline.db.tar.gz"]
        onExited: code => root.offlineReady = code === 0
    }
    property bool hasWifi: false
    property var networks: []
    property string connecting: ""
    property string wifiError: ""
    Process {
        id: onlineCheck
        command: ["curl", "-fsI", "--max-time", "5", "https://archlinux.org"]
        onExited: code => {
            const was = root.online;
            root.online = code === 0;
            if (root.online && !was) geo.running = true;
        }
    }
    Timer { interval: root.online ? 15000 : 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: onlineCheck.running = true }
    Process {
        id: wifiList
        property bool rescan: true
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", rescan ? "yes" : "auto"]
        onExited: rescan = false
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}, out = [];
                for (const line of text.split("\n")) {
                    const f = []; let cur = "";
                    for (let i = 0; i < line.length; i++) {
                        if (line[i] === "\\" && i + 1 < line.length) { cur += line[++i]; continue; }
                        if (line[i] === ":") { f.push(cur); cur = ""; continue; }
                        cur += line[i];
                    }
                    f.push(cur);
                    if (f.length < 4 || !f[1]) continue;
                    const signal = parseInt(f[2]) || 0, active = f[0] === "*";
                    if (seen[f[1]]) {
                        seen[f[1]].active = seen[f[1]].active || active;
                        seen[f[1]].signal = Math.max(seen[f[1]].signal, signal);
                        continue;
                    }
                    seen[f[1]] = { ssid: f[1], signal: signal, secure: f[3] !== "" && f[3] !== "--", active: active };
                    out.push(seen[f[1]]);
                }
                root.networks = out.sort((a, b) => b.active - a.active || b.signal - a.signal);
            }
        }
    }
    Process {
        id: wifiDevice
        command: ["sh", "-c", "rfkill unblock wifi 2>/dev/null; nmcli radio wifi on 2>/dev/null; nmcli -t -f TYPE device 2>/dev/null | grep -qx wifi"]
        onExited: code => { root.hasWifi = code === 0; if (root.hasWifi) wifiList.running = true; }
    }
    Timer { interval: 3000; repeat: true; running: !root.hasWifi; triggeredOnStart: true; onTriggered: wifiDevice.running = true }
    property string wifiOpen: ""
    property bool wifiAsking: false
    function pickWifi(n) {
        if (n.active || connecting !== "") return;
        wifiError = "";
        wifiOpen = n.ssid;
        wifiAsking = n.secure;
        if (!n.secure) connectWifi(n.ssid, "");
    }
    function cancelWifi() {
        wifiOpen = "";
        wifiAsking = false;
        wifiError = "";
    }
    Timer { interval: 8000; repeat: true; running: root.hasWifi && root.page === 1 && root.connecting === "" && root.wifiOpen === ""; onTriggered: wifiList.running = true }
    Process {
        id: wifiConnect
        property string ssid: ""
        property string password: ""
        command: ["sh", "-c", 'nmcli connection delete id "$1" >/dev/null 2>&1; if [ -n "$2" ]; then nmcli device wifi connect "$1" password "$2"; else nmcli device wifi connect "$1"; fi', "sh", ssid, password]
        stderr: StdioCollector { id: wifiErr }
        onExited: code => {
            root.connecting = "";
            const last = wifiErr.text.trim().split("\n").pop().replace(/^Error: */, "");
            const pw = /secrets|password|802-11-wireless-security|psk/i.test(wifiErr.text);
            root.wifiError = code === 0 ? "" : pw || !last ? "Couldn't connect. Check the password." : "Couldn't connect." + " " + last;
            password = "";
            onlineCheck.running = true;
            if (code === 0) { root.wifiOpen = ""; root.wifiAsking = false; wifiList.running = true; }
        }
    }
    function connectWifi(ssid, password) {
        connecting = ssid; wifiError = "";
        wifiConnect.ssid = ssid; wifiConnect.password = password;
        wifiConnect.running = true;
    }

    property var zones: []
    property bool zoneGuessed: false
    Process {
        running: true
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { onStreamFinished: { root.zones = text.split("\n").filter(z => z.length > 0); if (root.online) geo.running = true; } }
    }
    Process {
        id: geo
        command: ["sh", "-c", "curl -fs --max-time 5 https://ipapi.co/timezone || curl -fs --max-time 5 'http://ip-api.com/line/?fields=timezone'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const z = text.trim();
                if (root.zones.indexOf(z) >= 0 && root.timezone === "UTC") { root.timezone = z; root.zoneGuessed = true; }
            }
        }
    }

    property var disks: []
    readonly property real minBytes: 20e9
    Process {
        id: diskList
        running: true
        command: ["sh", "-c", "boot=$(lsblk -no PKNAME \"$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null)\" 2>/dev/null | head -n1); echo \"BOOT=$boot\"; lsblk -J -d -b -o NAME,PATH,SIZE,MODEL,TYPE,TRAN,RO"]
        stdout: StdioCollector {
            onStreamFinished: {
                const nl = text.indexOf("\n");
                const boot = text.slice(5, nl).trim();
                try {
                    root.disks = JSON.parse(text.slice(nl + 1)).blockdevices
                        .filter(d => d.type === "disk" && !d.ro && d.name !== boot && !/^(zram|loop)/.test(d.name))
                        .map(d => ({ path: d.path, size: Number(d.size), model: (d.model || "").trim() || d.name, tran: d.tran || "" }));
                    if (!root.disk) {
                        const ok = root.disks.filter(d => d.size >= root.minBytes);
                        if (ok.length === 1) root.disk = ok[0].path;
                    }
                } catch (e) {}
            }
        }
    }
    function sizeOf(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + " TB" : Math.round(b / 1e9) + " GB"; }
    readonly property var diskInfo: disks.find(d => d.path === disk) ?? null

    property var parts: []
    property string diskEsp: ""
    property string diskTable: ""
    property string probedDisk: ""
    property real freeBytes: 0
    property bool earlierVyntaris: false
    property bool foreignBoot: false
    readonly property real minRoom: 30e9
    readonly property var partInfo: parts.find(p => p.path === part) ?? null
    onDiskChanged: { part = ""; parts = []; diskEsp = ""; diskTable = ""; freeBytes = 0; earlierVyntaris = false; foreignBoot = false; if (disk) partProbe.running = true; }
    onModeChanged: if (disk) partProbe.running = true
    Component.onCompleted: if (disk) partProbe.running = true
    Process {
        id: partProbe
        onRunningChanged: if (running) root.probedDisk = root.disk
        onExited: if (root.disk && root.probedDisk !== root.disk) running = true
        command: ["sh", "-c", 'lsblk -J -b -o NAME,PATH,SIZE,FSTYPE,LABEL,PARTTYPE,PARTLABEL,PTTYPE,TYPE "$1"; echo @@; '
            + 'echo "$(sgdisk -F "$1" 2>/dev/null | tail -n1) $(sgdisk -E "$1" 2>/dev/null | tail -n1) $(blockdev --getss "$1" 2>/dev/null)"', "sh", root.disk]
        stdout: StdioCollector {
            onStreamFinished: {
                const [json, tail] = text.split("@@");
                try {
                    const dev = JSON.parse(json).blockdevices[0];
                    const esp = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b";
                    const xbootldr = "bc13c2ff-59e6-4262-a352-b275fd6f7172";
                    const list = (dev.children ?? []).filter(c => c.type === "part").map(c => ({
                        path: c.path, size: Number(c.size), fstype: c.fstype || "", label: c.label || "",
                        esp: (c.parttype || "").toLowerCase() === esp,
                        boot: (c.parttype || "").toLowerCase() === xbootldr, ours: c.partlabel === "Vyntaris boot" }));
                    root.diskEsp = (list.find(p => p.esp) ?? { path: "" }).path;
                    root.diskTable = dev.pttype || "";
                    root.earlierVyntaris = list.some(p => p.boot && p.ours);
                    root.foreignBoot = list.some(p => p.boot && !p.ours);
                    root.parts = list.filter(p => !p.esp && !p.boot);
                    const [first, last, sector] = tail.trim().split(/\s+/).map(Number);
                    root.freeBytes = root.diskTable === "gpt" && first > 0 && last > first ? (last - first + 1) * sector : 0;
                } catch (e) {}
                if (root.preview) {
                    root.diskEsp = "/dev/nvme0n1p1";
                    root.diskTable = "gpt";
                    root.parts = [{ path: "/dev/nvme0n1p3", size: 380e9, fstype: "ntfs", label: Tr.t("Windows"), esp: false },
                                  { path: "/dev/nvme0n1p5", size: 120e9, fstype: "ntfs", label: "Data", esp: false }];
                    root.freeBytes = 96e9;
                }
            }
        }
    }
    function partName(p) {
        return (p.label || p.fstype || p.path.replace("/dev/", "")) + "  ·  " + sizeOf(p.size);
    }
    readonly property string diskEffect: mode === "erase" ? "Everything on this disk will be erased."
        : foreignBoot ? Tr.t("Another system's boot partition is on this disk, and only one can start from a disk: use another disk, or the whole disk.")
        : (earlierVyntaris ? Tr.t("A Vyntaris already on this disk stops starting; its files stay.") + "  " : "")
        + (mode === "free" ? (freeBytes >= minRoom
            ? Tr.t("Uses its free space (") + sizeOf(freeBytes) + (earlierVyntaris ? ")." : Tr.t("); nothing on the disk is touched."))
            : Tr.t("Only ") + sizeOf(freeBytes) + Tr.t(" free; Vyntaris needs ") + sizeOf(minRoom) + Tr.t(". Make room in the other system first (Windows: Disk Management → Shrink volume)."))
        : partInfo ? Tr.t("Only ") + partName(partInfo) + " (" + part + Tr.t(") will be erased; the rest stays.")
        : Tr.t("Pick the partition to replace."))
    readonly property bool diskRisky: mode === "erase" || (mode === "partition" && part !== "") || (mode !== "erase" && (earlierVyntaris || foreignBoot))

    property real progress: 0
    property string stepName: ""
    ListModel { id: log }
    property int result: -1
    readonly property var marks: [
        ["Partitions", 0.02, "Partitions"], ["Base system", 0.04, "Packages"], ["Settings", 0.70, "Settings"],
        ["User", 0.71, "Settings"], ["Boot loader", 0.72, "Boot loader"], ["Vyntaris", 0.75, "Desktop"],
        ["Services", 0.77, "Desktop"], ["Firewall", 0.79, "Desktop"], ["Hyprland", 0.80, "Desktop"],
        ["Graphics", 0.81, "Drivers"], ["NVIDIA", 0.83, "Drivers"], ["Timeshift", 0.85, "Desktop"],
        ["Apps run", 0.86, "Desktop"], ["Login screen", 0.87, "Login screen"], ["AUR helper", 0.88, "Desktop"],
        ["Quiet boot", 0.91, "Graphical boot"], ["Boot splash", 0.92, "Graphical boot"], ["Boot images", 0.94, "Graphical boot"],
        ["First Timeshift", 0.97, "First snapshot"], ["Cleaning up", 0.98, "Finishing"]
    ]
    property int markIndex: -1
    property string liveLine: ""
    function onLine(raw) {
        const line = raw.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "").replace(/[\r\n]/g, "");
        if (!line.trim()) return;
        liveLine = line;
        const c = line.match(/\(\s*(\d+)\/(\d+)\)/);
        if (c && markIndex >= 0 && Number(c[2]) > 0) {
            const f = Number(c[1]) / Number(c[2]);
            const part = /^\s*Total/.test(line) ? 0.6 * f : /installing|upgrading|reinstalling/.test(line) ? 0.6 + 0.4 * f : -1;
            if (part >= 0) {
                const from = marks[markIndex][1], to = markIndex + 1 < marks.length ? marks[markIndex + 1][1] : 1;
                progress = Math.max(progress, from + (to - from) * part * 0.98);
            }
        }
        if (/\[[#o\- Cc]*\]\s*\d+%\s*$/.test(line)) return;
        if (log.count >= 400) log.remove(0);
        log.append({ line });
        const m = line.match(/^:: (.*)$/);
        if (!m) return;
        for (let i = 0; i < marks.length; i++)
            if (m[1].startsWith(marks[i][0])) { markIndex = i; progress = Math.max(progress, marks[i][1]); stepName = marks[i][2]; return; }
    }
    property var repairSystems: []
    property string repairSystem: ""
    property var repairSnapshots: []
    property string repairAction: ""
    property string repairSnapshot: ""
    property int repairResult: -1
    property bool repairScanning: false
    readonly property var repairActions: [
        { id: "restore", icon: "refresh", label: Tr.t("Go back to a snapshot"), sub: "Timeshift's, taken before every update" },
        { id: "boot", icon: "power", label: Tr.t("Make the boot images again"), sub: "When it doesn't start after a kernel update" },
        { id: "packages", icon: "download", label: Tr.t("Finish an update, reinstall the desktop"), sub: "When an update was cut off · needs the internet" },
        { id: "shell", icon: "terminal", label: Tr.t("A terminal inside it"), sub: "For doing it by hand" }
    ]
    readonly property bool repairReady: repairSystem !== "" && repairAction !== "" && repairAction !== "shell"
        && (repairAction !== "restore" || repairSnapshot !== "")
    ListModel { id: repairLog }
    function openRepair() {
        page = 8; repairResult = -1; repairAction = ""; repairLog.clear();
        repairScanning = true; repairScan.running = true;
    }
    function repair() {
        if (repairAction === "shell") {
            Quickshell.execDetached(root.preview ? ["kitty", "zsh"] : ["kitty", "repair-desktop", "shell", repairSystem]);
            return;
        }
        repairLog.clear(); repairResult = -2; repairRun.running = true;
    }
    Process {
        id: repairScan
        command: root.preview ? ["sh", "-c", "sleep 1; printf '/dev/nvme0n1p2\\tbtrfs\\tVyntaris 1.7.0\\tvyntaris\\t2\\n'"]
                              : ["repair-desktop", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.repairSystems = text.trim().split("\n").filter(l => l).map(l => {
                    const f = l.split("\t");
                    return { dev: f[0], fs: f[1], name: f[2], host: f[3], snaps: Number(f[4]) };
                });
                root.repairScanning = false;
                if (root.repairSystems.length === 1) root.repairSystem = root.repairSystems[0].dev;
            }
        }
    }
    onRepairSystemChanged: { repairSnapshots = []; repairSnapshot = ""; if (repairSystem) repairSnapList.running = true; }
    Process {
        id: repairSnapList
        command: root.preview
            ? ["sh", "-c", "printf '2026-10-09_10-55-01\\t2026-10-09 10:55\\tbefore upgrade\\n2026-10-08_22-18-40\\t2026-10-08 22:18\\tbefore upgrade\\n'"]
            : ["repair-desktop", "snapshots", root.repairSystem]
        stdout: StdioCollector {
            onStreamFinished: root.repairSnapshots = text.trim().split("\n").filter(l => l).map(l => {
                const f = l.split("\t");
                return { name: f[0], when: f[1], comment: f[2] ?? "" };
            })
        }
    }
    Process {
        id: repairRun
        command: root.preview
            ? ["sh", "-c", "for s in 'The installed system' 'Boot images' Done; do printf ':: %s\\n' \"$s\"; sleep 0.6; echo '   preview'; done"]
            : ["bash", "-c", 'set -o pipefail; repair-desktop "$@" 2>&1', "sh", root.repairAction, root.repairSystem]
                .concat(root.repairAction === "restore" ? [root.repairSnapshot] : [])
        stdout: SplitParser {
            onRead: line => {
                const l = line.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "");
                if (!l.trim()) return;
                if (repairLog.count >= 400) repairLog.remove(0);
                repairLog.append({ line: l });
            }
        }
        onExited: code => root.repairResult = code
    }

    function install() {
        page = 7; progress = 0.01; stepName = "Preparing"; log.clear(); liveLine = ""; markIndex = -1; result = -1;
        installer.running = true;
    }
    Process {
        id: installer
        command: root.preview
            ? ["sh", "-c", "for s in Partitions 'Base system' Settings 'User x' 'Boot loader' Vyntaris Services Firewall Graphics Timeshift 'Login screen' 'Quiet boot' 'Boot splash' 'Boot images' 'First Timeshift snapshot' 'Cleaning up'; do printf ':: %s\\n' \"$s\"; for i in 1 2 3; do echo \"   preview: $s $i\"; sleep 0.4; done; done; echo ':: Done'"]
            : ["bash", "-c", "set -o pipefail; script -qefc 'install-desktop < /dev/null' /dev/null | tr '\\r' '\\n'"]
        environment: ({
            INSTALL_YES: "1", INSTALL_DISK: root.disk, INSTALL_USER: root.user, INSTALL_PASSWORD: root.pass,
            INSTALL_FULLNAME: root.fullName, INSTALL_HOSTNAME: root.host, INSTALL_TIMEZONE: root.timezone,
            INSTALL_KEYMAP: root.keymap, INSTALL_KBVARIANT: root.variant, INSTALL_LOCALE: root.locale,
            INSTALL_FS: root.fs, INSTALL_MODE: root.mode, INSTALL_PART: root.part
        })
        stdout: SplitParser { onRead: line => root.onLine(line) }
        onExited: code => {
            root.result = code;
            if (code === 0) { root.progress = 1; root.stepName = "Done"; }
        }
    }

    component Pick: Rectangle {
        id: pick
        property string text: ""
        property string sub: ""
        property string icon: ""
        property bool selected: false
        property bool dim: false
        signal clicked()
        implicitHeight: sub ? 48 : 38
        radius: 12
        color: selected ? Theme.alpha(Theme.text, 0.08) : pickArea.containsMouse && !dim ? Theme.hover : "transparent"
        border { width: 1; color: selected ? Theme.accent : "transparent" }
        opacity: dim ? 0.45 : 1
        Behavior on color { ColorAnim {} }
        RowLayout {
            anchors { fill: parent; leftMargin: Theme.space12; rightMargin: Theme.space12 }
            spacing: Theme.space10
            Icon { visible: pick.icon !== ""; name: pick.icon; size: 16; color: pick.selected ? Theme.accentInk : Theme.subtext0 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; elide: Text.ElideRight; text: pick.text; font.weight: pick.selected ? Font.DemiBold : Font.Normal }
                Caption { Layout.fillWidth: true; visible: pick.sub !== ""; elide: Text.ElideRight; text: pick.sub }
            }
            Icon { visible: pick.selected; name: "check"; size: 14; color: Theme.accentInk }
        }
        MouseArea { id: pickArea; anchors.fill: parent; hoverEnabled: true; cursorShape: pick.dim ? Qt.ArrowCursor : Qt.PointingHandCursor; onClicked: if (!pick.dim) pick.clicked() }
    }

    component Box: Rectangle {
        radius: 14
        color: Theme.alpha(Theme.crust, 0.35)
        border { width: 1; color: Theme.glassRim }
        clip: true
    }

    component PickList: Box {
        property alias model: list.model
        property alias delegate: list.delegate
        readonly property alias view: list
        ListView {
            id: list
            anchors { fill: parent; margins: Theme.space6 }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Theme.space2
        }
    }

    component Page: SlidePage { current: root.page }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            readonly property bool primary: modelData === Quickshell.screens[0]
            screen: modelData
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "installer"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: Theme.crust

            BlurredWallpaper {
                anchors.fill: parent
                source: Quickshell.shellPath("wallpaper.jpg")
            }

            Loader {
                anchors.fill: parent
                active: win.primary
                sourceComponent: card
            }
        }
    }

    Component {
        id: card
        Item {
            Rectangle {
                z: 5
                anchors.fill: surface
                radius: 24
                color: Theme.alpha(Theme.crust, 0.94)
                opacity: textMode.running ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { Anim { duration: Theme.durationNormal } }
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.space10
                    Icon { Layout.alignment: Qt.AlignHCenter; name: "terminal"; size: 34; color: Theme.accentInk }
                    Label { Layout.alignment: Qt.AlignHCenter; font.pixelSize: Theme.fontSizeTitle; font.weight: Font.Bold; text: Tr.t("The text installer is open") }
                    Label { Layout.alignment: Qt.AlignHCenter; color: Theme.subtext0; text: Tr.t("Close it (Super+Q, or Enter once it ends) to come back here.") }
                }
            }
            Surface {
                id: surface
                anchors.centerIn: parent
                width: Math.min(880, parent.width - 48)
                height: Math.min(600, parent.height - 48)
                radius: 24
                scale: 0.92
                opacity: 0
                Component.onCompleted: { scale = 1; opacity = 1; }
                Behavior on scale { Anim { duration: Theme.durationSlow; easing.bezierCurve: Theme.curveSpring } }
                Behavior on opacity { Anim { duration: Theme.durationNormal } }
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.alpha("#000000", 0.45); shadowBlur: 1.0; shadowVerticalOffset: 6 }

                ColumnLayout {
                    anchors { fill: parent; margins: 28 }
                    spacing: Theme.space20

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space14
                        Icon { name: "vyntaris"; size: 22; color: Theme.accentInk }
                        ColumnLayout {
                            spacing: Theme.space2
                            Caption { text: root.preview ? Tr.t("Preview: nothing will be erased") : "Vyntaris" }
                            Label { text: root.page === 8 ? Tr.t("Repair") : Tr.t(root.pages[root.page]); font.pixelSize: Theme.fontSizeHeading; font.weight: Font.Bold }
                        }
                        Item { Layout.fillWidth: true }
                        Row {
                            visible: root.page !== 8
                            spacing: Theme.space6
                            Repeater {
                                model: root.pages.length
                                Rectangle {
                                    required property int index
                                    width: index === root.page ? 30 : 16
                                    height: 8
                                    radius: 3
                                    color: index <= root.page ? Theme.accent : Theme.alpha(Theme.text, 0.12)
                                    Behavior on width { Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring } }
                                    Behavior on color { ColorAnim {} }
                                }
                            }
                        }
                    }

                    Item {
                        id: pagesArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Page {
                            index: 0
                            ColumnLayout {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, 520)
                                spacing: Theme.space16
                                Logo { Layout.alignment: Qt.AlignHCenter; size: 84; animated: Theme.speed > 0 }
                                Label { Layout.alignment: Qt.AlignHCenter; text: Tr.t("Welcome to Vyntaris"); font.pixelSize: Theme.fontSize + 15; font.weight: Font.Bold }
                                Label {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    color: Theme.subtext0
                                    text: Tr.t("Hyprland and Quickshell, in Catppuccin colors. A few questions and it installs on its own.")
                                }
                            }
                        }

                        Page {
                            index: 1
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.space12
                                RowLayout {
                                    spacing: Theme.space12
                                    Rectangle {
                                        implicitWidth: 40; implicitHeight: 40; radius: 20
                                        color: root.online ? Theme.accent : Theme.alpha(Theme.text, 0.06)
                                        Icon { anchors.centerIn: parent; name: root.online ? "wifi" : "wifi-off"; size: 18; color: root.online ? Theme.textOnAccent : Theme.overlay1 }
                                    }
                                    ColumnLayout {
                                        spacing: 0
                                        Label { font.weight: Font.DemiBold; text: root.online ? Tr.t("Connected") : Tr.t("Not connected") }
                                        Label {
                                            color: Theme.subtext0
                                            text: root.online ? Tr.t("The installation downloads the newest packages.")
                                                : root.offlineReady ? Tr.t("You can go on without internet: everything is on this USB. Updates come later.")
                                                : root.networks.some(n => n.active) ? Tr.t("Connected to Wi-Fi, waiting for the internet…")
                                                : root.hasWifi ? Tr.t("Plug in a network cable, or pick a Wi-Fi network.") : Tr.t("No Wi-Fi here. Plug in a network cable.")
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Button { visible: root.hasWifi && !root.wifiAsking; icon: "refresh"; label: Tr.t("Refresh"); onClicked: { wifiList.rescan = true; wifiList.running = true; } }
                                }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: root.hasWifi && !root.wifiAsking
                                    PickList {
                                        anchors.fill: parent
                                        model: root.networks
                                        delegate: Rectangle {
                                            id: net
                                            required property var modelData
                                            readonly property bool joining: root.connecting === modelData.ssid
                                            width: ListView.view.width
                                            height: 52
                                            radius: 12
                                            color: modelData.active ? Theme.accent : netArea.containsMouse ? Theme.hover : "transparent"
                                            Behavior on color { ColorAnim {} }
                                            RowLayout {
                                                anchors { fill: parent; leftMargin: Theme.space14; rightMargin: Theme.space14 }
                                                spacing: Theme.space12
                                                Icon {
                                                    name: "wifi"
                                                    level: Math.min(3, Math.floor(net.modelData.signal / 25))
                                                    size: 18
                                                    color: net.modelData.active ? Theme.textOnAccent : Theme.subtext0
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 0
                                                    Label {
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                        font.weight: net.modelData.active ? Font.DemiBold : Font.Normal
                                                        color: net.modelData.active ? Theme.textOnAccent : Theme.text
                                                        text: net.modelData.ssid
                                                    }
                                                    Label {
                                                        Layout.fillWidth: true
                                                        visible: text !== ""
                                                        elide: Text.ElideRight
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: net.modelData.active ? Theme.textOnAccent : Theme.overlay1
                                                        text: net.joining ? Tr.t("Connecting") : !net.modelData.secure && !net.modelData.active ? Tr.t("Open") : ""
                                                    }
                                                }
                                                Spinner { visible: net.joining; size: 16 }
                                                Icon { visible: net.modelData.active; name: "check"; size: 16; color: Theme.textOnAccent }
                                                Icon { visible: !net.joining && !net.modelData.active && net.modelData.secure; name: "lock"; size: 14; color: Theme.overlay1 }
                                            }
                                            MouseArea {
                                                id: netArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.pickWifi(net.modelData)
                                            }
                                        }
                                    }
                                    Row {
                                        anchors.centerIn: parent
                                        visible: root.networks.length === 0
                                        spacing: Theme.space8
                                        Spinner { anchors.verticalCenter: parent.verticalCenter; size: 14 }
                                        Label { anchors.verticalCenter: parent.verticalCenter; overline: true; color: Theme.overlay1; text: Tr.t("Scanning…") }
                                    }
                                }
                                Label {
                                    Layout.fillWidth: true
                                    visible: !root.wifiAsking && root.wifiError !== ""
                                    wrapMode: Text.WordWrap
                                    color: Theme.error
                                    text: root.wifiError
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    visible: root.wifiAsking
                                    spacing: Theme.space14
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.space12
                                        Rectangle {
                                            implicitWidth: 38; implicitHeight: 38; radius: Theme.r(12)
                                            color: Theme.accent
                                            Icon { anchors.centerIn: parent; name: "lock"; size: 17; color: Theme.textOnAccent }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.space2
                                            Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.DemiBold; text: root.wifiOpen }
                                            Label {
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.overlay1
                                                text: root.connecting !== "" ? Tr.t("Connecting") : Tr.t("Type your password")
                                            }
                                        }
                                        Spinner { visible: root.connecting !== ""; size: 18 }
                                    }
                                    Field {
                                        id: wifiPass
                                        Layout.fillWidth: true
                                        implicitHeight: 44
                                        secret: true
                                        canReveal: true
                                        mono: true
                                        invalid: root.wifiError !== ""
                                        enabled: root.connecting === ""
                                        placeholder: Tr.t("Password")
                                        onTextChanged: if (text) root.wifiError = ""
                                        onVisibleChanged: if (visible) { text = ""; revealed = false; input.forceActiveFocus(); }
                                        Keys.onEscapePressed: root.cancelWifi()
                                        Connections {
                                            target: wifiPass.input
                                            function onAccepted() { if (wifiPass.text.length >= 8 && root.connecting === "") root.connectWifi(root.wifiOpen, wifiPass.text); }
                                        }
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        visible: root.wifiError !== ""
                                        wrapMode: Text.WordWrap
                                        color: Theme.error
                                        font.pixelSize: Theme.fontSizeSmall
                                        text: root.wifiError
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.space8
                                        Button { Layout.fillWidth: true; Layout.preferredWidth: 1; text: Tr.t("Cancel"); onClicked: root.cancelWifi() }
                                        Button {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            primary: true
                                            active: wifiPass.text.length >= 8 && root.connecting === ""
                                            text: Tr.t("Connect")
                                            onClicked: root.connectWifi(root.wifiOpen, wifiPass.text)
                                        }
                                    }
                                }
                                Item { Layout.fillHeight: true; visible: !root.hasWifi || root.wifiAsking }
                            }
                        }

                        Page {
                            index: 2
                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                columnSpacing: 16
                                rowSpacing: 8
                                Caption { text: Tr.t("Language") }
                                Caption { text: Tr.t("Keyboard layout") }
                                PickList {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    model: root.locales
                                    delegate: Pick {
                                        required property var modelData
                                        width: ListView.view.width
                                        text: modelData.label
                                        selected: root.locale === modelData.value
                                        onClicked: root.locale = modelData.value
                                    }
                                }
                                PickList {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    model: root.keymaps
                                    delegate: Pick {
                                        required property var modelData
                                        width: ListView.view.width
                                        text: modelData.label
                                        sub: modelData.layout + (modelData.variant ? " · " + modelData.variant : "")
                                        selected: root.keymap === modelData.layout && root.variant === modelData.variant
                                        onClicked: root.setKeymap(modelData)
                                    }
                                }
                                Item { implicitHeight: 1 }
                                Field { Layout.fillWidth: true; Layout.preferredWidth: 1; placeholder: Tr.t("Type here to try the keyboard") }
                            }
                        }

                        Page {
                            index: 3
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.space10
                                RowLayout {
                                    spacing: Theme.space14
                                    Label { text: root.timezone.replace(/_/g, " "); font.pixelSize: Theme.fontSizeTitle; font.weight: Font.DemiBold }
                                    Caption { visible: root.zoneGuessed; text: Tr.t("Detected from your connection") }
                                    Item { Layout.fillWidth: true }
                                }
                                Field { id: zoneSearch; Layout.fillWidth: true; placeholder: Tr.t("Search") }
                                PickList {
                                    id: zonePicker
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: {
                                        const q = zoneSearch.text.toLowerCase().replace(/ /g, "_");
                                        return q ? root.zones.filter(z => z.toLowerCase().indexOf(q) >= 0) : root.zones;
                                    }
                                    delegate: Pick {
                                        required property var modelData
                                        width: ListView.view.width
                                        text: modelData.split("/").pop().replace(/_/g, " ")
                                        sub: modelData.split("/").slice(0, -1).join(" · ").replace(/_/g, " ")
                                        selected: root.timezone === modelData
                                        onClicked: { root.timezone = modelData; root.zoneGuessed = false; }
                                    }
                                    Component.onCompleted: positionLater.start()
                                    Timer { id: positionLater; interval: 300; onTriggered: zonePicker.view.positionViewAtIndex(Math.max(0, root.zones.indexOf(root.timezone)), ListView.Center) }
                                }
                            }
                        }

                        Page {
                            index: 4
                            GridLayout {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, 560)
                                columns: 2
                                columnSpacing: 16
                                rowSpacing: 10
                                Caption { text: Tr.t("Your name") }
                                Field {
                                    Layout.fillWidth: true
                                    text: root.fullName
                                    onTextChanged: { root.fullName = text; if (!root.userEdited) root.user = root.slugOf(text); }
                                }
                                Caption { text: Tr.t("User name") }
                                ColumnLayout {
                                    spacing: Theme.space4
                                    Field {
                                        Layout.fillWidth: true
                                        mono: true
                                        text: root.user
                                        onTextChanged: if (text !== root.user) { root.user = text; root.userEdited = true; }
                                    }
                                    Label { visible: root.user !== "" && !root.userOk; color: Theme.error; font.pixelSize: Theme.fontSizeSmall; text: root.userTaken ? Tr.t("The system has a user by that name") : Tr.t("Lowercase letters, digits, - and _") }
                                }
                                Caption { text: Tr.t("Computer name") }
                                ColumnLayout {
                                    spacing: Theme.space4
                                    Field { Layout.fillWidth: true; mono: true; text: root.host; onTextChanged: root.host = text }
                                    Label { visible: root.host !== "" && !root.hostOk; color: Theme.error; font.pixelSize: Theme.fontSizeSmall; text: Tr.t("Letters, digits and - (not at either end), no spaces") }
                                }
                                Item { implicitHeight: 6; Layout.columnSpan: 2 }
                                Caption { text: Tr.t("Password") }
                                Field { Layout.fillWidth: true; secret: true; canReveal: true; onTextChanged: root.pass = text }
                                Caption { text: Tr.t("Confirm password") }
                                ColumnLayout {
                                    spacing: Theme.space4
                                    Field { Layout.fillWidth: true; secret: true; canReveal: true; onTextChanged: root.pass2 = text }
                                    Label { visible: root.pass2 !== "" && root.pass !== root.pass2; color: Theme.error; font.pixelSize: Theme.fontSizeSmall; text: Tr.t("The passwords don't match") }
                                }
                            }
                        }

                        Page {
                            index: 5
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.space10
                                Caption { text: Tr.t("Install on") }
                                Box {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.min(root.mode === "partition" ? 112 : 170, Math.max(60, root.disks.length * 50 + 12))
                                    ListView {
                                        anchors { fill: parent; margins: Theme.space6 }
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        spacing: Theme.space2
                                        model: root.disks
                                        delegate: Pick {
                                            required property var modelData
                                            width: ListView.view.width
                                            icon: "disk"
                                            text: modelData.model
                                            sub: modelData.path + "  ·  " + root.sizeOf(modelData.size) + (modelData.tran ? "  ·  " + modelData.tran : "") + (modelData.size < root.minBytes ? "  ·  " + "too small" : "")
                                            dim: modelData.size < root.minBytes
                                            selected: root.disk === modelData.path
                                            onClicked: root.disk = modelData.path
                                        }
                                    }
                                    Label { anchors.centerIn: parent; visible: root.disks.length === 0; color: Theme.overlay1; text: Tr.t("No disk found.") }
                                }
                                RowLayout {
                                    visible: root.disk !== ""
                                    spacing: Theme.space14
                                    Caption { text: Tr.t("How") }
                                    Choice {
                                        options: [{ value: "erase", label: Tr.t("Whole disk") }, { value: "free", label: Tr.t("Free space") },
                                                  { value: "partition", label: Tr.t("One partition") }]
                                        current: root.mode
                                        onPicked: v => root.mode = v
                                    }
                                }
                                Label {
                                    visible: root.disk !== "" && root.mode !== "erase" && !partProbe.running && (root.diskTable !== "gpt" || root.diskEsp === "")
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    color: root.diskTable !== "gpt" ? Theme.warning : Theme.subtext0
                                    text: root.diskTable !== "gpt" ? Tr.t("This disk uses the old MBR layout, and Vyntaris can't install next to it. Use the whole disk, or a disk with GPT.") : Tr.t("This disk has no EFI partition, so Vyntaris makes its own. To start the other system, use your computer's boot menu.")
                                }
                                PickList {
                                    visible: root.mode === "partition" && root.diskTable === "gpt"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.min(150, Math.max(60, root.parts.length * 50 + 12))
                                    model: root.parts
                                    delegate: Pick {
                                        required property var modelData
                                        width: ListView.view.width
                                        icon: "folder"
                                        text: root.partName(modelData)
                                        sub: modelData.path + (modelData.fstype ? "  ·  " + modelData.fstype : "") + (modelData.size < root.minRoom ? "  ·  " + "too small" : "")
                                        dim: modelData.size < root.minRoom
                                        selected: root.part === modelData.path
                                        onClicked: root.part = modelData.path
                                    }
                                }
                                Label {
                                    visible: root.disk !== "" && (root.mode === "erase" || root.diskTable === "gpt")
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    color: root.diskRisky ? Theme.warning : Theme.subtext0
                                    text: (root.diskRisky ? "⚠  " : "") + root.diskEffect
                                        + (root.mode !== "erase" && root.diskEsp !== "" && !root.foreignBoot ? "  At start you choose Vyntaris or the other system. If Windows uses BitLocker, keep its recovery key at hand." : "")
                                }
                                RowLayout {
                                    Layout.topMargin: Theme.space6
                                    spacing: Theme.space14
                                    Caption { text: Tr.t("File system") }
                                    Choice {
                                        options: [{ value: "btrfs", label: "Btrfs" }, { value: "ext4", label: "ext4" }]
                                        current: root.fs
                                        onPicked: v => root.fs = v
                                    }
                                    Label { color: Theme.subtext0; text: root.fs === "btrfs" ? Tr.t("Btrfs: instant snapshots, compression") : Tr.t("ext4: the classic") }
                                }
                                Item { Layout.fillHeight: true }
                            }
                        }

                        Page {
                            index: 6
                            GridLayout {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, 600)
                                columns: 2
                                columnSpacing: 24
                                rowSpacing: 12
                                Caption { text: Tr.t("Disk") }
                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: (root.diskInfo ? root.diskInfo.model + "  ·  " + root.sizeOf(root.diskInfo.size) + "  ·  " + root.disk : "")
                                        + "\n" + (root.mode === "erase" ? "The whole disk" : root.mode === "free" ? "Its free space, next to the other system" : "In place of " + (root.partInfo ? root.partName(root.partInfo) : root.part))
                                        + "  ·  " + (root.fs === "btrfs" ? "Btrfs" : "ext4")
                                }
                                Caption { text: Tr.t("User") }
                                Label { text: (root.fullName ? root.fullName + "  ·  " : "") + root.user + "@" + root.host }
                                Caption { text: Tr.t("Language") }
                                Label { text: (root.locales.find(l => l.value === root.locale) ?? { label: root.locale }).label }
                                Caption { text: Tr.t("Keyboard") }
                                Label { text: root.keymap + (root.variant ? " · " + root.variant : "") }
                                Caption { text: Tr.t("Time zone") }
                                Label { text: root.timezone.replace(/_/g, " ") }
                                Item { implicitHeight: 4; Layout.columnSpan: 2 }
                                Label {
                                    Layout.columnSpan: 2
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    color: root.diskRisky ? Theme.warning : Theme.subtext0
                                    text: (root.diskRisky ? "⚠  " : "") + root.diskEffect + (root.mode === "erase" ? "  " + root.disk : "")
                                }
                            }
                        }

                        Page {
                            index: 8
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.space10
                                Label {
                                    visible: root.repairScanning
                                    color: Theme.subtext0
                                    text: Tr.t("Looking for Vyntaris on this computer…")
                                }
                                Label {
                                    visible: !root.repairScanning && root.repairSystems.length === 0
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    color: Theme.warning
                                    text: Tr.t("No installed Vyntaris on this computer's disks.")
                                }
                                Caption { visible: root.repairSystems.length > 0; text: Tr.t("The system") }
                                Box {
                                    visible: root.repairSystems.length > 0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.min(112, root.repairSystems.length * 50 + 12)
                                    ListView {
                                        anchors { fill: parent; margins: Theme.space6 }
                                        clip: true
                                        interactive: false
                                        spacing: Theme.space2
                                        model: root.repairSystems
                                        delegate: Pick {
                                            required property var modelData
                                            width: ListView.view.width
                                            icon: "vyntaris"
                                            text: modelData.name + (modelData.host ? "  ·  " + modelData.host : "")
                                            sub: modelData.dev + "  ·  " + modelData.fs + "  ·  " + modelData.snaps + (modelData.snaps === 1 ? " snapshot" : " snapshots")
                                            selected: root.repairSystem === modelData.dev
                                            onClicked: root.repairSystem = modelData.dev
                                        }
                                    }
                                }
                                Caption { visible: root.repairSystem !== "" && root.repairResult === -1; text: Tr.t("What to do") }
                                GridLayout {
                                    visible: root.repairSystem !== "" && root.repairResult === -1
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 6
                                    rowSpacing: 4
                                    Repeater {
                                        model: root.repairActions
                                        Pick {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            icon: modelData.icon
                                            text: modelData.label
                                            sub: modelData.sub
                                            dim: modelData.id === "restore" && root.repairSnapshots.length === 0
                                            selected: root.repairAction === modelData.id
                                            onClicked: root.repairAction = modelData.id
                                        }
                                    }
                                }
                                PickList {
                                    visible: root.repairAction === "restore" && root.repairResult === -1
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: root.repairSnapshots
                                    delegate: Pick {
                                        required property var modelData
                                        width: ListView.view.width
                                        icon: "timer"
                                        text: modelData.when
                                        sub: modelData.comment || modelData.name
                                        selected: root.repairSnapshot === modelData.name
                                        onClicked: root.repairSnapshot = modelData.name
                                    }
                                }
                                Label {
                                    visible: root.repairAction === "restore" && root.repairResult === -1
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    color: Theme.subtext0
                                    font.pixelSize: Theme.fontSizeSmall
                                    text: Tr.t("The system as it is now is kept aside, not deleted; your files in /home stay as they are.")
                                }
                                Label {
                                    visible: root.repairResult >= 0
                                    font.weight: Font.DemiBold
                                    color: root.repairResult === 0 ? Theme.success : Theme.error
                                    text: root.repairResult === 0 ? Tr.t("Repaired. Restart and take out the USB stick.") : Tr.t("That didn't work; what happened is below.")
                                }
                                Box {
                                    visible: root.repairResult !== -1
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    ListView {
                                        anchors { fill: parent; leftMargin: Theme.space12; rightMargin: Theme.space20; topMargin: Theme.space10; bottomMargin: Theme.space10 }
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        spacing: Theme.space2
                                        model: repairLog
                                        onCountChanged: positionViewAtEnd()
                                        delegate: Label {
                                            required property string line
                                            width: ListView.view.width
                                            wrapMode: Text.WrapAnywhere
                                            mono: true
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: line.startsWith("::") ? Theme.accentInk : /^error/i.test(line) ? Theme.error : Theme.subtext0
                                            font.weight: line.startsWith("::") ? Font.DemiBold : Font.Normal
                                            text: line
                                        }
                                    }
                                }
                                Item { Layout.fillHeight: true; visible: root.repairAction !== "restore" && root.repairResult === -1 }
                            }
                        }

                        Page {
                            index: 7
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.space14
                                property bool details: false
                                id: inst
                                Item { Layout.fillHeight: true; visible: !inst.details }
                                Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    font.pixelSize: Theme.fontSizeHeading
                                    font.weight: Font.Bold
                                    text: root.result === 0 ? Tr.t("Vyntaris is installed") : root.result > 0 ? Tr.t("The installation failed") : Tr.t("Installing Vyntaris")
                                    color: root.result > 0 ? Theme.error : Theme.text
                                }
                                Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    color: Theme.subtext0
                                    text: root.result === 0 ? Tr.t("Remove the USB stick, then restart.") : root.result > 0 ? Tr.t("The details below say why. Fix it in a terminal (fix-keyring for key errors), then try again.") : Tr.t("This takes a while. The computer can stay alone.")
                                }
                                Row {
                                    id: segs
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: Theme.space10
                                    readonly property int count: 32
                                    spacing: Theme.space4
                                    property real pulse: 0
                                    SequentialAnimation on pulse {
                                        running: root.result < 0 && root.page === 7
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0; to: 1; duration: 700; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0; duration: 700; easing.type: Easing.InOutSine }
                                    }
                                    Repeater {
                                        model: segs.count
                                        Rectangle {
                                            required property int index
                                            readonly property real lit: root.progress * segs.count - index
                                            width: Math.min(14, (pagesArea.width - 40) / segs.count - 4)
                                            height: 22
                                            radius: 4
                                            color: root.result > 0 && lit > 0 ? Theme.error
                                                 : lit >= 1 ? Theme.accent
                                                 : lit > 0 ? Theme.alpha(Theme.accent, 0.35 + 0.5 * segs.pulse)
                                                 : Theme.alpha(Theme.text, 0.08)
                                            scale: lit > 0 && lit < 1 ? 1 + 0.12 * segs.pulse : 1
                                            Behavior on color { ColorAnim {} }
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: Theme.space10
                                    Caption { text: root.stepName }
                                    Caption { color: Theme.accentInk; text: Math.round(root.progress * 100) + "%" }
                                }
                                Label {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideMiddle
                                    mono: true
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.overlay1
                                    visible: !inst.details
                                    text: root.liveLine.trim()
                                }
                                Box {
                                    id: logBox
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: inst.details
                                    ListView {
                                        id: logView
                                        anchors { fill: parent; leftMargin: Theme.space12; rightMargin: Theme.space20; topMargin: Theme.space10; bottomMargin: Theme.space10 }
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        model: log
                                        spacing: Theme.space2
                                        property bool follow: true
                                        property bool pinning: false
                                        function pin() { pinning = true; positionViewAtEnd(); pinning = false; }
                                        onContentYChanged: if (!pinning) follow = atYEnd
                                        onCountChanged: if (follow) pin()
                                        onHeightChanged: if (follow) pin()
                                        onVisibleChanged: if (visible) { follow = true; pin(); }
                                        delegate: Label {
                                            required property string line
                                            width: ListView.view.width
                                            mono: true
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: line.startsWith("::") ? Theme.accentInk : /error|fail/i.test(line) ? Theme.error : Theme.subtext0
                                            font.weight: line.startsWith("::") ? Font.DemiBold : Font.Normal
                                            wrapMode: Text.WrapAnywhere
                                            text: line
                                        }
                                    }
                                    Rectangle {
                                        x: parent.width - 10
                                        y: 10 + logView.visibleArea.yPosition * (parent.height - 20)
                                        width: 4
                                        height: Math.max(28, logView.visibleArea.heightRatio * (parent.height - 20))
                                        radius: 2
                                        visible: logView.visibleArea.heightRatio < 1
                                        color: Theme.alpha(Theme.accent, barDrag.pressed || logView.moving ? 0.85 : 0.45)
                                        Behavior on color { ColorAnim {} }
                                        MouseArea {
                                            id: barDrag
                                            anchors { fill: parent; margins: -6 }
                                            cursorShape: Qt.PointingHandCursor
                                            property real from: 0
                                            property real start: 0
                                            onPressed: mouse => { from = mapToItem(logBox, mouse.x, mouse.y).y; start = logView.contentY; }
                                            onPositionChanged: mouse => {
                                                const dy = mapToItem(logBox, mouse.x, mouse.y).y - from;
                                                const range = logView.contentHeight - logView.height;
                                                logView.contentY = Math.max(logView.originY, Math.min(logView.originY + range,
                                                    start + dy / Math.max(1, logBox.height - 20 - height) * range));
                                            }
                                        }
                                    }
                                    Rectangle {
                                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.space12 }
                                        visible: !logView.follow
                                        width: latest.implicitWidth + 28
                                        height: 30
                                        radius: 15
                                        color: Theme.accent
                                        Label { id: latest; anchors.centerIn: parent; overline: true; color: Theme.textOnAccent; font.weight: Font.DemiBold; text: Tr.t("↓  Latest") }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { logView.follow = true; logView.pin(); } }
                                    }
                                }
                                Item { Layout.fillHeight: true; visible: !inst.details }
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: Theme.space10
                                    Button {
                                        text: inst.details ? Tr.t("Hide details") : Tr.t("Show details")
                                        onClicked: inst.details = !inst.details
                                    }
                                    Button {
                                        visible: root.result > 0
                                        text: Tr.t("Open terminal")
                                        onClicked: root.openTerminal()
                                    }
                                }
                                Connections { target: root; function onResultChanged() { if (root.result > 0) inst.details = true; } }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space10
                        Label {
                            visible: root.page === 0
                            color: Theme.overlay1
                            font.underline: textArea.containsMouse
                            text: Tr.t("Use the text installer")
                            MouseArea { id: textArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: textMode.running = true }
                        }
                        Label {
                            visible: root.page === 0
                            color: Theme.overlay1
                            font.underline: repairArea.containsMouse
                            text: Tr.t("Repair an installed Vyntaris")
                            MouseArea { id: repairArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openRepair() }
                        }
                        Button {
                            visible: root.page === 8 && root.repairResult !== -2
                            text: Tr.t("Back")
                            onClicked: root.page = 0
                        }
                        Button {
                            icon: "terminal"
                            onClicked: root.openTerminal()
                        }
                        Button {
                            visible: root.page > 0 && root.page < 7
                            text: Tr.t("Back")
                            onClicked: root.page--
                        }
                        Item { Layout.fillWidth: true }
                        Button {
                            visible: root.page < 6
                            primary: true
                            active: root.canLeave(root.page)
                            text: Tr.t("Next")
                            onClicked: root.page++
                        }
                        Button {
                            visible: root.page === 6
                            primary: true
                            danger: true
                            text: (root.mode === "free" ? Tr.t("Install") : Tr.t("Erase and install"))
                            onClicked: root.install()
                        }
                        Button {
                            visible: root.page === 8 && root.repairResult !== -2 && root.repairResult !== 0
                            primary: true
                            active: root.repairReady || root.repairAction === "shell"
                            text: root.repairAction === "shell" ? Tr.t("Open the terminal") : root.repairResult > 0 ? Tr.t("Try again") : Tr.t("Repair")
                            onClicked: root.repair()
                        }
                        Button {
                            visible: root.page === 8 && root.repairResult === 0
                            primary: true
                            text: Tr.t("Restart")
                            onClicked: Quickshell.execDetached(root.preview ? ["true"] : ["systemctl", "reboot"])
                        }
                        Button {
                            visible: root.page === 7 && root.result > 0
                            text: Tr.t("Try again")
                            onClicked: { root.result = -1; root.page = 6; }
                        }
                        Button {
                            visible: root.page === 7 && root.result === 0
                            primary: true
                            text: Tr.t("Restart")
                            onClicked: Quickshell.execDetached(root.preview ? ["true"] : ["systemctl", "reboot"])
                        }
                    }
                }
            }
        }
    }

    function openTerminal() {
        Quickshell.execDetached(root.preview ? ["kitty", "zsh"] : ["kitty", "installer-shell"]);
    }

    Process {
        id: textMode
        command: root.preview
            ? ["kitty", "--class", "installer-text", "sh", "-c", "echo 'Preview: the text installer runs here.'; echo; printf 'Enter goes back… '; read -r _"]
            : ["kitty", "--class", "installer-text", "installer-shell", "--text"]
    }

    IpcHandler {
        target: "installer"
        function quit(): void { if (root.result !== -1 || root.page !== 7) Qt.quit(); }
        function go(p: int): void { if (root.page !== 7 || root.result !== -1) root.page = Math.max(0, Math.min(6, p)); }
    }
}
