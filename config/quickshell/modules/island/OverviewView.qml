import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    readonly property bool active: Panels.overviewOpen

    readonly property int cardW: 260
    readonly property int cardH: 170
    readonly property int columns: Math.max(1, Math.min(4, windows.length))
    readonly property real fullWidth: Math.max(420, columns * (cardW + 12) + 28)
    readonly property real hang: windows.length === 0 ? 90
        : Math.ceil(windows.length / columns) * (cardH + 12) + 34

    width: fullWidth
    height: Theme.barHeight + hang

    readonly property var windows: Hyprland.toplevels.values
        .filter(t => t.workspace && t.workspace.id > 0)
        .sort((a, b) => a.workspace.id - b.workspace.id)

    property int current: 0

    Component.onCompleted: if (active) activeChanged()
    onActiveChanged: {
        if (!active) return;
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        selectTimer.restart();
        focusTimer.restart();
    }
    Timer {
        id: selectTimer
        interval: 60
        onTriggered: {
            const focused = root.windows.indexOf(Hyprland.activeToplevel);
            root.current = Math.max(0, (focused + 1) % Math.max(1, root.windows.length));
            if (Panels.overviewCommitPending) {
                Panels.overviewCommitPending = false;
                root.goTo(root.current);
            }
        }
    }

    function step(delta) {
        const n = windows.length;
        if (n > 0) current = (current + delta + n) % n;
    }
    Connections {
        target: Panels
        function onOverviewStep(delta) { root.step(delta); }
        function onOverviewCommitted() { if (!selectTimer.running) root.goTo(root.current); else Panels.overviewCommitPending = true; }
    }
    Timer { id: focusTimer; interval: 30; onTriggered: keys.forceActiveFocus() }
    Connections {
        target: root.Window.window
        function onActiveChanged() { if (root.active && root.Window.window.active) keys.forceActiveFocus(); }
    }

    function goTo(i) {
        const t = windows[i];
        if (!t) return;
        Panels.overviewOpen = false;
        // Focused once the switcher has let the keyboard go: while it holds it, Hyprland moves no focus, so
        // letting go of Alt closed it and left the window as it was.
        focusLater.address = String(t.address).startsWith("0x") ? t.address : "0x" + t.address;
        focusLater.restart();
    }
    Timer {
        id: focusLater
        property string address
        interval: 80
        onTriggered: Compositor.dispatch(`hl.dsp.focus({ window = "address:${address}" })`)
    }

    Item {
        id: keys
        anchors.fill: parent
        readonly property int n: root.windows.length
        Keys.onEscapePressed: Panels.overviewOpen = false
        Keys.onTabPressed: root.current = (root.current + 1) % Math.max(1, n)
        Keys.onBacktabPressed: root.current = (root.current + n - 1) % Math.max(1, n)
        Keys.onRightPressed: root.current = (root.current + 1) % Math.max(1, n)
        Keys.onLeftPressed: root.current = (root.current + n - 1) % Math.max(1, n)
        Keys.onDownPressed: root.current = Math.min(n - 1, root.current + root.columns)
        Keys.onUpPressed: root.current = Math.max(0, root.current - root.columns)
        Keys.onReturnPressed: root.goTo(root.current)
        Keys.onEnterPressed: root.goTo(root.current)
        Keys.onSpacePressed: root.goTo(root.current)
        Keys.onReleased: event => { if (event.key === Qt.Key_Alt && Panels.overviewOpen) Panels.overviewCommit(); }
    }

    PanelHeader {
        icon: "windows"
        title: Tr.t("Windows")
        Label { mono: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.overlay1; text: root.windows.length }
    }

    Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.panelTop
        columns: root.columns
        spacing: Theme.space12

        Repeater {
            model: root.windows

            Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool selected: root.current === index
                width: root.cardW
                height: root.cardH

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r(16)
                    color: card.selected ? Theme.accent
                        : area.containsMouse ? Theme.tint(parent, Theme.text, 0.09) : Theme.tint(parent, Theme.text, 0.05)
                    border { width: 1; color: card.selected ? Theme.accent : Theme.rimOn(parent) }
                    Behavior on color { ColorAnim {} }
                }

                ScreencopyView {
                    id: preview
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.space8 }
                    height: parent.height - 44
                    captureSource: root.active ? card.modelData.wayland : null
                    live: root.active
                    constraintSize: Qt.size(width, height)
                }

                RowLayout {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.space10 }
                    spacing: Theme.space8
                    AppIcon {
                        implicitSize: 18
                        readonly property string appId: card.modelData.wayland?.appId ?? ""
                        source: Quickshell.iconPath(DesktopEntries.heuristicLookup(appId)?.icon ?? appId, true)
                            || Quickshell.iconPath("application-x-executable", true)
                    }
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeLabel
                        font.weight: card.selected ? Font.DemiBold : Font.Normal
                        color: card.selected ? Theme.textOnAccent : Theme.subtext1
                        text: card.modelData.title
                    }
                    Label {
                        mono: true
                        font.pixelSize: Theme.fontSizeSmall
                        color: card.selected ? Theme.textOnAccent : Theme.overlay0
                        text: card.modelData.workspace?.id ?? ""
                    }
                }

                scale: area.pressed ? 0.97 : 1
                Behavior on scale { Anim { duration: Theme.durationFast; easing.bezierCurve: Theme.curveSpring } }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.current = card.index
                    onClicked: root.goTo(card.index)
                }
            }
        }
    }


    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barHeight + 30
        visible: root.windows.length === 0
        color: Theme.overlay1
        text: Tr.t("No open windows")
    }
}
