import QtQuick
import qs.config

Item {
    id: root
    property real value: 0
    property color fillColor: Theme.accent
    property bool dimmed: false
    property int count: Math.max(8, Math.round(width / 9))
    // From this share of the bar on it shows in the warning colour: the part past what is safe.
    property real caution: 1
    property string label: {
        for (let p = parent; p; p = p.parent)
            if (p.isOption === true) return p.title;
        return "";
    }
    readonly property real step: 0.05
    signal moved(real v)

    function nudge(by) { moved(Math.max(0, Math.min(1, value + by))); }
    activeFocusOnTab: enabled
    Keys.onLeftPressed: nudge(-step)
    Keys.onDownPressed: nudge(-step)
    Keys.onRightPressed: nudge(step)
    Keys.onUpPressed: nudge(step)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) { moved(0); event.accepted = true; }
        else if (event.key === Qt.Key_End) { moved(1); event.accepted = true; }
    }
    Accessible.role: Accessible.Slider
    Accessible.name: label
    Accessible.focusable: true
    Accessible.focused: activeFocus
    Accessible.description: Math.round(shown * 100) + "%"
    opacity: enabled ? 1 : Theme.disabledOpacity
    FocusRing { anchors.margins: -3; ringRadius: 5 }

    implicitWidth: 120
    implicitHeight: 16

    readonly property real shown: Math.max(0, Math.min(1, area.pressed ? area.dragValue : value))
    readonly property int lit: Math.round(shown * count)

    Row {
        id: cells
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space4
        Repeater {
            model: root.count
            Rectangle {
                required property int index
                readonly property bool on: index < root.lit
                width: (root.width - (root.count - 1) * cells.spacing) / root.count
                height: on ? 12 : 6
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: !on ? (area.containsMouse ? Theme.trackOffHover : Theme.trackOff)
                    : root.dimmed ? Theme.overlay0
                    : index >= Math.round(root.caution * root.count) ? Theme.warning
                    : index === root.lit - 1 ? Theme.accentBright : root.fillColor
                Behavior on height { Anim { duration: Theme.durationFast } }
                Behavior on color { ColorAnim {} }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property real dragValue: 0

        function update(mouse) {
            dragValue = Math.max(0, Math.min(1, mouse.x / root.width));
            root.moved(dragValue);
        }
        onPressed: mouse => update(mouse)
        onPositionChanged: mouse => { if (pressed) update(mouse); }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
