import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root
    property string text
    property string icon
    property bool danger: false
    property bool on: false
    signal clicked()
    readonly property color fill: danger ? Theme.error : Theme.accent

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 24
    radius: Theme.r(12)
    color: area.containsMouse ? fill : on ? Theme.accent : Theme.tint(parent, Theme.text, 0.06)
    border { width: 1; color: area.containsMouse ? fill : on ? Theme.accent : Theme.rimOn(parent) }
    Behavior on color { ColorAnim {} }

    readonly property color ink: area.containsMouse ? Theme.on(fill) : on ? Theme.textOnAccent : Theme.subtext0
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space6
        Icon { visible: root.icon !== ""; name: root.icon; size: 12; color: root.ink }
        Label { overline: true; font.pixelSize: Theme.fontSizeSmall; color: root.ink; text: root.text }
    }
    PressArea { id: area; anchors.fill: parent; label: root.text; onClicked: root.clicked() }
}
