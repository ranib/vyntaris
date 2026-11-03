import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config

// A chooser that drops down from the button it belongs to, over the page, rather than opening the page up under its
// row: under the button, or over it where there's no room below. Escape, a click outside or a pick closes it, and
// `closed` says so. `shown` opens and closes it from outside.
Popup {
    id: root
    property Item anchor: null
    property bool shown: false
    property real preferredWidth: 340
    default property alias content: body.data
    readonly property real gap: Theme.space6

    parent: anchor
    width: Math.max(preferredWidth, anchor ? anchor.width : 0)
    x: anchor ? anchor.width - width : 0
    padding: Theme.space8
    margins: Theme.space12
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    onShownChanged: shown ? open() : close()
    // It unrolls from the button: grows down from under it (up, when it opens over it), its content uncovered as it goes.
    property real reveal: 0
    property bool upward: false
    property real edge: 0
    height: Math.round(implicitHeight * reveal)
    y: upward ? edge - height : edge
    clip: true
    onAboutToShow: {
        if (!anchor) return;
        // Under the button, its right edge with the button's, unless that runs off the window: then over it.
        const below = anchor.mapToItem(null, 0, anchor.height).y;
        const room = anchor.Window.window ? anchor.Window.window.height - below : 1e6;
        upward = room < implicitHeight + gap + margins;
        edge = upward ? -gap : anchor.height + gap;
    }

    background: Rectangle {
        id: bg
        radius: Theme.r(14)
        // Solid, a step up from the cards it opens over.
        color: Theme.isDark ? Theme.surface0 : Theme.base
        border { width: 1; color: Theme.surface1 }
    }
    // The content keeps its own height while the dropdown unrolls over it, so it's uncovered, not squeezed.
    contentItem: Item {
        implicitWidth: body.implicitWidth
        implicitHeight: body.implicitHeight
        clip: true
        ColumnLayout {
            id: body
            // What's in it tints over the dropdown, which isn't an item above it.
            readonly property color ground: bg.color
            width: parent.width
            height: implicitHeight
            y: root.upward ? parent.height - height : 0
            spacing: Theme.space8
        }
    }

    enter: Transition {
        NumberAnimation { property: "reveal"; from: 0; to: 1; duration: Theme.durationNormal; easing.bezierCurve: Theme.curvePanelIn }
    }
    exit: Transition {
        NumberAnimation { property: "reveal"; from: 1; to: 0; duration: Theme.durationFast; easing.bezierCurve: Theme.curvePanelOut }
    }
}
