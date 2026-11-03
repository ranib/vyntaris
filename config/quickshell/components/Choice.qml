import QtQuick
import qs.config

Item {
    id: root
    property var options: []
    property var current
    // Every option the same share of a width given from outside, instead of just wide enough for its word.
    property bool stretch: false
    property string label: {
        for (let p = parent; p; p = p.parent)
            if (p.isOption === true) return p.title;
        return "";
    }
    signal picked(var value)

    function shift(by) {
        const next = (Math.max(0, index) + by + options.length) % options.length;
        if (options.length > 0) picked(options[next].value);
    }
    activeFocusOnTab: enabled
    Keys.onLeftPressed: shift(-1)
    Keys.onUpPressed: shift(-1)
    Keys.onRightPressed: shift(1)
    Keys.onDownPressed: shift(1)
    Accessible.role: Accessible.List
    Accessible.name: label
    Accessible.description: options[index]?.label ?? ""
    Accessible.focusable: true
    Accessible.focused: activeFocus
    FocusRing { ringRadius: Theme.r(height / 2) }
    opacity: enabled ? 1 : Theme.disabledOpacity

    readonly property int index: options.findIndex(o => o.value === current)

    implicitWidth: stretch ? 0 : row.implicitWidth + 6
    implicitHeight: Theme.controlHeight

    // Plain shapes, not slanted ones: the part chosen has to sit evenly inside the whole.
    Rectangle {
        anchors.fill: parent
        radius: Theme.r(height / 2)
        color: Theme.tint(parent, Theme.crust, 0.45)
        border { width: 1; color: Theme.rimOn(parent) }
    }

    Rectangle {
        readonly property Item target: root.index >= 0 && optionRepeater.count > root.index ? optionRepeater.itemAt(root.index) : null
        visible: target !== null
        x: 3 + (target?.x ?? 0)
        y: 3
        width: target?.width ?? 0
        height: parent.height - 6
        radius: Theme.r(height / 2)
        color: Theme.accent
        Behavior on x { Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring } }
        Behavior on width { Anim { duration: Theme.durationNormal } }
    }

    Row {
        id: row
        x: 3
        height: parent.height

        Repeater {
            id: optionRepeater
            model: root.options
            Item {
                required property var modelData
                required property int index
                width: root.stretch ? (root.width - 6) / Math.max(1, root.options.length) : optLabel.implicitWidth + 28
                height: row.height
                Label {
                    id: optLabel
                    anchors.centerIn: parent
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: root.index === index ? Font.DemiBold : Font.Normal
                    color: root.index === index ? Theme.textOnAccent : optArea.containsMouse ? Theme.text : Theme.subtext0
                    text: modelData.label
                }
                MouseArea {
                    id: optArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData.value)
                }
            }
        }
    }
}
