import QtQuick
import QtQuick.Layouts
import qs.config

RowLayout {
    id: root
    property bool connected: false
    property string name
    property string icon
    property int iconLevel: -1
    property real level: -1
    property string details
    property bool showDetails: true

    readonly property string caption: [level >= 0 ? Math.round(level * 100) + "%" : "", showDetails ? details : ""].filter(s => s).join("  ·  ")
    spacing: Theme.space12

    Rectangle {
        implicitWidth: 38
        implicitHeight: 38
        radius: 19
        color: root.connected ? Theme.accent : Theme.tint(parent, Theme.text, 0.06)
        Icon {
            anchors.centerIn: parent
            name: root.icon
            level: root.iconLevel
            size: 18
            color: root.connected ? Theme.textOnAccent : Theme.overlay1
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.space2
        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.DemiBold
            color: root.connected ? Theme.text : Theme.subtext0
            text: root.name
        }
        Label {
            Layout.fillWidth: true
            visible: text !== ""
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.overlay1
            text: root.caption
        }
    }
}
