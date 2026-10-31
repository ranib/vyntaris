import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    readonly property real fullWidth: Math.max(420, Theme.fontSize * 32)
    readonly property real hang: content.implicitHeight + 24

    width: fullWidth
    height: Theme.barHeight + hang

    readonly property var b: Battery
    readonly property color tint: b.charging ? Theme.accent
        : b.percent <= 15 ? Theme.error
        : b.percent <= 30 ? Theme.warning : Theme.accent

    function duration(hours) {
        if (hours < 0) return "";
        const h = Math.floor(hours), m = Math.round((hours - h) * 60);
        return h > 0 ? `${h}h ${String(m).padStart(2, "0")}m` : `${m}m`;
    }

    Connections {
        target: Panels
        function onBatteryOpenChanged() { if (Panels.batteryOpen) Battery.refresh(); }
    }

    PanelHeader {
        icon: "battery"
        title: root.b.full ? Tr.t("Full") : root.b.charging ? Tr.t("Charging") : Tr.t("Battery")
    }

    PanelBody {
        id: content

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space14

            Label {
                mono: true
                font.pixelSize: Theme.fontSizeHero
                font.weight: Font.Light
                color: Theme.ink(root.tint)
                text: root.b.percent + "%"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space2
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    font.weight: Font.DemiBold
                    text: root.b.full ? Tr.t("Plugged in")
                        : root.b.hoursLeft < 0 ? Tr.t("Estimating…")
                        : root.duration(root.b.hoursLeft) + (root.b.charging ? Tr.t(" until full") : Tr.t(" remaining"))
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    mono: true
                    color: Theme.subtext0
                    font.pixelSize: Theme.fontSizeLabel
                    text: root.b.power.toFixed(1) + Tr.t(" W · ") + root.b.energyNow.toFixed(1) + " / " + root.b.energyFull.toFixed(1) + Tr.t(" Wh")
                }
            }
        }

        Row {
            id: cells
            Layout.fillWidth: true
            readonly property int count: 20
            readonly property int filled: Math.round(root.b.percent / 100 * count)
            spacing: Theme.space4
            Repeater {
                model: cells.count
                Rectangle {
                    required property int index
                    width: (cells.width - (cells.count - 1) * cells.spacing) / cells.count
                    height: 14
                    radius: 3
                    color: index < cells.filled ? root.tint : Theme.alpha(Theme.text, 0.1)

                    SequentialAnimation on opacity {
                        running: root.b.charging && !root.b.full && index === cells.filled - 1 && Theme.speed > 0
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space10

            Label { overline: true; color: Theme.overlay1; text: Tr.t("Health") }
            Meter {
                Layout.fillWidth: true
                implicitHeight: 8
                visible: root.b.health >= 0
                value: root.b.health
                fillColor: root.b.health < 0.6 ? Theme.error : root.b.health < 0.8 ? Theme.warning : Theme.accent
            }
            Label {
                mono: true
                font.pixelSize: Theme.fontSizeLabel
                text: root.b.health >= 0 ? Math.round(root.b.health * 100) + "%" : "—"
            }
            Rectangle { implicitWidth: 1; implicitHeight: 12; color: Theme.hairline }
            Label { overline: true; color: Theme.overlay1; text: Tr.t("Cycles") }
            Label {
                mono: true
                font.pixelSize: Theme.fontSizeLabel
                text: root.b.cycles >= 0 ? root.b.cycles : "—"
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline; visible: Battery.users.length > 0 }

        Label { visible: Battery.users.length > 0; overline: true; color: Theme.overlay1; text: Tr.t("Using the most") }
        Repeater {
            model: Battery.users
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.space10
                Icon { name: modelData.cpu < 0 ? "monitor" : "cpu"; size: 14; color: Theme.overlay1 }
                Label { Layout.fillWidth: true; elide: Text.ElideRight; text: modelData.name }
                Meter {
                    visible: modelData.cpu >= 0
                    implicitWidth: 90
                    implicitHeight: 6
                    value: Math.min(1, modelData.cpu / 50)
                    fillColor: modelData.cpu >= 25 ? Theme.warning : Theme.accent
                }
                Label {
                    mono: true
                    font.pixelSize: Theme.fontSizeLabel
                    color: modelData.cpu < 0 ? Theme.warning : Theme.subtext0
                    text: modelData.cpu < 0 ? Tr.t("awake") : modelData.cpu + "%"
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space10
            Icon { name: "gauge"; size: 16; color: Theme.overlay1 }
            Label { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; overline: true; color: Theme.overlay1; text: Tr.t("Power") }
            Choice {
                options: Power.order.map(p => ({ value: p, label: Power.name(p).replace(Tr.t("Power saver"), Tr.t("Saver")) }))
                current: Power.profile
                onPicked: v => Power.set(v)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Battery.limitKind !== ""
            spacing: Theme.space10
            Icon { name: "battery"; level: 5; size: 16; color: Battery.chargeLimit ? Theme.accentInk : Theme.overlay1 }
            Label { Layout.fillWidth: true; overline: true; color: Theme.overlay1; text: Tr.t("Limit to 80%") }
            Switch { checked: Battery.chargeLimit; onToggled: on => Battery.setChargeLimit(on) }
        }
    }
}
