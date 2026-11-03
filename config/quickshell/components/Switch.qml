import QtQuick
import qs.config

Rectangle {
    id: root
    property bool checked: false
    property string label: {
        for (let p = parent; p; p = p.parent)
            if (p.isOption === true) return p.title;
        return "";
    }
    signal toggled(bool on)

    implicitWidth: 42
    implicitHeight: 24
    radius: Theme.r(height / 2)
    opacity: enabled ? 1 : Theme.disabledOpacity
    color: checked ? (area.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                   : Theme.tint(parent, Theme.text, area.containsMouse ? 0.2 : 0.12)
    border { width: 1; color: checked ? Theme.accent : Theme.controlEdge }
    Behavior on color { ColorAnim {} }

    Rectangle {
        width: 18; height: 18; radius: Theme.r(10)
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.textOnAccent : Theme.controlEdge
        Behavior on x { Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring } }
    }

    PressArea {
        id: area
        anchors.fill: parent
        label: root.label
        role: Accessible.CheckBox
        checked: root.checked
        onClicked: root.toggled(!root.checked)
    }
}
