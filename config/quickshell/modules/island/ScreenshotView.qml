import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    readonly property real fullWidth: 570
    readonly property real hang: content.implicitHeight + 26

    width: fullWidth
    height: Theme.barHeight + hang

    HoverHandler { onHoveredChanged: Screenshot.keepOpen(hovered) }

    PanelHeader {
        icon: "image"
        title: Tr.t("Screenshot")
        Icon { name: "check"; size: 13; stroke: 2.2; color: Theme.accentInk }
        Label { overline: true; color: Theme.accentInk; text: Tr.t("Copied") }
        HeaderButton { icon: "close"; label: Tr.t("Close"); onClicked: Screenshot.dismiss() }
    }

    PanelBody {
        id: content

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space14

            ClippingRectangle {
                implicitWidth: 152
                implicitHeight: 86
                radius: Theme.r(12)
                color: Theme.tint(parent, Theme.text, 0.06)
                Image {
                    anchors.fill: parent
                    source: Screenshot.lastPath ? "file://" + Screenshot.lastPath : ""
                    sourceSize: Qt.size(304, 172)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Screenshot.open() }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space8

                Field {
                    Layout.fillWidth: true
                    mono: true
                    text: Screenshot.lastPath.split("/").pop().replace(/\.png$/i, "")
                    onCommitted: t => Screenshot.rename(t)
                    onActiveFocusChanged: Screenshot.keepOpen(activeFocus)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space6
                    Button { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "image"; text: Tr.t("Edit"); onClicked: Screenshot.editShot() }
                    Button { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "external"; text: Tr.t("Open"); onClicked: Screenshot.open() }
                    Button { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "folder"; text: Tr.t("Folder"); onClicked: Screenshot.openFolder() }
                    Button { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "trash"; text: Tr.t("Trash"); danger: true; onClicked: Screenshot.remove() }
                }
            }
        }
    }
}
