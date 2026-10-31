import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    readonly property real fullWidth: 340
    readonly property real hang: content.implicitHeight + 24

    width: fullWidth
    height: Theme.barHeight + hang

    readonly property var kinds: [
        { id: "mic",    icon: "mic",     off: "mic-off",    label: Tr.t("Microphone"), color: Theme.peach },
        { id: "camera", icon: "camera",  off: "camera-off", label: Tr.t("Camera"),     color: Theme.green },
        { id: "screen", icon: "monitor", off: "monitor",    label: Tr.t("Screen"),     color: Theme.green },
    ]

    PanelHeader { icon: "eye"; title: Tr.t("Privacy") }

    PanelBody {
        id: content
        y: Theme.barHeight + 8

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: Theme.space16

        Repeater {
            model: root.kinds
            RoundToggle {
                id: sensor
                required property var modelData
                readonly property var users: Privacy.entries.filter(e => e.kind === modelData.id).map(e => e.app)
                interactive: false
                on: users.length > 0
                tint: modelData.color
                icon: on ? modelData.icon : modelData.off
                label: on ? users[0] + (users.length > 1 ? " +" + (users.length - 1) : "") : modelData.label
            }
        }
    }

    Repeater {
        model: Privacy.entries
        RowLayout {
            id: use
            required property var modelData
            readonly property var kind: root.kinds.find(k => k.id === modelData.kind)
            Layout.fillWidth: true
            spacing: Theme.space10
            Icon { name: use.kind?.icon ?? "eye"; size: 15; color: Theme.ink(use.kind?.color ?? Theme.accent) }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.DemiBold; text: use.modelData.app }
                Caption { text: Tr.f("Uses the {0}", (use.kind?.label ?? "").toLowerCase()) }
            }
            ChipButton { visible: Privacy.canClose(use.modelData); danger: true; text: Tr.t("Close"); onClicked: Privacy.close(use.modelData) }
        }
    }
    }
}
