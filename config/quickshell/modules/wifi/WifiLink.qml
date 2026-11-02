import Quickshell.Io
import QtQuick

Item {
    id: root
    property string device: ""
    property bool active: false
    property bool wired: false

    property real down: -1
    property real up: -1
    property real ping: -1
    property string rate: ""
    property string band: ""
    property string address: ""
    property var last: null
    property bool ready: false

    function speed(bytes) {
        if (bytes < 0) return "–";
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB/s";
        if (bytes >= 1024) return Math.round(bytes / 1024) + " KB/s";
        return Math.round(bytes) + " B/s";
    }

    function parse(text) {
        ready = true;
        const field = key => (text.split("\n").find(l => l.startsWith(key + "=")) ?? "").slice(key.length + 1).trim();
        const [rx, tx, at] = field("n").split(" ").map(Number);
        if (last && at > last.at) {
            const seconds = (at - last.at) / 1000;
            down = Math.max(0, rx - last.rx) / seconds;
            up = Math.max(0, tx - last.tx) / seconds;
        }
        if (at > 0) last = { rx, tx, at };
        const [freq, bitrate] = field("l").split(":");
        const mhz = parseInt(freq);
        band = !(mhz > 0) ? "" : mhz >= 5925 ? "6 GHz" : mhz >= 5000 ? "5 GHz" : "2.4 GHz";
        rate = (bitrate ?? "").replace("Mbit/s", "Mb/s");
        address = field("a").split("|")[0].split("/")[0].trim();
        const ms = parseFloat(field("p"));
        ping = ms >= 0 ? ms : -1;
    }

    onActiveChanged: if (!active) { last = null; ready = false; down = -1; up = -1; ping = -1; }

    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.active && root.device !== ""
        onTriggered: if (!read.running) read.running = true
    }

    Process {
        id: read
        command: ["sh", "-c",
            'read r < "/sys/class/net/$1/statistics/rx_bytes"; read t < "/sys/class/net/$1/statistics/tx_bytes"; '
            + 'echo "n=$r $t $(date +%s%3N)"; '
            + 'if [ "$2" = wired ]; then read s < "/sys/class/net/$1/speed" 2>/dev/null; [ "${s:-0}" -gt 0 ] 2>/dev/null && echo "l=:$s Mb/s"; '
            + 'else echo "l=$(nmcli -g IN-USE,FREQ,RATE dev wifi list ifname "$1" --rescan no 2>/dev/null | sed -n "s/^\\*://p" | head -n1)"; fi; '
            + 'echo "a=$(nmcli -g IP4.ADDRESS dev show "$1" 2>/dev/null)"; '
            + 'echo "p=$(ping -n -c1 -W1 1.1.1.1 2>/dev/null | sed -n "s/.*time=\\([0-9.]*\\).*/\\1/p")"',
            "sh", root.device, root.wired ? "wired" : "wifi"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
}
