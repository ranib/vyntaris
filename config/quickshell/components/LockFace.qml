import Quickshell
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.config

Item {
    id: root

    property string user: ""
    property string fullName: ""
    property string face: ""
    property int faceVersion: 0
    property string wallpaper: ""
    property string status: ""
    property string title: Tr.t("Locked")
    property string layoutCode: ""
    property int battery: -1
    property bool charging: false
    property bool showPower: false
    property bool active: true
    property var tr: s => s
    property var dateOf: d => Tr.dates.toString(d, "dddd · d MMMM")
    readonly property string timeFormat: (Config.bar.clockFormat || "HH:mm").replace(":ss", "")

    signal submit(string password)
    signal layoutClicked()
    signal powerClicked(string action)

    property bool showPassword: false
    readonly property bool busy: status === "checking"
    readonly property bool wrong: status === "wrong"

    function t(s) { return root.tr(s); }
    function takeFocus() { input.forceActiveFocus(); }
    function send() {
        if (busy || !input.text) return;
        const pw = input.text;
        input.text = "";
        root.submit(pw);
    }
    onWrongChanged: if (wrong) shake.restart()
    onBusyChanged: if (!busy && !wrong) showPassword = false
    onActiveChanged: if (active) focusTimer.restart()
    Timer { id: focusTimer; interval: 60; running: root.active; onTriggered: input.forceActiveFocus() }
    readonly property bool windowActive: Window.active
    onWindowActiveChanged: if (windowActive && active) focusTimer.restart()
    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.windowActive && root.visible
        onTriggered: if (!input.activeFocus) input.forceActiveFocus()
    }

    Rectangle { anchors.fill: parent; color: Theme.crust }
    CircleReveal {
        id: wallReveal
        anchors.fill: parent
        progress: 0
        clip: true
        BlurredWallpaper {
            anchors.fill: parent
            margin: -48
            source: root.wallpaper ? "file://" + root.wallpaper : ""
            cache: false
            onStatusChanged: if (status === Image.Ready) wallReveal.run()
        }
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    readonly property real islandWidth: Theme.notchWidth
    readonly property real islandHang: Theme.notchDepth
    property real reveal: 0
    NumberAnimation on reveal { running: true; from: 0; to: 1; duration: Theme.durationSlow * 1.4; easing.type: Easing.OutBack; easing.overshoot: 0.8 }

    BarShape {
        anchors.fill: parent
        drawers: [{ center: root.width / 2, width: root.islandWidth, hang: root.islandHang }]
    }

    Row {
        x: 22
        height: Theme.barHeight
        spacing: Theme.space10
        Icon { anchors.verticalCenter: parent.verticalCenter; name: "vyntaris"; size: 18; color: Theme.accentInk }
        Label { anchors.verticalCenter: parent.verticalCenter; overline: true; color: Theme.subtext0; text: root.t(root.title) }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.space24
        height: Theme.barHeight
        spacing: Theme.space16
        Label {
            visible: root.layoutCode !== ""
            anchors.verticalCenter: parent.verticalCenter
            mono: true
            font.weight: Font.DemiBold
            color: Theme.accentInk
            text: root.layoutCode
            PressArea { label: root.t(Tr.t("Keyboard layout")); anchors.fill: parent; anchors.margins: -6; onClicked: root.layoutClicked() }
        }
        Row {
            visible: root.battery >= 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space4
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "battery"
                level: Math.min(7, Math.round(root.battery / 100 * 7))
                size: 22
                filled: true
                color: root.charging ? Theme.accentInk : root.battery <= 15 ? Theme.error : root.battery <= 30 ? Theme.warning : Theme.accentInk
            }
            Icon { visible: root.charging; anchors.verticalCenter: parent.verticalCenter; name: "bolt"; filled: true; size: 13; color: Theme.accentInk }
            Label { anchors.verticalCenter: parent.verticalCenter; mono: true; font.pixelSize: Theme.fontSizeLabel; text: root.battery }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        height: Theme.barHeight + Theme.notchDepth
        spacing: Theme.space8
        opacity: root.reveal
        Label { anchors.verticalCenter: parent.verticalCenter; font.weight: Font.DemiBold; text: Qt.formatDateTime(clock.date, "ddd d MMM") }
        Label { anchors.verticalCenter: parent.verticalCenter; mono: true; font.weight: Font.DemiBold; text: Qt.formatDateTime(clock.date, root.timeFormat) }
    }

    ColumnLayout {
        id: islandContent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: card.top
        anchors.bottomMargin: Theme.space36
        spacing: Theme.space2
        opacity: root.reveal
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, root.timeFormat)
            color: Theme.onWallpaper
            font { family: Theme.monoFamily; pixelSize: 84; weight: Font.Light }
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.alpha("#000000", 0.55); shadowBlur: 0.8; shadowVerticalOffset: 2 }
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            overline: true
            color: Theme.onWallpaper
            text: root.dateOf(clock.date)
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.alpha("#000000", 0.6); shadowBlur: 0.6; shadowVerticalOffset: 1 }
        }
    }

    property real shakeX: 0
    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "shakeX"; to: -14; duration: Theme.paced(50) }
        NumberAnimation { target: root; property: "shakeX"; to: 12; duration: Theme.paced(70) }
        NumberAnimation { target: root; property: "shakeX"; to: -7; duration: Theme.paced(70) }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: Theme.paced(100); easing.type: Easing.OutBack }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: root.shakeX
        y: root.height * 0.56 - height / 2 + (1 - root.reveal) * 40
        opacity: root.reveal
        width: 400
        height: cardColumn.implicitHeight + 44
        radius: Theme.r(20)
        border { width: 1; color: root.wrong ? Theme.tint(parent, Theme.error, 0.6) : Theme.edgeOn(parent) }
        color: Theme.isDark ? Theme.crust : Theme.base
        Behavior on border.color { ColorAnim {} }

        ColumnLayout {
            id: cardColumn
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: Theme.space14

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space12
                Avatar { size: 44; name: root.fullName || root.user; source: root.face; version: root.faceVersion }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { overline: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.accentInk; text: root.t(root.showPower ? Tr.t("Welcome") : Tr.t("Locked")) }
                    Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.DemiBold; text: root.fullName || root.user }
                }
                Icon { name: "lock"; size: 16; color: Theme.overlay1 }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space12

                PasswordCells {
                    id: input
                    Layout.fillWidth: true
                    busy: root.busy
                    wrong: root.wrong
                    reveal: root.showPassword
                    enabled: !root.busy
                    focus: root.active
                    onTextChanged: if (text && root.wrong) root.status = ""
                    onSubmitted: root.send()
                }

                IconButton {
                    icon: root.showPassword ? "eye-off" : "eye"
                    label: root.showPassword ? root.t(Tr.t("Hide password")) : root.t(Tr.t("Show password"))
                    on: root.showPassword
                    onClicked: { root.showPassword = !root.showPassword; input.forceActiveFocus(); }
                }
                IconButton {
                    size: 40
                    primary: true
                    icon: "chevron-right"
                    label: root.t(Tr.t("unlock"))
                    active: !root.busy && input.text !== ""
                    onClicked: root.send()
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: Math.max(statusLabel.implicitHeight, hints.implicitHeight)
                Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width)
                    elide: Text.ElideRight
                    visible: root.status !== ""
                    overline: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.wrong ? Theme.error : Theme.overlay1
                    text: root.wrong ? root.t(Tr.t("Wrong password")) : root.busy ? root.t(Tr.t("Checking…")) : root.status
                }
                KeyHints {
                    id: hints
                    anchors.centerIn: parent
                    visible: root.status === ""
                    keys: [["↵", root.t(Tr.t("unlock"))], ["esc", root.t(Tr.t("clear"))]]
                }
            }
        }
    }

    Row {
        visible: root.showPower
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.space32 }
        spacing: Theme.space10
        Repeater {
            model: [{ id: "reboot", icon: "restart", label: Tr.t("Restart") }, { id: "poweroff", icon: "power", label: Tr.t("Shut down") }]
            Button {
                radius: Theme.r(12)
                required property var modelData
                icon: modelData.icon
                text: root.t(modelData.label)
                onClicked: root.powerClicked(modelData.id)
            }
        }
    }
}
