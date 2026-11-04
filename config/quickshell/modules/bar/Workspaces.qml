import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    required property var window

    // The workspaces to show, rebuilt whenever they change. After a restart Hyprland's workspaces come by name first,
    // their ids (-1) only with a refresh, and the one asked for as the bar started went before the connection was up:
    // the bar showed none until the next workspace event. A workspace's number is its id, or its name until that
    // comes, and while one is missing the bar asks again.
    property var list: []
    function numberOf(w) { return w.id > 0 ? w.id : /^\d+$/.test(w.name ?? "") ? parseInt(w.name) : -1; }
    function rebuild() {
        const all = Hyprland.workspaces.values;
        if (all.some(w => w.id <= 0 && /^\d+$/.test(w.name ?? "")) && !asked.running) { Hyprland.refreshWorkspaces(); asked.start(); }
        list = all.filter(w => numberOf(w) > 0).sort((a, b) => numberOf(a) - numberOf(b));
        const ids = list.map(w => numberOf(w));
        // Only what changed moves. One that's gone is marked leaving and shrinks away by itself (drop() takes it out
        // after); one that's new goes in where its number belongs, and grows in.
        for (let i = 0; i < shown.count; i++) {
            const e = shown.get(i);
            if (!ids.includes(e.wid) && !e.leaving) shown.setProperty(i, "leaving", true);
            else if (ids.includes(e.wid) && e.leaving) shown.setProperty(i, "leaving", false);
        }
        for (const id of ids) {
            let at = 0, have = false;
            for (let i = 0; i < shown.count; i++) {
                const w = shown.get(i).wid;
                if (w === id) { have = true; break; }
                if (w < id) at = i + 1;
            }
            if (!have) shown.insert(at, { wid: id, leaving: false });
        }
    }
    function drop(wid) {
        for (let i = 0; i < shown.count; i++) if (shown.get(i).wid === wid && shown.get(i).leaving) { shown.remove(i); return; }
    }
    ListModel { id: shown }
    Timer { id: asked; interval: 1000 }
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.rebuild(); }
        function onObjectInsertedPost() { root.rebuild(); }
        function onObjectRemovedPost() { root.rebuild(); }
    }
    Component.onCompleted: rebuild()
    Timer { interval: 400; running: true; repeat: true; property int left: 8; onTriggered: { root.rebuild(); if (--left <= 0) stop(); } }
    readonly property int focusedNumber: Hyprland.focusedWorkspace ? numberOf(Hyprland.focusedWorkspace) : -1

    readonly property var scratchpad: Hyprland.workspaces.values.find(w => w.name === "special:magic") ?? null
    readonly property bool scratchpadShown:
        (Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name ?? "") === "special:magic"

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (/^activespecial/.test(event.name)) Hyprland.refreshMonitors();
            if (/^(createworkspace|destroyworkspace|moveworkspace|renameworkspace|workspace)/.test(event.name)) Qt.callLater(root.rebuild);
        }
    }

    function icons(ws) {
        const seen = [];
        for (const t of ws.toplevels.values) {
            const id = t.wayland?.appId ?? t.lastIpcObject?.class ?? "";
            if (!id) continue;
            const entry = DesktopEntries.heuristicLookup(id);
            const path = Quickshell.iconPath(entry?.icon ?? id, true);
            if (path && !seen.includes(path)) seen.push(path);
        }
        return seen.slice(0, 3);
    }

    // Follows the numbers as they grow and shrink themselves; an animation of its own would restart every frame.
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight - 8

    // The highlight goes where the focused number will be once the numbers settle (each at its full width, the ones
    // leaving not counted), and slides there once: following them as they grow and shrink made it run off.
    readonly property var rest: {
        void shown.count;
        let x = 0, at = -1, w = 0;
        for (let i = 0; i < numbers.count; i++) {
            const it = numbers.itemAt(i);
            if (!it || it.leaving) continue;
            if (it.wid === focusedNumber) { at = x; w = it.full; }
            x += it.full;
        }
        return { x: at, width: w };
    }
    Rectangle {
        visible: root.rest.x >= 0
        x: Math.max(0, root.rest.x)
        width: root.rest.width
        height: parent.height
        radius: Theme.r(height / 2)
        color: Theme.accent
        Behavior on x { Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring } }
        Behavior on width { Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring } }
    }

    Row {
        id: row
        height: parent.height

        // Each number takes the room it has (`span` of its full width), so the row is right every frame: one coming in
        // grows into place, one leaving shrinks and fades out of it, and the rest move over with them.
        Repeater {
            id: numbers
            model: shown

            Item {
                id: ws
                required property int wid
                required property bool leaving
                readonly property var modelData: root.list.find(w => root.numberOf(w) === wid) ?? ({ id: wid, toplevels: { values: [] } })
                readonly property bool focused: !leaving && root.focusedNumber === wid
                readonly property var appIcons: Config.bar.workspaceIcons ? root.icons(modelData) : []
                readonly property real full: Math.max(24, content.implicitWidth + 14)

                property real span: 0
                Component.onCompleted: span = 1
                onLeavingChanged: span = leaving ? 0 : 1
                Behavior on span { Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curvePanelIn } }
                onSpanChanged: if (leaving && span <= 0) root.drop(wid)

                width: full * span
                height: row.height
                opacity: span
                clip: span < 1

                RowLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: Theme.space4

                    Label {
                        mono: true
                        text: ws.wid
                        font.pixelSize: Theme.fontSizeLabel
                        font.weight: ws.focused ? Font.Bold : Font.Medium
                        color: ws.focused ? Theme.textOnAccent : Theme.subtext1
                    }
                    Repeater {
                        model: ws.appIcons
                        AppIcon {
                            required property string modelData
                            implicitSize: 13
                            source: modelData
                            themed: Config.bar.workspaceIconsAccent
                            opacity: ws.focused ? 1 : 0.7
                        }
                    }
                }

                MouseArea {
                    id: wsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusWorkspace(ws.wid)
                }
            }
        }

        Item {
            visible: root.scratchpad !== null
            width: 22
            height: row.height

            Rectangle {
                anchors.centerIn: parent
                width: root.scratchpadShown ? 10 : 6
                height: width
                radius: width / 2
                color: root.scratchpadShown ? Theme.accent : Theme.overlay1
                Behavior on width { Anim { easing.bezierCurve: Theme.curveSpring } }
                Behavior on color { ColorAnim {} }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Compositor.toggleSpecial("magic")
            }
        }
    }

    WheelHandler {
        onWheel: event => Compositor.cycleWorkspace(event.angleDelta.y > 0 ? -1 : 1)
    }

}
