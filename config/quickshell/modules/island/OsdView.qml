import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    readonly property real fullWidth: 380
    readonly property var view: Osd.view
    readonly property bool toggle: view.toggle === true
    readonly property real hang: toggle ? 8 : 50

    width: fullWidth
    height: Theme.barHeight + hang

    Connections {
        target: Osd
        function onKindChanged() { swapAnim.restart(); }
    }
    transform: Translate { id: shift }
    SequentialAnimation {
        id: swapAnim
        PropertyAction { target: shift; property: "y"; value: -8 }
        Anim { target: shift; property: "y"; to: 0; easing.bezierCurve: Theme.curveDecelerate }
    }

    Item {
        anchors { fill: parent; leftMargin: Theme.space24; rightMargin: Theme.space24 }

        RowLayout {
            width: parent.width
            height: Theme.barHeight + 4
            spacing: Theme.space10

            Icon {
                name: root.view.icon
                level: root.view.level
                size: 18
                color: root.view.dimmed ? Theme.overlay1 : Theme.accentInk
            }
            Label {
                Layout.fillWidth: true
                overline: true
                color: root.view.dimmed ? Theme.overlay1 : Theme.accentInk
                text: root.view.label
            }
            Label {
                visible: root.view.value >= 0 || root.toggle
                mono: true
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Font.DemiBold
                color: root.view.dimmed ? Theme.overlay1 : Theme.text
                text: root.view.text
            }
        }

        Item {
            visible: !root.toggle
            y: Theme.panelTop
            width: parent.width
            height: 34

            Row {
                id: segments
                visible: root.view.value >= 0
                anchors.verticalCenter: parent.verticalCenter
                readonly property int count: 24
                readonly property int lit: Math.round(Math.max(0, Math.min(1, root.view.value)) * count)
                spacing: Theme.space4

                Repeater {
                    model: segments.count
                    Rectangle {
                        required property int index
                        readonly property bool on: index < segments.lit
                        width: (root.fullWidth - 44 - (segments.count - 1) * segments.spacing) / segments.count
                        height: on ? 10 : 6
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 2
                        color: !on ? Theme.tint(parent, Theme.text, 0.1)
                            : root.view.dimmed ? Theme.overlay0
                            : index === segments.lit - 1 ? Theme.accentBright : Theme.accent
                        Behavior on height { Anim { duration: Theme.durationFast } }
                        Behavior on color { ColorAnim {} }
                    }
                }
            }

            ColumnLayout {
                visible: root.view.value < 0
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                    text: root.view.text
                }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    elide: Text.ElideRight
                    color: Theme.subtext0
                    font.pixelSize: Theme.fontSizeSmall
                    text: root.view.sub
                }
            }
        }
    }
}
