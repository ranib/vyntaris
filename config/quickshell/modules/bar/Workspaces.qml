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
        // Only what changed moves: a new number comes in, an emptied one goes, the rest stay where they are.
        for (let i = shown.count - 1; i >= 0; i--)
            if (!ids.includes(shown.get(i).wid)) shown.remove(i);
        ids.forEach((id, i) => {
            if (i < shown.count && shown.get(i).wid === id) return;
            let at = -1;
            for (let k = i + 1; k < shown.count; k++) if (shown.get(k).wid === id) { at = k; break; }
            if (at >= 0) shown.move(at, i, 1); else shown.insert(i, { wid: id });
        });
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
    readonly property int activeIndex: {
        void shown.count;
        const f = Hyprland.focusedWorkspace;
        return f ? list.findIndex(w => w === f || numberOf(w) === numberOf(f)) : -1;
    }

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

    Rectangle {
        readonly property Item target: { void view.count; void view.contentWidth; return root.activeIndex >= 0 ? view.itemAtIndex(root.activeIndex) : null; }
        visible: target !== null
        x: target?.x ?? 0
        width: target?.width ?? 0
        height: parent.height
        radius: Theme.r(height / 2)
        color: Theme.accent
        Behavior on x { Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring } }
        Behavior on width { Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring } }
    }

    Row {
        id: row
        height: parent.height

        ListView {
            id: view
            orientation: ListView.Horizontal
            interactive: false
            // The room the numbers take as they are, a leaving one's shrinking included (contentWidth isn't told).
            width: contentItem.childrenRect.width
            height: row.height
            model: shown
            // A number comes in growing, an emptied one shrinks and fades, and the ones beside it slide over.
            add: Transition {
                NumberAnimation { property: "span"; from: 0; to: 1; duration: Theme.durationNormal; easing.bezierCurve: Theme.curvePanelIn }
                NumberAnimation { property: "scale"; from: 0.4; to: 1; duration: Theme.durationSlow; easing.bezierCurve: Theme.curveSpring }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationNormal }
            }
            displaced: Transition {
                NumberAnimation { property: "x"; duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring }
            }

            delegate: Item {
                id: ws
                required property int wid
                required property int index
                readonly property var modelData: root.list.find(w => root.numberOf(w) === wid) ?? ({ id: wid, toplevels: { values: [] } })
                readonly property bool focused: root.activeIndex === index
                readonly property var appIcons: Config.bar.workspaceIcons ? root.icons(modelData) : []

                property real span: 1
                width: Math.max(24, content.implicitWidth + 14) * span
                // An emptied workspace's number stays while it shrinks, fades and gives its room back.
                ListView.onRemove: SequentialAnimation {
                    PropertyAction { target: ws; property: "ListView.delayRemove"; value: true }
                    ParallelAnimation {
                        NumberAnimation { target: ws; property: "scale"; to: 0.4; duration: Theme.durationNormal; easing.bezierCurve: Theme.curvePanelOut }
                        NumberAnimation { target: ws; property: "opacity"; to: 0; duration: Theme.durationNormal }
                        NumberAnimation { target: ws; property: "span"; to: 0; duration: Theme.durationNormal; easing.bezierCurve: Theme.curvePanelOut }
                    }
                    PropertyAction { target: ws; property: "ListView.delayRemove"; value: false }
                }
                height: row.height

                // Eases a change in its icons; coming in or going, its width follows `span` frame by frame instead.
                Behavior on width { enabled: ws.span === 1; Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring } }

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
