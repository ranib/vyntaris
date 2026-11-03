import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Rectangle {
    id: root
    property var player: Media.active
    property int artSize: 64
    readonly property bool playing: player !== null && (player.trackTitle ?? "") !== ""

    implicitWidth: 380
    implicitHeight: artSize + 24
    radius: Theme.r(20)
    color: Theme.tint(parent, Theme.crust, 0.6)
    border { width: 1; color: Theme.rimOn(parent) }

    RowLayout {
        anchors { fill: parent; margins: Theme.space12 }
        spacing: Theme.space14

        ClippingRectangle {
            implicitWidth: root.artSize
            implicitHeight: root.artSize
            radius: Theme.r(12)
            color: Theme.tint(parent, Theme.text, 0.08)
            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Icon { anchors.centerIn: parent; visible: !(root.player?.trackArtUrl); name: "music"; size: root.artSize * 0.38; color: Theme.surface2 }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space2
            Label { Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.DemiBold; text: root.player?.trackTitle ?? "" }
            Label { Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.subtext0; font.pixelSize: Theme.fontSizeSmall; text: root.player?.trackArtist ?? "" }
            RowLayout {
                Layout.topMargin: Theme.space2
                spacing: Theme.space4
                IconButton { size: 30; icon: "previous"; label: Tr.t("Previous"); onClicked: Media.previous() }
                IconButton { size: 34; primary: true; icon: root.player?.isPlaying ? "pause" : "play"; label: root.player?.isPlaying ? Tr.t("Pause") : Tr.t("Play"); onClicked: Media.toggle() }
                IconButton { size: 30; icon: "next"; label: Tr.t("Next"); onClicked: Media.next() }
            }
        }
    }
}
