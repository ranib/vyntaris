import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

RowLayout {
    id: root
    required property var link
    Layout.fillWidth: true
    Layout.topMargin: Theme.space2
    spacing: Theme.space8
    Repeater {
        model: [
            { value: root.link.speed(root.link.down), label: Tr.t("Download"), waiting: root.link.down < 0 },
            { value: root.link.speed(root.link.up), label: Tr.t("Upload"), waiting: root.link.up < 0 },
            { value: root.link.ping >= 0 ? Math.round(root.link.ping) + " ms" : "–", label: Tr.t("Ping"), waiting: !root.link.ready },
            { value: root.link.rate || "–", label: Tr.t("Link"), waiting: !root.link.ready },
        ]
        ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: Theme.space2
            Item {
                Layout.fillWidth: true
                implicitHeight: statValue.implicitHeight
                Label {
                    id: statValue
                    width: parent.width
                    visible: !parent.parent.modelData.waiting
                    elide: Text.ElideRight
                    mono: true
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: Font.DemiBold
                    text: parent.parent.modelData.value
                }
                Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.parent.modelData.waiting
                    size: 12
                }
            }
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.overlay1
                text: parent.modelData.label
            }
        }
    }
}
