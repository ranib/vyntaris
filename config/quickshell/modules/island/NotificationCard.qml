import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

Item {
    id: root
    required property var entry
    property int stacked: 0
    property int more: 0
    property string ago: ""
    signal dismissed()
    signal clicked()

    readonly property bool critical: entry.urgency === NotificationUrgency.Critical
    readonly property color tint: critical ? Theme.error : Theme.accent
    readonly property string image: entry.image ?? ""
    readonly property string iconName: {
        if (entry.appIcon) return entry.appIcon;
        const m = image.match(/^image:\/\/icon\/(.+)$/);
        if (m && !m[1].startsWith("/")) return m[1];
        return DesktopEntries.heuristicLookup(entry.appName || "")?.icon ?? "";
    }
    readonly property string iconPath: !iconName ? "" : iconName.startsWith("/") ? "file://" + iconName : Quickshell.iconPath(iconName, true)
    readonly property string picture: {
        const m = image.match(/^image:\/\/icon\/(\/.+)$/);
        if (m) return "file://" + m[1];
        return image.startsWith("image://icon/") ? "" : image;
    }

    implicitHeight: card.height + stacked * 6

    Repeater {
        model: root.stacked
        Item {
            required property int index
            z: -1 - index
            x: (index + 1) * 10 + card.offset
            y: card.height
            width: card.width - (index + 1) * 20
            height: (index + 1) * 6
            clip: true
            opacity: card.opacity
            Rectangle {
                y: parent.height - height
                width: parent.width
                height: card.radius * 2
                radius: card.radius
                color: Theme.tint(parent, Theme.text, 0.05 - index * 0.015)
                border { width: 1; color: Theme.tint(parent, Theme.text, 0.08 - index * 0.03) }
            }
        }
    }

    Rectangle {
        id: card
        property real offset: 0
        x: offset
        width: root.width
        height: body.implicitHeight + 22
        radius: Theme.r(16)
        opacity: 1 - Math.min(1, Math.abs(offset) / width) * 0.9
        readonly property color fill: hover.hovered ? Theme.tint(parent, Theme.text, 0.075) : Theme.tint(parent, Theme.text, 0.045)
        readonly property color edge: root.critical ? Theme.tint(parent, Theme.error, 0.5) : hover.hovered ? Theme.tint(parent, Theme.accent, 0.3) : Theme.rimOn(parent)
        color: cardSlant.on ? "transparent" : fill
        border { width: cardSlant.on ? 0 : 1; color: edge }
        Slanted { id: cardSlant; fill: card.fill; stroke: card.edge; radius: card.radius }
        Behavior on color { ColorAnim {} }


        HoverHandler { id: hover }
        TapHandler { onTapped: root.clicked() }
        DragHandler {
            id: drag
            target: null
            yAxis.enabled: false
            onTranslationChanged: card.offset = translation.x
            onActiveChanged: if (!active) (Math.abs(card.offset) > card.width * 0.32 ? away : back).start()
        }
        NumberAnimation { id: back; target: card; property: "offset"; to: 0; duration: Theme.durationNormal; easing.type: Easing.OutCubic }
        SequentialAnimation {
            id: away
            NumberAnimation { target: card; property: "offset"; to: card.offset > 0 ? card.width : -card.width; duration: Theme.durationFast; easing.type: Easing.InCubic }
            ScriptAction { script: root.dismissed() }
        }

        RowLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.space12; leftMargin: Theme.space12; rightMargin: Theme.space12 }
            spacing: Theme.space12

            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 36
                implicitHeight: 36
                radius: 18
                color: root.tint
                AppIcon {
                    anchors.centerIn: parent
                    visible: root.iconPath !== ""
                    implicitSize: 20
                    source: root.iconPath
                    tint: root.tint
                }
                Icon {
                    anchors.centerIn: parent
                    visible: root.iconPath === ""
                    name: root.critical ? "alert" : "bell"
                    size: 16
                    color: Theme.on(root.tint)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space6
                    Label {
                        Layout.maximumWidth: 180
                        overline: true
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.critical ? Theme.error : Theme.overlay1
                        text: (root.critical ? Tr.t("Critical") + " · " : "") + (root.entry.appName || Tr.t("System"))
                    }
                    Rectangle { implicitWidth: 3; implicitHeight: 3; radius: 1.5; color: Theme.overlay0 }
                    Label { font.pixelSize: Theme.fontSizeSmall; color: Theme.overlay0; text: root.ago }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        visible: root.more > 0
                        implicitWidth: moreText.implicitWidth + 14
                        implicitHeight: 18
                        radius: Theme.r(10)
                        color: Theme.accent
                        Label { id: moreText; anchors.centerIn: parent; mono: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.textOnAccent; text: "+" + root.more }
                    }
                    Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: 10
                        opacity: hover.hovered || closeArea.activeFocus ? 1 : 0
                        Behavior on opacity { Anim { duration: Theme.durationFast } }
                        color: closeArea.containsMouse ? Theme.tint(parent, Theme.error, 0.2) : Theme.tint(parent, Theme.text, 0.07)
                        Icon { anchors.centerIn: parent; name: "close"; size: 10; stroke: 2.2; color: closeArea.containsMouse ? Theme.error : Theme.subtext0 }
                        PressArea { label: Tr.t("Dismiss"); id: closeArea; anchors.fill: parent; anchors.margins: -4; onClicked: away.start() }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                    font.pixelSize: Theme.fontSizeLabel
                    text: root.entry.summary
                }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    linkColor: Theme.accent
                    color: Theme.subtext0
                    font.pixelSize: Theme.fontSizeSmall
                    text: root.entry.body
                }
            }

            ClippingRectangle {
                Layout.alignment: Qt.AlignTop
                visible: root.picture !== "" && picture.status !== Image.Error
                implicitWidth: 46
                implicitHeight: 46
                radius: Theme.r(12)
                color: Theme.tint(parent, Theme.text, 0.06)
                Image {
                    id: picture
                    anchors.fill: parent
                    source: root.picture
                    sourceSize: Qt.size(92, 92)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }
    }
}
