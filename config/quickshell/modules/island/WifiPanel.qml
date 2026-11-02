import Quickshell.Networking
import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.wifi

Item {
    id: root
    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property real fullWidth: 400
    readonly property real hang: wifi.bodyHeight + 4

    width: fullWidth
    height: Theme.barHeight + hang

    PanelHeader {
        icon: wifi.wiredOnly ? "ethernet" : "wifi"
        title: root.wired ? Tr.t("Network") : Tr.t("Wi-Fi")
        Switch {
            visible: root.device !== null && !wifi.wiredOnly
            checked: Networking.wifiEnabled
            onToggled: on => Networking.wifiEnabled = on
        }
    }

    WifiView {
        id: wifi
        y: Theme.barHeight
        width: root.fullWidth
        showHeader: false
        device: root.device
        wiredDevice: root.wired
        open: Panels.wifiOpen
    }
}
