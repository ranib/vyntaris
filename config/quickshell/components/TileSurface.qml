import QtQuick
import qs.config

Rectangle {
    id: root
    property bool marked: false
    property bool solid: false
    property real pressScale: 0.97
    readonly property alias hovered: area.containsMouse
    readonly property alias pressed: area.pressed
    property alias acceptedButtons: area.acceptedButtons
    property alias label: area.label
    property alias role: area.role
    property alias checked: area.checked
    signal activated(var mouse)
    signal entered()

    radius: Theme.r(16)
    readonly property color fill: marked && solid ? (hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
        : hovered || marked ? Theme.tint(parent, Theme.text, 0.09) : Theme.tint(parent, Theme.text, 0.05)
    readonly property color edge: marked ? Theme.accent : Theme.rimOn(parent)
    // Slanted, the fill is drawn by the shape and `color` is clear, so what is on it tints over `fill`.
    readonly property color ground: fill
    color: slant.on ? "transparent" : fill
    border { width: slant.on ? 0 : 1; color: edge }
    Slanted { id: slant; fill: root.fill; stroke: root.edge; radius: root.radius }
    scale: pressed ? pressScale : 1
    Behavior on color { ColorAnim {} }
    Behavior on scale { Anim { duration: Theme.durationFast; easing.bezierCurve: Theme.curveSpring } }

    PressArea {
        id: area
        anchors.fill: parent
        onClicked: mouse => root.activated(mouse)
        onEntered: root.entered()
    }
}
