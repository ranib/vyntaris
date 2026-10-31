import QtQuick
import qs.config

Item {
    id: root
    property string icon
    property string glyph
    property string label
    property color tint: Theme.accent
    property bool on: false
    property bool enabled: true
    property bool interactive: true
    signal clicked()
    signal rightClicked()
    signal entered()

    implicitWidth: 72
    implicitHeight: circle.height + 6 + name.implicitHeight
    opacity: enabled ? 1 : Theme.disabledOpacity
    readonly property color inkOn: Theme.on(tint)

    Rectangle {
        id: circle
        anchors.horizontalCenter: parent.horizontalCenter
        width: 48
        height: 48
        radius: 24
        color: root.on ? root.tint : area.containsMouse && root.interactive ? Theme.alpha(Theme.text, 0.12) : Theme.alpha(Theme.text, 0.07)
        border { width: 1; color: root.on ? root.tint : Theme.glassRim }
        scale: area.pressed ? 0.9 : 1
        Behavior on color { ColorAnim {} }
        Behavior on scale { Anim { duration: Theme.durationFast; easing.bezierCurve: Theme.curveSpring } }

        Label {
            anchors.centerIn: parent
            visible: root.glyph !== ""
            mono: true
            font.weight: Font.Bold
            color: root.on ? root.inkOn : Theme.subtext1
            text: root.glyph
        }
        Icon {
            anchors.centerIn: parent
            visible: root.glyph === ""
            name: root.icon
            size: 19
            color: root.on ? root.inkOn : Theme.subtext1
        }
    }

    Label {
        id: name
        anchors { horizontalCenter: parent.horizontalCenter; top: circle.bottom; topMargin: Theme.space6 }
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.pixelSize: Theme.fontSizeSmall
        font.weight: root.on ? Font.DemiBold : Font.Normal
        color: root.on ? (Qt.colorEqual(root.tint, Theme.accent) ? Theme.text : Theme.ink(root.tint)) : Theme.overlay1
        text: root.label
    }

    PressArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled && root.interactive
        label: root.label
        ringRadius: 14
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse?.button === Qt.RightButton ? root.rightClicked() : root.clicked()
        onEntered: root.entered()
    }
}
