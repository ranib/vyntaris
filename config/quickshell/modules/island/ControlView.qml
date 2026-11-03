import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import "../../components/Icons.js" as Icons
import qs.services

Item {
    id: root
    readonly property real fullWidth: 480
    readonly property real hang: content.implicitHeight + 26
    readonly property bool active: Panels.controlOpen

    width: fullWidth
    height: Theme.barHeight + hang

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)

    PwObjectTracker { objects: [ root.sink, root.source ] }

    Component.onCompleted: if (active) activeChanged()
    onActiveChanged: {
        if (active) { calendar.reset(); Weather.refresh(); }
        if (active) Notifications.markRead();
        else if (adapter) adapter.discovering = false;
    }

    function nodeName(n) { return n?.description || n?.nickname || n?.name || "—"; }

    PanelHeader {
        icon: "control"
        title: Tr.t("Control center")
        HeaderButton { icon: "apps"; label: Tr.t("Apps"); onClicked: Panels.appsOpen = true }
        HeaderButton { icon: "lock"; label: Tr.t("Lock"); onClicked: { Panels.controlOpen = false; Quickshell.execDetached(["loginctl", "lock-session"]); } }
        HeaderButton { icon: "power"; label: Tr.t("Power"); onClicked: Panels.powerOpen = true }
    }

    PanelBody {
        id: content
        spacing: Theme.space10

        Rectangle {
            id: mediaCard
            readonly property var player: Media.active
            Layout.fillWidth: true
            visible: player !== null
            implicitHeight: mediaRow.implicitHeight + 24
            color: "transparent"

            Timer {
                running: root.active && mediaCard.player !== null
                interval: 1000
                repeat: true
                triggeredOnStart: true
                onTriggered: mediaCard.player?.positionChanged()
            }
            property real knownLength: 0
            readonly property real length: (player?.lengthSupported && player.length > 0) ? player.length : knownLength
            onLengthChanged: if (player?.lengthSupported && player.length > 0) knownLength = player.length
            Connections {
                target: mediaCard.player
                function onTrackTitleChanged() { mediaCard.knownLength = 0; }
            }

            RowLayout {
                id: mediaRow
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Theme.space12; rightMargin: Theme.space12 }
                spacing: Theme.space12

                ClippingRectangle {
                    implicitWidth: 52; implicitHeight: 52; radius: Theme.r(12)
                    color: Theme.accent
                    Image {
                        anchors.fill: parent
                        source: mediaCard.player?.trackArtUrl ?? ""
                        sourceSize: Qt.size(104, 104)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Icon { anchors.centerIn: parent; visible: !(mediaCard.player?.trackArtUrl); name: "music"; size: 22; color: Theme.textOnAccent }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space4
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.weight: Font.DemiBold
                        text: mediaCard.player?.trackTitle || mediaCard.player?.identity || ""
                    }
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.overlay1
                        text: mediaCard.player?.trackArtist || mediaCard.player?.identity || ""
                    }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 10
                        opacity: mediaCard.length > 0 ? 1 : 0.4
                        Row {
                            id: progCells
                            anchors.fill: parent
                            readonly property int count: 22
                            readonly property int lit: mediaCard.length > 0 ? Math.round(Math.max(0, Math.min(1, (mediaCard.player?.position ?? 0) / mediaCard.length)) * count) : 0
                            spacing: Theme.space4
                            Repeater {
                                model: progCells.count
                                Rectangle {
                                    required property int index
                                    readonly property bool on: index < progCells.lit
                                    width: (progCells.width - (progCells.count - 1) * progCells.spacing) / progCells.count
                                    height: on ? 8 : 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 2
                                    color: !on ? Theme.tint(parent, Theme.text, 0.12) : index === progCells.lit - 1 ? Theme.accentBright : Theme.accent
                                    Behavior on height { Anim { duration: Theme.durationFast } }
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            enabled: (mediaCard.player?.canSeek ?? false) && mediaCard.length > 0
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: mouse => mediaCard.player.position = Math.max(0, Math.min(1, mouse.x / width)) * mediaCard.length
                        }
                    }
                }

                Row {
                    spacing: Theme.space4
                    IconButton { size: 30; anchors.verticalCenter: parent.verticalCenter; icon: "previous"; label: Tr.t("Previous"); active: mediaCard.player?.canGoPrevious ?? false; onClicked: mediaCard.player.previous() }
                    IconButton { anchors.verticalCenter: parent.verticalCenter; primary: true; size: 38; icon: mediaCard.player?.isPlaying ? "pause" : "play"; label: mediaCard.player?.isPlaying ? Tr.t("Pause") : Tr.t("Play"); active: mediaCard.player?.canTogglePlaying ?? false; onClicked: mediaCard.player.togglePlaying() }
                    IconButton { size: 30; anchors.verticalCenter: parent.verticalCenter; icon: "next"; label: Tr.t("Next"); active: mediaCard.player?.canGoNext ?? false; onClicked: mediaCard.player.next() }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space2
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            QuickTile {
                Layout.fillWidth: true
                icon: Networking.wifiEnabled ? "wifi" : "wifi-off"
                title: Tr.t("Wi-Fi")
                subtitle: !Networking.wifiEnabled ? Tr.t("Off") : root.wifiNetwork?.name ?? Tr.t("Not connected")
                on: Networking.wifiEnabled
                enabled: root.wifi !== null
                more: true
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                onMoreClicked: Panels.wifiOpen = true
            }
            QuickTile {
                Layout.fillWidth: true
                icon: "bluetooth"
                title: Tr.t("Bluetooth")
                subtitle: !(root.adapter?.enabled ?? false) ? Tr.t("Off")
                    : root.btConnected.length === 1 ? (root.btConnected[0].name || root.btConnected[0].deviceName || Tr.t("1 device"))
                    : root.btConnected.length > 1 ? Tr.f("{0} devices", root.btConnected.length) : Tr.t("On")
                on: root.adapter?.enabled ?? false
                enabled: root.adapter !== null
                more: true
                onClicked: BluetoothCtl.toggle()
                onMoreClicked: Panels.bluetoothOpen = true
            }
            QuickTile {
                Layout.fillWidth: true
                icon: "sunset"
                title: Tr.t("Night light")
                subtitle: NightLight.active ? Config.nightLight.temperature + Tr.t(" K")
                    : Config.nightLight.automatic ? Tr.f("From {0}", Config.nightLight.start) : Tr.t("Off")
                on: NightLight.active
                more: true
                onClicked: NightLight.toggle()
                onMoreClicked: Panels.nightOpen = true
            }
            QuickTile {
                Layout.fillWidth: true
                icon: KeepAwake.icon
                title: Tr.t("Keep awake")
                subtitle: !KeepAwake.active ? Tr.t("Off")
                    : (KeepAwake.inhibitDisplay ? Tr.t("Screen stays on") : Tr.t("System stays on")) + (KeepAwake.minutes > 0 ? " · " + KeepAwake.minutes + Tr.t(" min") : "")
                on: KeepAwake.active
                more: true
                onClicked: KeepAwake.toggle()
                onMoreClicked: Panels.awakeOpen = true
            }
            QuickTile {
                Layout.fillWidth: true
                icon: root.source?.audio?.muted ? "mic-off" : "mic"
                title: Tr.t("Microphone")
                subtitle: root.source?.audio?.muted ?? true ? Tr.t("Muted")
                    : NoiseSuppression.level > 0 ? Tr.f("Noise {0}", NoiseSuppression.labels[NoiseSuppression.level].toLowerCase()) : root.nodeName(root.source)
                on: !(root.source?.audio?.muted ?? true)
                enabled: root.source !== null
                more: true
                onClicked: root.source.audio.muted = !root.source.audio.muted
                onMoreClicked: Panels.soundOpen = true
            }
            QuickTile {
                Layout.fillWidth: true
                icon: "vpn"
                title: Tr.t("VPN")
                subtitle: Vpn.active ? (Vpn.active.place || Vpn.active.name) : Tr.t("Off")
                on: Vpn.active !== null
                more: true
                onClicked: { if (Vpn.list.length > 0 || Vpn.places.length > 0) Vpn.quick(); else Panels.vpnOpen = true; }
                onMoreClicked: Panels.vpnOpen = true
            }
        }

        component Card: Item {
            id: card
            default property alias content: inner.data
            property real pad: 4
            property alias spacing: inner.spacing
            Layout.fillWidth: true
            implicitHeight: inner.implicitHeight + pad * 2
            ColumnLayout {
                id: inner
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: parent.pad }
                spacing: Theme.space12
            }
        }

        Card {
            SegmentSlider {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space2
                icon: root.sink?.audio?.muted ? "volume-x" : "volume"
                label: Tr.t("Volume")
                iconLabel: Tr.t("Mute")
                iconLevel: Icons.volumeLevel(root.sink?.audio?.volume ?? 0)
                value: root.sink?.audio?.volume ?? 0
                maximum: Config.maxVolume
                dimmed: root.sink?.audio?.muted ?? false
                valueText: root.sink?.audio?.muted ? "--" : Math.round(level * 100)
                onMoved: v => { if (root.sink?.audio) root.sink.audio.volume = v; }
                onIconClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
            }
            SegmentSlider {
                Layout.fillWidth: true
                visible: Brightness.available
                icon: "sun"
                label: Tr.t("Brightness")
                value: Brightness.value
                onMoved: v => Brightness.set(v)
            }
        }

        Card {
            pad: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                component Gauge: Item {
                    id: g
                    property alias value: ring.value
                    property alias text: ring.text
                    property alias caption: ring.caption
                    property alias color: ring.color
                    signal clicked()
                    Layout.fillWidth: true
                    implicitHeight: 62
                    Ring { id: ring; anchors.centerIn: parent; scale: gArea.containsMouse ? 1.06 : 1; Behavior on scale { Anim { duration: Theme.durationFast } } }
                    PressArea { label: ring.caption + " " + ring.text; id: gArea; anchors.fill: parent; onClicked: g.clicked() }
                }
                function tint(v) { return v > 0.9 ? Theme.error : v > 0.75 ? Theme.warning : Theme.accent; }

                Gauge {
                    value: SystemStats.cpu
                    color: parent.tint(SystemStats.cpu)
                    text: Math.round(SystemStats.cpu * 100)
                    caption: Tr.t("CPU")
                    onClicked: Panels.systemOpen = true
                }
                Gauge {
                    value: SystemStats.memory
                    color: parent.tint(SystemStats.memory)
                    text: Math.round(SystemStats.memory * 100)
                    caption: Tr.t("RAM")
                    onClicked: Panels.systemOpen = true
                }
                Gauge {
                    visible: SystemStats.temperature >= 0
                    value: SystemStats.temperature / 100
                    color: SystemStats.temperature > 85 ? Theme.error : SystemStats.temperature > 70 ? Theme.warning : Theme.accent
                    text: Math.round(SystemStats.temperature)
                    caption: "°C"
                    onClicked: Panels.systemOpen = true
                }
                Gauge {
                    visible: Battery.available
                    value: Battery.percent / 100
                    color: Battery.percent <= 15 && !Battery.charging ? Theme.error : Theme.accent
                    text: Battery.percent
                    caption: Battery.charging ? Tr.t("CHG") : Tr.t("BAT")
                    onClicked: Panels.batteryOpen = true
                }
            }
        }

        Card {
            pad: 12
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space12
                TodayWeather {
                    Layout.fillWidth: true
                    Layout.minimumWidth: Theme.fontSize * 7
                    Layout.leftMargin: Theme.space4
                    titleY: calendar.titleY
                    datesBaseline: calendar.datesBaseline
                }
                MonthCalendar { id: calendar; Layout.alignment: Qt.AlignTop; Layout.fillWidth: true; Layout.maximumWidth: implicitWidth }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairlineOn(parent) }

        NotificationList {
            Layout.fillWidth: true
            maxListHeight: 240
        }
    }
}
