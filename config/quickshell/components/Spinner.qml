import QtQuick
import QtQuick.Shapes
import qs.config

Item {
    id: root
    property real size: 16
    property color color: Theme.accent
    readonly property real thickness: Math.max(1.5, size / 8)
    property bool settled: false

    implicitWidth: size
    implicitHeight: size
    opacity: settled ? 1 : 0
    Behavior on opacity { Anim { duration: Theme.durationFast } }

    onVisibleChanged: { settled = false; if (visible) settle.restart(); }
    Component.onCompleted: if (visible) settle.restart()
    Timer { id: settle; interval: 150; onTriggered: root.settled = true }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.tint(parent, root.color, 0.25)
            strokeWidth: root.thickness
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: (root.size - root.thickness) / 2; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }
    }
    Shape {
        id: arc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: (root.size - root.thickness) / 2; radiusY: radiusX
                startAngle: -90; sweepAngle: 100
            }
        }
        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: root.visible && Theme.speed > 0
        }
    }
}
