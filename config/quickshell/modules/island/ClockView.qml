import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    readonly property real fullWidth: Math.max(Theme.notchWidth, row.implicitWidth + 36)
    readonly property real hang: Theme.notchDepth

    readonly property var activity: Activities.items[0] ?? null
    readonly property int more: Math.max(0, Activities.items.length - 1)

    width: fullWidth
    height: Theme.barHeight + hang

    SystemClock { id: clock; precision: Config.bar.clockFormat.includes("ss") ? SystemClock.Seconds : SystemClock.Minutes }

    function openActivity() {
        const kind = activity?.kind;
        if (kind === "timer" || kind === "stopwatch") { Panels.timerTab = kind; Panels.timerOpen = true; }
        else if (kind === "download") Activities.openDownloads();
        else if (kind === "packages") Panels.packagesOpen = true;
        else if (kind === "backup") Panels.cloudOpen = true;
        else Panels.controlOpen = true;
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.controlOpen = !Panels.controlOpen
    }

    RowLayout {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        y: (Theme.barHeight + Theme.notchDepth - height) / 2
        spacing: Theme.space8

        Label {
            visible: Config.bar.clockShow !== "time"
            font.weight: Font.DemiBold
            text: Tr.dates.toString(clock.date, "ddd d MMM")
        }
        Label {
            visible: Config.bar.clockShow !== "date"
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            text: Qt.formatDateTime(clock.date, Config.bar.clockFormat)
        }

        Bars {
            visible: Visualizer.wanted
            Layout.leftMargin: Theme.space2
            implicitWidth: 22
            implicitHeight: 14
            values: Visualizer.group(5)
            count: 5
            gap: 2.5
            minimum: 0.18
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Panels.mediaOpen = true }
        }

        Icon {
            visible: Notifications.dnd
            name: "bell-off"
            size: 12
            color: Theme.overlay1
        }
        Rectangle {
            visible: !Notifications.dnd && Notifications.unread > 0
            implicitWidth: 6
            implicitHeight: 6
            radius: 3
            color: Theme.accent
        }

        Item {
            visible: root.activity !== null
            Layout.leftMargin: Theme.space4
            implicitWidth: 16; implicitHeight: 16
            Ring {
                anchors.fill: parent
                visible: (root.activity?.progress ?? -1) >= 0
                value: Math.max(0, root.activity?.progress ?? 0)
                thickness: 2
            }
            Icon {
                anchors.centerIn: parent
                name: root.activity?.icon ?? ""
                size: (root.activity?.progress ?? -1) >= 0 ? 9 : 13
                color: Theme.ink(root.activity?.color ?? Theme.accent)
            }
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.openActivity() }
        }
        Label {
            id: activityText
            visible: root.activity !== null
            Layout.leftMargin: Theme.space4
            Layout.maximumWidth: 120
            elide: Text.ElideRight
            mono: true
            font.weight: Font.DemiBold
            color: root.activity?.paused ? Theme.overlay1 : (root.activity?.color ? Theme.ink(root.activity.color) : Theme.text)
            text: root.activity?.text ?? ""
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.openActivity() }
        }
        Label {
            visible: root.more > 0
            mono: true
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.overlay1
            text: "+" + root.more
        }
    }
}
