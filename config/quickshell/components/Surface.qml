import QtQuick
import qs.config

Rectangle {
    id: surface
    property color tint: "transparent"
    // Painted by the gradient, which is the glass all the way down.
    readonly property color ground: Theme.glass

    radius: Theme.r(Theme.radius)
    // No rim: it sits over the wallpaper, where a see-through one barely showed and a solid one would draw a line.
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
