pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    property bool locked: false
    property bool preview: false
    signal woke()
    Timer { running: root.preview; interval: 15000; onTriggered: root.preview = false }
    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/shell-locked"

    function lock() {
        if (locked) return;
        Quickshell.execDetached(["touch", marker]);
        locked = true;
    }
    function unlocked() {
        Quickshell.execDetached(["rm", "-f", marker]);
        locked = false;
    }

    Process {
        running: true
        command: ["test", "-e", root.marker]
        onExited: code => { if (code === 0) root.locked = true; }
    }
}
