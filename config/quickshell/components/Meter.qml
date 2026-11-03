import QtQuick
import qs.config

Item {
    id: root
    property real value: 0
    property bool dimmed: false
    property color fillColor: Theme.accent
    property int count: 20
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * count)

    implicitWidth: 34
    implicitHeight: 8

    readonly property real gap: height >= 10 ? 3 : 2

    Row {
        anchors.fill: parent
        spacing: root.gap
        Repeater {
            model: root.count
            Rectangle {
                required property int index
                width: (root.width - (root.count - 1) * root.gap) / root.count
                height: root.height
                radius: Math.min(3, height / 4)
                color: index >= root.lit ? Theme.tint(parent, Theme.text, 0.1)
                    : root.dimmed ? Theme.overlay0
                    : index === root.lit - 1 && root.fillColor === Theme.accent ? Theme.accentBright : root.fillColor
                Behavior on color { ColorAnim {} }
            }
        }
    }
}
