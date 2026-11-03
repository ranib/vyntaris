import QtQuick
import qs.config

Rectangle {
    id: surface
    property color tint: "transparent"

    radius: Theme.r(Theme.radius)
    border { width: 1; color: Theme.edgeOn(parent) }
    gradient: Gradient {
        GradientStop { position: 0; color: Theme.glassTop }
        GradientStop { position: 1; color: Theme.glass }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: surface.tint
        Behavior on color { ColorAnim {} }
    }
}
