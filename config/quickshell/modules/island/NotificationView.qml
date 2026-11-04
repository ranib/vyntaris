import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import "../../components/Slant.js" as Slant
import qs.services

Item {
    id: root
    readonly property var n: Notifications.current
    readonly property real fullWidth: 440
    readonly property real hang: body.implicitHeight + (critical ? 22 : 38)
    function out(y) { return Theme.slanted ? Slant.out(height, Theme.barHeight, y) : 0; }

    readonly property bool critical: n?.urgency === NotificationUrgency.Critical
    readonly property color tint: critical ? Theme.error : Theme.accent
    readonly property real timeout: {
        const t = n?.expireTimeout ?? 0;
        return t <= 0 ? Config.notifications.timeout : (t < 1000 ? t * 1000 : t);
    }

    width: fullWidth
    height: Theme.barHeight + hang

    property real remaining: 1
    onNChanged: {
        life.stop();
        remaining = 1;
        if (n && !critical) life.start();
        swapAnim.restart();
    }
    NumberAnimation {
        id: life
        target: root
        property: "remaining"
        from: 1; to: 0
        duration: root.timeout
        paused: running && hover.containsMouse
        onFinished: root.n?.expire()
    }

    transform: Translate { id: shift }
    SequentialAnimation {
        id: swapAnim
        PropertyAction { target: shift; property: "y"; value: -10 }
        Anim { target: shift; property: "y"; to: 0; easing.bezierCurve: Theme.curveDecelerate }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            const def = (root.n?.actions ?? []).find(a => a.identifier === "default");
            if (mouse.button !== Qt.LeftButton) { root.n?.dismiss(); return; }
            // The app is told (Discord opens the conversation), and its window comes forward, which it can't do itself.
            const app = [root.n?.desktopEntry, root.n?.appName];
            if (def) def.invoke(); else root.n?.dismiss();
            Notifications.focusApp(app[0], app[1]);
        }
    }

    PanelHeader {
        icon: root.critical ? "alert" : "bell"
        title: (root.critical ? Tr.t("Critical") + " · " : "") + (root.n?.appName || Tr.t("System"))
        tint: root.tint
        Label {
            visible: Notifications.waiting > 0
            mono: true
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.overlay1
            text: "+" + Notifications.waiting
        }
        HeaderButton { icon: "close"; label: Tr.t("Dismiss"); onClicked: root.n?.dismiss() }
    }

    RowLayout {
        id: body
        x: 22 - root.out(y + height)
        y: Theme.barHeight + 4
        width: parent.width - 44 + 2 * root.out(y + height)
        spacing: Theme.space14

        NotificationIcon {
            Layout.alignment: Qt.AlignTop
            image: root.n?.image ?? ""
            appIcon: root.n?.appIcon ?? ""
            appName: root.n?.appName ?? ""
            tint: root.tint
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space4

            Label {
                Layout.fillWidth: true
                text: root.n?.summary ?? ""
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.weight: Font.DemiBold
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.n?.body ?? ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: Theme.subtext0
                linkColor: Theme.accent
                font.pixelSize: Theme.fontSizeLabel
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space6
                spacing: Theme.space6
                visible: actions.count > 0
                Repeater {
                    id: actions
                    model: (root.n?.actions ?? []).filter(a => a.identifier !== "default")
                    ChipButton {
                        required property var modelData
                        danger: root.critical
                        text: modelData.text
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }

    Meter {
        visible: !root.critical
        x: 22 - root.out(y + height)
        anchors { bottom: parent.bottom; bottomMargin: Theme.space12 }
        width: root.fullWidth - 44 + 2 * root.out(y + height)
        height: 6
        count: 36
        value: root.remaining
        fillColor: root.tint
    }
}
