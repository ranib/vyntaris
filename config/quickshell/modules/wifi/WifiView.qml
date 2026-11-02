import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components
import "../../components/Icons.js" as Icons

Item {
    id: root
    required property var device
    property bool open: false
    property bool showHeader: true
    property var wiredDevice: null
    readonly property bool wiredShown: !showHeader && !asking && (wiredDevice?.connected ?? false)
    readonly property bool wiredOnly: wiredShown && connected === null

    readonly property real naturalWidth: 340
    readonly property real bodyHeight: content.implicitHeight > 0 ? content.implicitHeight + 28 : 8

    property var pending: null
    property string error: ""
    readonly property bool asking: pending !== null

    width: naturalWidth
    height: bodyHeight

    readonly property var networks: (device?.networks.values ?? [])
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))

    readonly property var connected: networks.find(n => n.connected) ?? null

    function choose(n) {
        error = "";
        if (n.connected || n.stateChanging) return;
        if (n.known || n.security === WifiSecurityType.Open) {
            pending = null;
            n.connect();
        } else {
            pending = n;
            password.text = "";
            password.revealed = false;
            Qt.callLater(() => password.input.forceActiveFocus());
        }
    }

    function cancelPassword() {
        pending = null;
        error = "";
        password.text = "";
    }

    function submitPassword() {
        if (!pending || password.text.length === 0) return;
        pending.connectWithPsk(password.text);
        pending = null;
        password.text = "";
    }

    WifiLink {
        id: link
        device: root.device?.name ?? ""
        active: root.open && !root.asking && root.connected !== null
    }

    WifiLink {
        id: wiredLink
        wired: true
        device: root.wiredDevice?.name ?? ""
        active: root.open && root.wiredShown
    }

    Timer { id: scanLinger; interval: 1500 }
    Binding {
        target: root.device
        property: "scannerEnabled"
        value: (root.open && !root.wiredOnly) || scanLinger.running
        when: root.device !== null
    }

    Binding {
        target: Panels
        property: "wifiTyping"
        value: root.asking
        when: root.open
    }

    onOpenChanged: if (!open) { pending = null; error = ""; scanLinger.restart(); }

    PanelBody {
        id: content
        y: root.showHeader ? 14 : 6
        spacing: Theme.space10

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.showHeader && !root.asking
            spacing: Theme.space10

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space10

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1000
                    spacing: Theme.space2
                    Label { overline: true; text: Tr.t("Wi-Fi"); color: Theme.overlay1 }
                    Label {
                        text: !Networking.wifiEnabled ? Tr.t("Off")
                            : root.networks.find(n => n.connected)?.name ?? Tr.t("Not connected")
                        font.weight: Font.DemiBold
                    }
                }

                Switch {
                    checked: Networking.wifiEnabled
                    onToggled: on => Networking.wifiEnabled = on
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.wiredShown
            spacing: Theme.space8

            ConnectionSummary {
                Layout.fillWidth: true
                connected: true
                name: Tr.t("Wired")
                icon: "ethernet"
                details: wiredLink.address
            }

            LinkStats { link: wiredLink }

            Rectangle { Layout.fillWidth: true; Layout.topMargin: Theme.space4; visible: !root.wiredOnly; implicitHeight: 1; color: Theme.hairline }
        }

        Label {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space4
            Layout.bottomMargin: Theme.space4
            visible: !root.asking && !root.wiredOnly && root.device !== null && !Networking.wifiEnabled
            horizontalAlignment: Text.AlignHCenter
            color: Theme.overlay1
            text: Tr.t("Off")
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.space4
            Layout.bottomMargin: Theme.space4
            visible: !root.asking && !root.wiredOnly && (root.device === null || (Networking.wifiEnabled && root.networks.length === 0))
            spacing: Theme.space8
            Spinner { visible: root.device !== null; size: 14 }
            Label {
                text: root.device === null ? Tr.t("No adapter") : Tr.t("Scanning…")
                color: Theme.overlay1
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: !root.asking && !root.showHeader && Networking.wifiEnabled && root.connected !== null
            spacing: Theme.space8

            ConnectionSummary {
                Layout.fillWidth: true
                connected: true
                name: root.connected?.name ?? ""
                icon: "wifi"
                iconLevel: Icons.wifiLevel(root.connected?.signalStrength ?? 0)
                level: Icons.signal(root.connected?.signalStrength ?? 0)
                details: [link.band, link.address, root.connected?.security === WifiSecurityType.Open ? Tr.t("Open") : ""].filter(s => s).join("  ·  ")
            }

            LinkStats { link: link }

            Rectangle { Layout.fillWidth: true; Layout.topMargin: Theme.space4; implicitHeight: 1; color: Theme.hairline }
            RowLayout {
                Layout.fillWidth: true
                Caption { Layout.fillWidth: true; text: Tr.t("Nearby") }
                Spinner { visible: root.networks.filter(n => !n.connected).length === 0; size: 12 }
                Label {
                    visible: root.networks.filter(n => !n.connected).length === 0
                    overline: true; color: Theme.overlay0; font.pixelSize: Theme.fontSizeSmall; text: Tr.t("Scanning…")
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 7 * 42)
            visible: !root.asking && !root.wiredOnly && Networking.wifiEnabled && model.length > 0
            clip: true
            spacing: Theme.space2
            boundsBehavior: Flickable.StopAtBounds
            model: root.showHeader ? root.networks : root.networks.filter(n => !n.connected)

            delegate: Item {
                id: slot
                required property var modelData
                width: list.width
                height: 40
            PanelSurface {
                id: row
                readonly property var modelData: slot.modelData
                readonly property bool busy: modelData.stateChanging
                x: content.lane(slot, list)
                width: slot.width - 2 * x
                height: slot.height
                radius: Theme.r(12)
                fill: row.modelData.connected ? Theme.accent
                     : hover.containsMouse ? Theme.hover : "transparent"
                edgeWidth: 0
                Behavior on fill { ColorAnim {} }

                Connections {
                    target: row.modelData
                    function onConnectionFailed(reason) {
                        if (reason === ConnectionFailReason.NoSecrets) {
                            root.pending = row.modelData;
                            root.error = Tr.t("Wrong or missing password");
                            Qt.callLater(() => password.input.forceActiveFocus());
                        } else {
                            root.error = Tr.t("Couldn't connect to this network. Check that it's in range and try again.");
                        }
                    }
                }

                PressArea {
                    label: row.modelData.name
                    id: hover
                    anchors.fill: parent
                    onClicked: root.choose(row.modelData)
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: Theme.space10; rightMargin: Theme.space8 }
                    spacing: Theme.space10

                    Row {
                        id: mini
                        readonly property int lit: Math.max(1, Math.round(Icons.signal(row.modelData.signalStrength) * 5))
                        spacing: Theme.space2
                        Repeater {
                            model: 5
                            Rectangle {
                                required property int index
                                anchors.bottom: parent.bottom
                                width: 4
                                height: 5 + index * 2.5
                                radius: 1.5
                                color: index < mini.lit ? (row.modelData.connected ? Theme.textOnAccent : Theme.text)
                                                        : Theme.alpha(row.modelData.connected ? Theme.textOnAccent : Theme.text, 0.2)
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: row.modelData.connected ? Theme.textOnAccent : Theme.text
                            font.weight: row.modelData.connected ? Font.DemiBold : Font.Normal
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: row.modelData.connected ? Theme.textOnAccent : Theme.overlay1
                            text: row.busy ? (row.modelData.connected ? Tr.t("Disconnecting") : Tr.t("Connecting"))
                                : !row.modelData.connected && row.modelData.known ? Tr.t("Saved") : ""
                        }
                    }

                    Icon {
                        visible: row.modelData.connected && !row.busy
                        name: "check"
                        size: 16
                        color: Theme.textOnAccent
                    }

                    Spinner {
                        visible: row.busy
                        size: 16
                        color: row.modelData.connected ? Theme.textOnAccent : Theme.accent
                    }

                    Icon {
                        visible: !row.busy && !row.modelData.connected && row.modelData.security !== WifiSecurityType.Open
                        name: "lock"
                        size: 14
                        color: Theme.overlay1
                    }

                }
            }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.asking
            spacing: Theme.space14

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space12

                Rectangle {
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: Theme.r(12)
                    color: Theme.accent
                    Icon { anchors.centerIn: parent; name: "lock"; size: 17; color: Theme.textOnAccent }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space2
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                        text: root.pending?.name ?? ""
                    }
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.overlay1
                        text: Tr.t("Type your password")
                    }
                }
            }

            Field {
                id: password
                Layout.fillWidth: true
                secret: true
                canReveal: true
                mono: true
                invalid: root.error !== ""
                placeholder: Tr.t("Password")
                onTextChanged: if (text) root.error = ""
                Keys.onEscapePressed: root.cancelPassword()
                Connections { target: password.input; function onAccepted() { root.submitPassword(); } }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: root.error !== ""
            text: root.error
            wrapMode: Text.Wrap
            color: Theme.error
            font.pixelSize: Theme.fontSizeSmall
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.asking
            spacing: Theme.space8

            Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: Tr.t("Cancel")
                onClicked: root.cancelPassword()
            }
            Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                primary: true
                active: password.text !== ""
                text: Tr.t("Connect")
                onClicked: root.submitPassword()
            }
        }
    }
}
