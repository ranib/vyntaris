import QtQuick
import qs.config

PanelSurface {
    id: root
    property alias text: field.text
    property string placeholder: Tr.t("Search…")
    // How many results, in a pill on the right like the apps' search; below 0 it isn't shown.
    property int count: -1
    readonly property alias input: field
    signal accepted()

    implicitWidth: 240
    implicitHeight: Theme.controlHeight
    radius: Theme.r(height / 2)
    fill: Theme.mantle
    edgeWidth: field.activeFocus ? 2 : 1; edge: field.activeFocus ? Theme.accentInk : Theme.controlEdge
    Behavior on edge { ColorAnim {} }

    Rectangle {
        id: disc
        anchors { left: parent.left; leftMargin: Theme.space6; verticalCenter: parent.verticalCenter }
        width: parent.height - 10
        height: width
        radius: width / 2
        color: Theme.accent
        Icon { anchors.centerIn: parent; name: "search"; size: 16; color: Theme.textOnAccent }
    }
    Rectangle {
        id: badge
        visible: root.count >= 0
        anchors { right: parent.right; rightMargin: Theme.space6; verticalCenter: parent.verticalCenter }
        width: Math.max(disc.width, countText.implicitWidth + 16)
        height: disc.height
        radius: Theme.r(height / 2)
        color: Theme.accent
        Label {
            id: countText
            anchors.centerIn: parent
            mono: true
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.textOnAccent
            text: root.count
        }
    }
    TextInput {
        id: field
        activeFocusOnTab: true
        Keys.forwardTo: [root]
        Accessible.role: Accessible.EditableText
        Accessible.name: root.placeholder
        anchors { left: disc.right; leftMargin: Theme.space12; right: badge.visible ? badge.left : parent.right; rightMargin: badge.visible ? Theme.space12 : Theme.space16; verticalCenter: parent.verticalCenter }
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.textOnAccent
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeMedium }
        clip: true
        onAccepted: root.accepted()
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: !field.text
            color: Theme.overlay0
            text: root.placeholder
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: field.forceActiveFocus(); z: -1 }
}
