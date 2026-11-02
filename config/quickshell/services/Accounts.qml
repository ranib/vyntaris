pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    readonly property string tool: Quickshell.env("VYNTARIS_SETTINGS_ADMIN") || "/usr/lib/vyntaris/settings-admin"
    readonly property string me: Quickshell.env("USER")
    readonly property string face: Quickshell.env("HOME") + "/.face"

    property var users: []
    readonly property var self: users.find(u => u.name === me) ?? ({ name: me, full: me, admin: false })
    readonly property var others: users.filter(u => u.name !== me)
    property bool busy: false
    property string failure: ""
    property int faceVersion: 0
    property bool hasFace: false

    function refresh() { list.running = true; faceCheck.running = true; }
    Process {
        id: list
        command: ["sh", "-c", 'getent group wheel | cut -d: -f4; getent passwd | awk -F: \'$3 >= 1000 && $3 < 60000 && $7 !~ /nologin|false/ {print $1 ":" $5}\'']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const admins = (lines[0] ?? "").split(",");
                root.users = lines.slice(1).filter(l => l.includes(":")).map(l => {
                    const i = l.indexOf(":");
                    const name = l.slice(0, i), full = l.slice(i + 1).split(",")[0];
                    return { name, full: full || name, admin: admins.includes(name) };
                }).sort((a, b) => (b.name === root.me) - (a.name === root.me) || a.name.localeCompare(b.name));
            }
        }
    }

    function run(args, input) {
        if (busy) return;
        busy = true;
        failure = "";
        job.input = input ?? "";
        job.command = ["pkexec", tool].concat(args);
        job.running = true;
    }
    Process {
        id: job
        property string input: ""
        stdinEnabled: true
        onStarted: { write(input + "\n"); stdinEnabled = false; }
        stderr: StdioCollector { id: jobErr }
        onExited: code => {
            root.busy = false;
            job.stdinEnabled = true;
            if (code !== 0 && code !== 126 && code !== 127)
                root.failure = jobErr.text.trim().split("\n").pop() || Tr.t("That couldn't be changed. Try again, or check that you're an administrator.");
            root.refresh();
        }
    }

    function add(name, full, admin, password) { run(["user-add", name, full, admin ? "admin" : "standard"], password); }
    function remove(name) { run(["user-remove", name]); }
    function setAdmin(name, on) { run(["user-admin", name, on ? "on" : "off"]); }
    function setPassword(name, password) { run(["user-password", name], password); }
    readonly property string changer: Quickshell.env("VYNTARIS_CHANGE_PASSWORD") || "/usr/lib/vyntaris/change-password"
    function setOwnPassword(current, password) {
        if (busy) return;
        busy = true;
        failure = "";
        own.input = current + "\n" + password;
        own.running = true;
    }
    Process {
        id: own
        property string input: ""
        command: [root.changer]
        stdinEnabled: true
        onStarted: { write(input + "\n"); input = ""; stdinEnabled = false; }
        stderr: StdioCollector { id: ownErr }
        onExited: code => {
            root.busy = false;
            own.stdinEnabled = true;
            if (code !== 0)
                root.failure = Tr.t("The password wasn't changed: the current one isn't right, or the new one is refused.");
        }
    }
    function setName(name, full) { run(["user-name", name, full]); }

    function nameFor(full) {
        const n = full.trim().split(/\s+/)[0]?.toLowerCase().normalize("NFD").replace(/[^a-z0-9_-]/g, "") ?? "";
        return /^[a-z_]/.test(n) ? n.slice(0, 32) : "";
    }

    function setFace(path) {
        faceSet.command = ["cp", "-f", path, face];
        faceSet.running = true;
    }
    function clearFace() {
        faceSet.command = ["rm", "-f", face];
        faceSet.running = true;
    }
    Process { id: faceSet; onExited: { root.faceVersion++; faceCheck.running = true; } }
    Process { id: faceCheck; command: ["test", "-s", root.face]; onExited: code => root.hasFace = code === 0 }
    property var pictures: []
    function findPictures() { pics.running = true; }
    Process {
        id: pics
        command: ["sh", "-c", 'd="$(xdg-user-dir PICTURES)"; find "$d" -maxdepth 2 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) -printf "%T@ %p\\n" 2>/dev/null | sort -rn | head -n 12 | cut -d" " -f2-']
        stdout: StdioCollector { onStreamFinished: root.pictures = text.split("\n").filter(l => l) }
    }

    Component.onCompleted: refresh()
}
