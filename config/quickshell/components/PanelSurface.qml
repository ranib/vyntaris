import QtQuick
import qs.config

Rectangle {
    id: root
    property color fill: "transparent"
    property color edge: "transparent"
    property real edgeWidth: 0
    readonly property alias slanted: slant.on
    // Slanted, the fill is drawn by the shape and `color` is clear, so what is on it tints over `fill`.
    readonly property color ground: fill
    color: slant.on ? "transparent" : fill
    border { width: slant.on ? 0 : edgeWidth; color: edge }
    Slanted { id: slant; fill: root.fill; stroke: root.edge; strokeWidth: root.edgeWidth; radius: root.radius }
}
