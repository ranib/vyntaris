import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import "../../components/Slant.js" as Slant
import qs.services

Item {
    id: root
    readonly property real fullWidth: 480
    readonly property real hang: Theme.panelTop - Theme.barHeight + card.height + (Visualizer.wanted ? 14 + 22 : 0) + 18
    readonly property real pad: 12
    function out(y) { return Theme.slanted ? Slant.out(height, Theme.barHeight, y) : 0; }
    readonly property bool active: Panels.mediaOpen

    width: fullWidth
    height: Theme.barHeight + hang

    property var player: Media.active
    Component.onCompleted: if (active) activeChanged()
    onActiveChanged: if (active) player = Media.active

    Timer {
        running: root.active && (root.player?.isPlaying ?? false)
        interval: 500
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    function time(sec) {
        if (!(sec >= 0)) return "--:--";
        const m = Math.floor(sec / 60), s = Math.floor(sec % 60);
        return m + ":" + String(s).padStart(2, "0");
    }

    PanelHeader {
        icon: "music"
        title: root.player?.identity ?? Tr.t("Media")
        Repeater {
            model: Media.players.length > 1 ? Media.players : []
            Rectangle {
                required property var modelData
                implicitWidth: 8; implicitHeight: 8; radius: 4
                color: modelData === root.player ? Theme.accent : Theme.tint(parent, Theme.text, 0.2)
                PressArea { label: modelData.identity ?? ""; anchors.fill: parent; anchors.margins: -4; onClicked: root.player = modelData }
            }
        }
    }

    PanelSurface {
        id: card
        x: Theme.panelInset - root.out(y + height)
        y: Theme.panelTop
        width: parent.width - 2 * Theme.panelInset + 2 * root.out(y + height)
        height: content.implicitHeight + 2 * root.pad
    }

    RowLayout {
        id: content
        x: card.x + root.pad
        y: card.y + root.pad
        width: card.width - 2 * root.pad
        spacing: Theme.space16

        ClippingRectangle {
            implicitWidth: 112
            implicitHeight: 112
            radius: Theme.r(16)
            color: Theme.tint(parent, Theme.text, 0.06)
            border { width: 1; color: Theme.rimOn(parent) }

            Image {
                anchors.fill: parent
                visible: status === Image.Ready
                source: root.player?.trackArtUrl ?? ""
                sourceSize: Qt.size(224, 224)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                visible: !(root.player?.trackArtUrl)
                name: "music"
                size: 36
                stroke: 1.4
                color: Theme.surface2
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space4

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeLarge
                font.weight: root.player?.trackTitle ? Font.DemiBold : Font.Normal
                color: root.player?.trackTitle ? Theme.text : Theme.overlay1
                text: root.player?.trackTitle || Tr.t("Nothing playing")
            }
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: Theme.subtext0
                text: [root.player?.trackArtist, root.player?.trackAlbum].filter(s => s).join(" · ")
            }

            Item {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space8
                implicitHeight: 14
                visible: root.player?.lengthSupported ?? false

                Meter {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    count: 28
                    value: (root.player?.position ?? 0) / Math.max(1, root.player?.length ?? 1)
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.player?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => root.player.position = mouse.x / width * root.player.length
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.player?.lengthSupported ?? false
                Label { mono: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.overlay1; text: root.time(root.player?.position) }
                Item { Layout.fillWidth: true }
                Label { mono: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.overlay1; text: root.time(root.player?.length) }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.space2
                spacing: Theme.space20

                IconButton { size: 34; icon: "previous"; label: Tr.t("Previous"); active: root.player?.canGoPrevious ?? false; onClicked: root.player.previous() }
                IconButton { icon: root.player?.isPlaying ? "pause" : "play"; label: root.player?.isPlaying ? Tr.t("Pause") : Tr.t("Play"); primary: true; size: 44; active: root.player?.canTogglePlaying ?? false; onClicked: root.player.togglePlaying() }
                IconButton { size: 34; icon: "next"; label: Tr.t("Next"); active: root.player?.canGoNext ?? false; onClicked: root.player.next() }
            }
        }
    }

    Bars {
        x: Theme.panelInset - root.out(y + height)
        y: card.y + card.height + 14
        width: parent.width - 2 * Theme.panelInset + 2 * root.out(y + height)
        height: 22
        visible: Visualizer.wanted
        opacity: 0.85
        values: Visualizer.bars
        count: Visualizer.count
        gap: 3
        minimum: 0.1
    }
}
