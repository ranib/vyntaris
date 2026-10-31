import QtQuick
import QtQuick.Effects
import qs.config

Item {
    id: root
    property url source
    property real blur: 1
    property real blurMultiplier: 0.6
    property color veil: Theme.wallpaperVeil
    property real margin: 0
    property alias cache: wall.cache
    readonly property alias status: wall.status

    Image {
        id: wall
        anchors.fill: parent
        anchors.margins: root.margin
        source: root.source
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: width
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: wall
        source: wall
        visible: wall.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blur: root.blur
        blurMax: 64
        blurMultiplier: root.blurMultiplier
    }
    Rectangle { anchors.fill: parent; color: root.veil }
}
