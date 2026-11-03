import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.config

ClippingRectangle {
    id: root
    property string image
    property string appIcon
    property color tint: Theme.accent
    property int size: 40

    property string appName: ""
    readonly property string iconName: {
        if (appIcon) return appIcon;
        const m = image.match(/^image:\/\/icon\/(.+)$/);
        if (m && !m[1].startsWith("/")) return m[1];
        return appName ? DesktopEntries.heuristicLookup(appName)?.icon ?? "" : "";
    }
    readonly property string iconPath: !iconName ? "" : iconName.startsWith("/") ? "file://" + iconName : Quickshell.iconPath(iconName, true)
    readonly property string pictureSource: {
        const m = image.match(/^image:\/\/icon\/(\/.+)$/);
        if (m) return "file://" + m[1];
        return image.startsWith("image://icon/") ? "" : image;
    }
    readonly property bool hasImage: pictureSource !== "" && picture.status !== Image.Error

    implicitWidth: size
    implicitHeight: size
    radius: size * 0.3
    color: hasImage ? "transparent" : Theme.tint(parent, tint, 0.16)

    Image {
        id: picture
        anchors.fill: parent
        visible: root.hasImage
        source: root.pictureSource
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    IconImage {
        anchors.centerIn: parent
        implicitSize: root.size * 0.6
        visible: !root.hasImage && root.iconPath !== ""
        source: root.iconPath
    }
    Icon {
        anchors.centerIn: parent
        visible: !root.hasImage && root.iconPath === ""
        name: "bell"
        size: root.size * 0.45
        color: Theme.ink(root.tint)
    }
}
