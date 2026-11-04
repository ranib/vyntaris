pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import qs.config

Singleton {
    id: root

    readonly property bool enabled: Config.bar.privacy

    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream)
    PwObjectTracker { objects: root.enabled ? root.streams : [] }

    function prop(n, key) { return n?.properties?.[key] ?? ""; }
    // Who it is, by the program behind the stream: what a stream calls itself is often its library's name (Discord's
    // microphone is "WEBRTC VoiceEngine", Chromium's "Chromium input"), so the app's own name comes first.
    function appName(n) {
        const bin = prop(n, "application.process.binary");
        const entry = bin ? DesktopEntries.heuristicLookup(bin) : null;
        if (entry?.name) return entry.name;
        const own = prop(n, "application.name") || prop(n, "node.description") || prop(n, "node.name") || n?.description || "";
        return bin && (!own || /voiceengine|^chromium|^alsa plug-in|^pipewire|^libcanberra/i.test(own)) ? bin.charAt(0).toUpperCase() + bin.slice(1) : own;
    }

    readonly property var micUsers: {
        if (!enabled) return [];
        const out = [];
        for (const n of streams) {
            if (prop(n, "media.class") !== "Stream/Input/Audio") continue;
            if (prop(n, "stream.capture.sink") === "true" || prop(n, "stream.monitor") === "true") continue;
            if (prop(n, "target.object").endsWith(".monitor")) continue;
            if (prop(n, "node.passive") === "true" || prop(n, "node.name") === "capture.vyntaris_noise") continue;
            const name = appName(n);
            if (/^(cava|quickshell|pavucontrol|pulseaudio volume control)$/i.test(name)) continue;
            if (!out.some(u => u.app === name)) out.push({ app: name, pid: Number(prop(n, "application.process.id")) || 0, client: Number(prop(n, "client.id")) || 0 });
        }
        return out;
    }
    readonly property var micApps: micUsers.map(u => u.app)

    readonly property var screenNodes: Pipewire.nodes.values.filter(n =>
        prop(n, "media.class") === "Video/Source" && /^(xdph|xdpw)/.test(prop(n, "node.name")))

    function consumers(sources) {
        return consumerUsers(sources).map(u => u.app);
    }
    function consumerUsers(sources) {
        const out = [];
        for (const g of Pipewire.linkGroups.values) {
            if (!sources.includes(g.source)) continue;
            const name = appName(g.target);
            if (name && !out.some(u => u.app === name)) out.push({ app: name, pid: Number(prop(g.target, "application.process.id")) || 0, client: Number(prop(g.target, "client.id")) || 0 });
        }
        return out;
    }

    readonly property var screenApps: {
        if (!enabled || screenNodes.length === 0) return [];
        const apps = consumers(screenNodes);
        return apps.length > 0 ? apps : [Tr.t("An app")];
    }

    readonly property var cameraNodes: Pipewire.nodes.values.filter(n =>
        prop(n, "media.class") === "Video/Source" && !screenNodes.includes(n))

    property var deviceUsers: []
    property var deviceProcs: []
    readonly property var cameraApps: {
        if (!enabled) return [];
        const out = consumers(cameraNodes);
        for (const name of deviceUsers)
            if (!out.includes(name)) out.push(name);
        return out;
    }

    readonly property bool mic: micApps.length > 0
    readonly property bool camera: cameraApps.length > 0
    readonly property bool screen: screenApps.length > 0
    readonly property bool active: mic || camera || screen

    readonly property var entries: {
        const out = [];
        if (!enabled) return out;
        const cams = consumerUsers(cameraNodes);
        for (const d of deviceProcs) if (!cams.some(u => u.app === d.app)) cams.push(d);
        for (const u of cams) out.push({ kind: "camera", app: u.app, pid: u.pid, client: u.client ?? 0 });
        const scr = consumerUsers(screenNodes);
        if (screenNodes.length > 0 && scr.length === 0) scr.push({ app: Tr.t("An app"), pid: 0, client: 0 });
        for (const u of scr) out.push({ kind: "screen", app: u.app, pid: u.pid, client: u.client });
        for (const u of micUsers) out.push({ kind: "mic", app: u.app, pid: u.pid, client: u.client });
        return out;
    }
    function canClose(e) { return e.pid > 1 || e.client > 0; }
    function close(e) {
        Quickshell.execDetached(["sh", "-c",
            'pid=$2; if [ "$1" -gt 0 ]; then p=$(pw-cli info "$1" 2>/dev/null | sed -n \'s/.*pipewire.sec.pid = "\\([0-9]*\\)".*/\\1/p\' | head -1); [ -n "$p" ] && pid=$p; fi; '
            + '[ "$pid" -gt 1 ] || exit; case "$(cat /proc/$pid/comm 2>/dev/null)" in pipewire*|wireplumber|quickshell|qs|xdg-desktop-portal*) exit ;; esac; kill -TERM "$pid"',
            "sh", String(e.client ?? 0), String(e.pid ?? 0)]);
    }

    Connections {
        target: Hardware
        function onCameraChanged() { if (!Hardware.camera) { root.deviceUsers = []; root.deviceProcs = []; } }
    }
    Process {
        id: devices
        command: ["sh", "-c", 'for d in /dev/video*; do [ -e "$d" ] && fuser "$d" 2>/dev/null; done | tr -s " " "\\n" | sed "/^$/d" | sort -u | while read -r p; do printf "%s %s\\n" "$p" "$(cat "/proc/$p/comm" 2>/dev/null)"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const procs = text.split("\n").map(s => s.trim()).filter(s => s).map(s => ({ pid: Number(s.split(" ")[0]), app: s.slice(s.indexOf(" ") + 1) }))
                    .filter(p => p.app && !/^(pipewire|wireplumber|quickshell|qs)$/.test(p.app))
                    .filter((p, i, a) => a.findIndex(q => q.app === p.app) === i);
                root.deviceProcs = procs;
                root.deviceUsers = procs.map(p => p.app);
            }
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.enabled && Hardware.camera
        triggeredOnStart: true
        onTriggered: if (!devices.running) devices.running = true
    }
}
