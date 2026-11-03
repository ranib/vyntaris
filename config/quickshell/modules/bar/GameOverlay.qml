import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.components
import qs.modules.island
import qs.services

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property bool shown: Games.watching && Games.known && Compositor.fullscreenMode === 2
        && Monitors.focused?.name === modelData.name
    visible: shown || fade.running

    WlrLayershell.namespace: "quickshell-game"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    implicitWidth: pill.width
    implicitHeight: Theme.barHeight
    color: "transparent"
    mask: Region {}

    Rectangle {
        id: pill
        width: stats.implicitWidth + 36
        height: Theme.barHeight + radius
        y: -radius
        radius: Theme.r(12)
        color: Theme.glassTop
        border { width: 1; color: Theme.rimOn(parent) }
        opacity: win.shown ? 1 : 0
        Behavior on opacity { Anim { id: fade; duration: Theme.durationNormal } }

        GameStatsRow {
            id: stats
            anchors.horizontalCenter: parent.horizontalCenter
            y: pill.radius + (Theme.barHeight - height) / 2
        }
    }
}
