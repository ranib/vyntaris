import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property real fullWidth: 400
    readonly property real hang: content.implicitHeight > 0 ? content.implicitHeight + 28 : 8
    readonly property bool active: Panels.bluetoothOpen

    width: fullWidth
    height: Theme.barHeight + hang

    function named(d) {
        const n = d.name || d.deviceName || "";
        return n && n !== d.address && !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(n);
    }
    readonly property var devices: (adapter?.devices.values ?? [])
        .filter(d => d.paired || root.named(d))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || ""))
    readonly property var connected: devices.find(d => d.connected) ?? null
    readonly property var paired: devices.filter(d => d !== connected && d.paired).slice(0, 6)
    readonly property var available: devices.filter(d => !d.paired).slice(0, 6)

    function iconFor(d) {
        const i = d?.icon ?? "";
        return /audio|headset|headphone|speaker/.test(i) ? "headphones"
            : /keyboard/.test(i) ? "keyboard"
            : /phone/.test(i) ? "bell"
            : /computer/.test(i) ? "windows"
            : "bluetooth";
    }

    function nameOf(d) { return d?.name || d?.deviceName || ""; }
    function choose(d) {
        if (d.connected) d.disconnect();
        else if (d.paired) d.connect();
        else { d.trusted = true; d.pair(); }
    }

    Instantiator {
        model: ["discovering", "pairable", "discoverable"]
        Binding {
            required property string modelData
            target: root.adapter
            property: modelData
            value: root.active && root.on
            when: root.adapter !== null
        }
    }

    PanelHeader {
        icon: "bluetooth"
        title: Tr.t("Bluetooth")
        Switch {
            checked: root.on
            onToggled: on => BluetoothCtl.setEnabled(on)
        }
    }

    PanelBody {
        id: content
        spacing: Theme.space10

        Label {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space4
            Layout.bottomMargin: Theme.space4
            visible: !root.adapter
            horizontalAlignment: Text.AlignHCenter
            color: Theme.overlay1
            text: Tr.t("No adapter")
        }

        Label {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space4
            Layout.bottomMargin: Theme.space4
            visible: !!root.adapter && !root.on
            horizontalAlignment: Text.AlignHCenter
            color: Theme.overlay1
            text: Tr.t("Off")
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.on
            spacing: Theme.space8

            ConnectionSummary {
                Layout.fillWidth: true
                connected: root.connected !== null
                name: root.connected ? root.nameOf(root.connected) : Tr.t("No device")
                icon: root.iconFor(root.connected)
                level: root.connected?.batteryAvailable ? root.connected.battery : -1
                details: root.connected ? root.connected.address : root.paired.length > 0 ? root.paired.length + " paired" : ""
                showDetails: root.connected !== null || root.paired.length > 0

                Button {
                    visible: root.connected !== null
                    text: Tr.t("Disconnect")
                    onClicked: root.connected.disconnect()
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.topMargin: Theme.space4; implicitHeight: 1; color: Theme.hairlineOn(parent) }
        }

        component DeviceRow: PanelSurface {
            id: row
            required property var modelData
            readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting || modelData.pairing
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Theme.r(12)
            fill: hover.containsMouse ? Theme.hoverOn(parent) : "transparent"
            Behavior on fill { ColorAnim {} }
            PressArea { label: root.nameOf(row.modelData); id: hover; anchors.fill: parent; onClicked: root.choose(row.modelData) }
            RowLayout {
                anchors { fill: parent; leftMargin: Theme.space12; rightMargin: Theme.space12 }
                spacing: Theme.space12
                Icon { name: root.iconFor(row.modelData); size: 16; color: row.modelData.paired ? Theme.text : Theme.overlay1 }
                Label { Layout.fillWidth: true; elide: Text.ElideRight; text: root.nameOf(row.modelData) }
                Spinner { visible: row.busy; size: 14 }
                Label {
                    visible: row.busy || hover.containsMouse
                    overline: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.accentInk
                    text: (row.busy ? Tr.t("Connecting") : row.modelData.paired ? Tr.t("Connect") : Tr.t("Pair"))
                }
                Label {
                    visible: !row.busy && !hover.containsMouse && row.modelData.batteryAvailable
                    mono: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.overlay1
                    text: Math.round(row.modelData.battery * 100) + "%"
                }
            }
        }

        Caption {
            visible: root.on && root.paired.length > 0
            text: Tr.t("Paired")
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.on && root.paired.length > 0
            spacing: Theme.space2
            Repeater { model: root.paired; DeviceRow {} }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.on
            Caption { Layout.fillWidth: true; text: Tr.t("Nearby") }
            Spinner { visible: root.available.length === 0; size: 12 }
            Label {
                visible: root.available.length === 0
                color: Theme.overlay1; text: Tr.t("Scanning…")
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.on
            spacing: Theme.space2
            Repeater { model: root.available; DeviceRow {} }
        }
    }
}
