import QtQuick
import qs.config

Item {
    id: root
    property real value: 0
    property color fillColor: Theme.accent
    property int count: Math.max(8, Math.round(width / 9))

    implicitWidth: 120
    implicitHeight: 14

    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * count)

    Row {
        id: cells
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space4
        Repeater {
            model: root.count
            Rectangle {
                required property int index
                readonly property bool on: index < root.lit
                width: (root.width - (root.count - 1) * cells.spacing) / root.count
                height: on ? 12 : 6
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: !on ? Theme.tint(parent, Theme.text, 0.1)
                    : index === root.lit - 1 && root.fillColor === Theme.accent ? Theme.accentBright : root.fillColor
                Behavior on height { Anim { duration: Theme.durationFast } }
                Behavior on color { ColorAnim {} }
            }
        }
    }
}
