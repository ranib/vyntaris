pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.config
import "Terminal.js" as Terminal

Singleton {
    id: root

    property var packages: []
    readonly property int count: packages.length
    readonly property int total: count + firmware.length
    readonly property var desktop: packages.find(p => p.name === "vyntaris") ?? null
    property var tested: ({})
    readonly property var held: packages.filter(p => !p.aur && tested[p.name] && !tested[p.name].includes(p.to))
    property bool checking: false
    property bool failed: false
    property string aurHelper: ""
    property var firmware: []

    function check() {
        if (repo.running || aur.running) { again = true; return; }
        checking = true;
        repo.running = true;
    }
    property bool again: false
    function checkFirmware() {
        if (!fw.running) fw.running = true;
    }

    property bool upgrading: false
    property string lastResult: ""
    readonly property string upgradeState: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vyntaris-upgrade"
    function upgrade() {
        if (upgrading) return;
        upgrading = true;
        lastResult = "";
        output = [];
        Quickshell.execDetached(["systemd-run", "--user", "--quiet", "--collect", "--unit=vyntaris-upgrade",
            "--description=Updating the system", "--", Quickshell.shellPath("scripts/upgrade.sh"), aurHelper]);
        upgradeWatch.restart();
    }
    function upgradeInTerminal() {
        const cmd = aurHelper ? `${aurHelper} -Syu` : "sudo pacman -Syu";
        Config.runInTerminal(`${cmd}; ${Config.enterToClose(true)}`);
        lastResult = "";
        recheck.restart();
    }
    property var output: []
    Timer {
        interval: 500
        repeat: true
        triggeredOnStart: true
        running: root.upgrading
        onTriggered: if (!outputRead.running) outputRead.running = true
    }
    Process {
        id: outputRead
        command: ["sh", "-c", 'f="$1/log"; [ "$(stat -c %s "$f" 2>/dev/null || echo 0)" -gt 16384 ] && echo cut; tail -c 16384 "$f" 2>/dev/null; true',
            "sh", root.upgradeState]
        stdout: StdioCollector {
            onStreamFinished: root.output = Terminal.screen(text.startsWith("cut\n") ? text.slice(4).replace(/^[^\r\n\x1b]*/, "") : text, 8)
        }
    }
    Timer { id: upgradeWatch; interval: 2000; repeat: true; onTriggered: if (!upgradeCheck.running) upgradeCheck.running = true }
    Process {
        id: upgradeCheck
        running: true
        command: ["sh", "-c", 'systemctl --user is-active --quiet vyntaris-upgrade && echo running; cat "$1/result" 2>/dev/null; true',
            "sh", root.upgradeState]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines[0] === "running") {
                    root.upgrading = true;
                    if (!upgradeWatch.running) upgradeWatch.start();
                    return;
                }
                if (!root.upgrading) return;
                upgradeWatch.stop();
                root.upgrading = false;
                root.lastResult = lines[0] || "failed";
                root.check();
                root.checkFirmware();
            }
        }
    }

    function upgradeFirmware() {
        Config.runInTerminal('fwupdmgr update; ' + Config.enterToClose(true));
        recheck.restart();
    }

    function parsePackages(text, aur) {
        return text.trim().split("\n").filter(l => l).map(l => {
            const m = l.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/);
            return m ? { name: m[1], from: m[2], to: m[3], aur } : { name: l, from: "", to: "", aur };
        });
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v yay || command -v paru"]
        stdout: StdioCollector { onStreamFinished: root.aurHelper = text.trim().split("/").pop() }
    }

    Process {
        id: repo
        command: ["sh", "-c", "if command -v checkupdates >/dev/null; then checkupdates 2>/dev/null; echo \"::$?\"; else echo ::2; fi; "
            + "curl -fsS --max-time 10 https://pkg.vyntarisos.com/tested 2>/dev/null | sed 's/^/@@ /'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const status = /^::\d+$/;
                const code = (lines.find(l => status.test(l)) ?? "::2").slice(2);
                const tested = {};
                for (const l of lines.filter(l => l.startsWith("@@ "))) {
                    const [name, version] = l.slice(3).trim().split(/\s+/);
                    if (version) (tested[name] = tested[name] ?? []).push(version);
                }
                root.tested = tested;
                root.failed = code !== "0" && code !== "2";
                root.repoList = root.parsePackages(lines.filter(l => !l.startsWith("@@ ") && !status.test(l)).join("\n"), false);
                if (root.aurHelper) aur.running = true;
                else root.finish([]);
            }
        }
    }
    property var repoList: []
    Process {
        id: aur
        command: ["sh", "-c", `${root.aurHelper} -Qua 2>/dev/null; true`]
        stdout: StdioCollector { onStreamFinished: root.finish(root.parsePackages(text, true)) }
    }
    function finish(aurList) {
        packages = repoList.concat(aurList);
        checking = false;
        if (again) { again = false; check(); }
    }

    FileView {
        path: "/var/log/pacman.log"
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: settled.restart()
    }
    Timer { id: settled; interval: 3000; onTriggered: root.check() }
    Process {
        id: fw
        command: ["sh", "-c", "command -v fwupdmgr >/dev/null || exit 0; fwupdmgr get-updates --json 2>/dev/null; "
            + "pgrep -f 'fwupdmgr (update|install)' >/dev/null || fwupdmgr quit >/dev/null 2>&1; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.firmware = (JSON.parse(text).Devices ?? []).filter(d => (d.Releases ?? []).length > 0)
                        .map(d => ({ name: d.Name, from: d.Version ?? "", to: d.Releases[0].Version ?? "" }));
                } catch (e) { root.firmware = []; }
            }
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.check()
    }
    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        onTriggered: { interval = 24 * 60 * 60 * 1000; root.checkFirmware(); }
    }
    Timer {
        id: recheck
        interval: 120000
        repeat: true
        property int left: 5
        onTriggered: { root.check(); root.checkFirmware(); if (--left <= 0) { stop(); left = 5; } }
    }
}
