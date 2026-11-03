import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    readonly property real fullWidth: 380
    readonly property real hang: 46
    readonly property var view: Activities.current ?? { icon: "", title: "", sub: "", progress: -1, color: Theme.accent }

    width: fullWidth
    height: Theme.barHeight + hang

    RowLayout {
        anchors { left: parent.left; right: parent.right; leftMargin: Theme.space24; rightMargin: Theme.space24 }
        y: (Theme.barHeight + root.hang - height) / 2 - 2
        spacing: Theme.space14

        Rectangle {
            implicitWidth: 40; implicitHeight: 40; radius: 20
            color: Theme.tint(parent, root.view.color, 0.18)
            Icon { anchors.centerIn: parent; name: root.view.icon; size: 20; color: Theme.ink(root.view.color) }
            scale: Activities.shown ? 1 : 0.5
            Behavior on scale { Anim { duration: Theme.durationSlow; easing.bezierCurve: Theme.curveSpring } }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space4
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                text: root.view.title
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                elide: Text.ElideMiddle
                color: Theme.subtext0
                font.pixelSize: Theme.fontSizeSmall
                text: root.view.sub
            }
            Meter {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space2
                visible: root.view.progress >= 0
                value: root.view.progress
                fillColor: root.view.color
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Activities.dismiss()
    }
}
