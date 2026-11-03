import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    readonly property real fullWidth: 400
    readonly property real hang: content.implicitHeight > 0 ? content.implicitHeight + 28 : 8
    readonly property bool active: Panels.phoneOpen
    readonly property var phone: Phone.phone
    readonly property var mine: phone ?? Phone.paired[0] ?? null
    readonly property var away: Phone.paired.filter(d => d !== root.mine)

    width: fullWidth
    height: Theme.barHeight + hang

    onActiveChanged: if (active && Phone.running) Phone.refresh()

    PanelHeader {
        icon: "smartphone"
        title: Tr.t("Phone")
        Switch {
            checked: Phone.enabled
            onToggled: on => Phone.setEnabled(on)
        }
    }

    PanelBody {
        id: content
        spacing: Theme.space10

        Label {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space4
            Layout.bottomMargin: Theme.space4
            visible: !Phone.enabled
            horizontalAlignment: Text.AlignHCenter
            color: Theme.overlay1
            text: Tr.t("Off")
        }

        component PanelRow: PanelSurface {
            id: row
            property string icon
            property string title
            property string note
            property string action
            property string status
            property bool lit: false
            property bool sure: false
            property bool asking: false
            signal chosen()
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Theme.r(12)
            opacity: enabled ? 1 : Theme.disabledOpacity
            fill: hover.containsMouse ? Theme.hoverOn(parent) : "transparent"
            Behavior on fill { ColorAnim {} }
            PressArea {
                label: row.title
                id: hover
                anchors.fill: parent
                onExited: row.asking = false
                onClicked: {
                    if (row.sure && !row.asking) { row.asking = true; return; }
                    row.asking = false;
                    row.chosen();
                }
            }
            RowLayout {
                anchors { fill: parent; leftMargin: Theme.space12; rightMargin: Theme.space12 }
                spacing: Theme.space12
                Icon { name: row.icon; size: 16; color: Theme.text }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { Layout.fillWidth: true; elide: Text.ElideRight; text: row.title }
                    Label {
                        Layout.fillWidth: true
                        visible: row.note !== ""
                        overline: true
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.overlay1
                        text: row.note
                    }
                }
                Label {
                    visible: hover.containsMouse ? row.action !== "" : row.status !== ""
                    overline: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: row.asking ? Theme.error : hover.containsMouse || row.lit ? Theme.accentInk : Theme.overlay1
                    text: row.asking ? Tr.t("Sure?") : hover.containsMouse ? row.action : row.status
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Phone.enabled
            spacing: Theme.space8

            Repeater {
                model: Phone.asking
                PanelSurface {
                    id: ask
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: Theme.r(12)
                    fill: Theme.tint(parent, Theme.text, 0.05)
                    edgeWidth: 1; edge: Theme.accent
                    RowLayout {
                        anchors { fill: parent; leftMargin: Theme.space12; rightMargin: Theme.space8 }
                        spacing: Theme.space10
                        Icon { name: Phone.iconFor(ask.modelData); size: 16; color: Theme.accentInk }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.DemiBold; text: ask.modelData.name }
                            Label {
                                overline: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.accentInk
                                text: Tr.f("Wants to pair · code {0}", ask.modelData.code)
                            }
                        }
                        ChipButton { text: Tr.t("Reject"); onClicked: Phone.reject(ask.modelData.id) }
                        ChipButton { on: true; text: Tr.t("Pair"); onClicked: Phone.accept(ask.modelData.id) }
                    }
                }
            }

            ConnectionSummary {
                Layout.fillWidth: true
                connected: root.phone !== null
                name: root.mine?.name ?? (!Phone.running ? Tr.t("Starting…") : Tr.t("No phone yet"))
                icon: Phone.iconFor(root.mine)
                level: root.phone && root.phone.battery >= 0 ? root.phone.battery / 100 : -1
                details: !root.mine ? Tr.t("KDE Connect on the phone, on the same Wi-Fi")
                    : !root.phone ? Tr.t("Not in reach · on the same Wi-Fi?")
                    : [root.phone.charging ? Tr.t("Charging") : "", root.phone.network,
                       root.phone.signal >= 0 ? Tr.f("Signal {0}/4", root.phone.signal) : ""].filter(s => s).join("  ·  ")
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.phone !== null
                spacing: Theme.space2
                PanelRow {
                    icon: "phone-ring"; title: Tr.t("Find it"); action: Tr.t("Ring")
                    enabled: root.phone?.can.includes("ring") ?? false
                    onChosen: Phone.ring(root.phone.id)
                }
                PanelRow {
                    icon: "send"; title: Tr.t("Send it files"); action: Tr.t("Choose")
                    enabled: root.phone?.can.includes("share") ?? false
                    onChosen: { Phone.pick(root.phone.id); Panels.phoneOpen = false; }
                }
                PanelRow {
                    icon: "clipboard"; title: Tr.t("Send it the clipboard"); action: Tr.t("Send")
                    enabled: root.phone?.can.includes("clipboard") ?? false
                    onChosen: Phone.clipboard(root.phone.id)
                }
            }

            Label {
                Layout.fillWidth: true
                visible: Phone.failure !== ""
                wrapMode: Text.Wrap
                color: Theme.error
                font.pixelSize: Theme.fontSizeSmall
                text: Phone.failure
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.mine !== null
                spacing: Theme.space2
                Rectangle { Layout.fillWidth: true; Layout.topMargin: Theme.space4; Layout.bottomMargin: Theme.space6; implicitHeight: 1; color: Theme.hairlineOn(parent) }
                Caption { Layout.bottomMargin: Theme.space4; text: Tr.t("Shared") }
                component Share: PanelRow {
                    property string key
                    visible: key in (root.mine?.features ?? {})
                    readonly property bool on: root.mine?.features[key] ?? false
                    status: on ? Tr.t("On") : Tr.t("Off")
                    lit: on
                    action: on ? Tr.t("Turn off") : Tr.t("Turn on")
                    onChosen: Phone.feature(root.mine.id, key, !on)
                }
                Share { key: "control"; icon: "touchpad"; title: Tr.t("Control this computer"); note: "touchpad, keyboard, volume, music" }
                Share { key: "notifications"; icon: "bell"; title: Tr.t("Its notifications") }
                Share { key: "clipboard"; icon: "copy"; title: Tr.t("One clipboard") }
                Share { key: "pausemusic"; icon: "pause"; title: Tr.t("Pause music during calls") }
                PanelRow {
                    icon: "close"; title: Tr.f("Unpair {0}", root.mine?.name ?? ""); action: Tr.t("Unpair"); sure: true
                    onChosen: Phone.unpair(root.mine.id)
                }
            }

            Caption { visible: root.away.length > 0; Layout.topMargin: Theme.space4; text: Tr.t("Paired") }
            Repeater {
                model: root.away
                PanelRow {
                    required property var modelData
                    icon: Phone.iconFor(modelData); title: modelData.name; status: Tr.t("Away"); action: Tr.t("Unpair"); sure: true
                    onChosen: Phone.unpair(modelData.id)
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.topMargin: Theme.space4; implicitHeight: 1; color: Theme.hairlineOn(parent); visible: Phone.running }
            RowLayout {
                Layout.fillWidth: true
                visible: Phone.running
                Caption { Layout.fillWidth: true; text: Tr.t("Nearby") }
                Label {
                    visible: Phone.nearby.length === 0
                    color: Theme.overlay1; text: Tr.t("Looking…")
                }
            }
            Repeater {
                model: Phone.nearby
                PanelRow {
                    required property var modelData
                    readonly property bool waiting: modelData.pairState === 1
                    icon: Phone.iconFor(modelData); title: modelData.name
                    note: waiting ? "Accept on the phone · code " + modelData.code : ""
                    action: waiting ? Tr.t("Cancel") : Tr.t("Pair")
                    onChosen: waiting ? Phone.reject(modelData.id) : Phone.pair(modelData.id)
                }
            }
        }
    }
}
