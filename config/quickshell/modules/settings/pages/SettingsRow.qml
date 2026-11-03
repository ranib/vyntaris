import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// One setting. Rows next to each other on a page share a card, split by thin lines; anything else
// between them (a section title, a note, a picker) starts a new card.
Item {
    id: r
    property string title
    readonly property bool isOption: true
    readonly property bool isCardRow: true
    property real flash: 0
    SequentialAnimation on flash {
        id: flashAnim
        running: false
        NumberAnimation { to: 1; duration: Theme.paced(180) }
        PauseAnimation { duration: Theme.paced(900) }
        NumberAnimation { to: 0; duration: Theme.paced(700) }
    }
    function highlight() { flashAnim.restart(); }
    default property alias control: slot.data

    // The nearest shown sibling either way, past Repeaters (they're items, but draw nothing themselves).
    function neighbour(step) {
        const kids = parent ? parent.children : [];
        for (let i = kids.indexOf(r) + step; i >= 0 && i < kids.length; i += step) {
            const k = kids[i];
            if (k.delegate !== undefined && k.model !== undefined) continue;
            if (k.visible) return k;
        }
        return null;
    }
    readonly property bool first: { const n = neighbour(-1); return !(n && n.isCardRow === true); }
    readonly property bool last: { const n = neighbour(1); return !(n && n.isCardRow === true); }

    Layout.fillWidth: true
    // Cards touch: the page's spacing is taken back between rows of one card.
    Layout.topMargin: first ? Theme.space4 : -(parent?.spacing ?? 0)
    implicitHeight: Math.max(52, row.implicitHeight + 2 * Theme.space10)
    implicitWidth: row.implicitWidth + 2 * Theme.space16

    Rectangle {
        anchors.fill: parent
        // Solid, like GTK's cards (card_bg_color in AppTheme).
        color: Theme.isDark ? Theme.surface0 : Theme.mantle
        topLeftRadius: r.first ? Theme.r(12) : 0
        topRightRadius: r.first ? Theme.r(12) : 0
        bottomLeftRadius: r.last ? Theme.r(12) : 0
        bottomRightRadius: r.last ? Theme.r(12) : 0
        border { width: 0 }
    }
    Rectangle {
        visible: !r.first
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: Theme.space16; rightMargin: Theme.space16 }
        height: 1
        color: Theme.base
    }

    RowLayout {
        id: row
        anchors { fill: parent; leftMargin: Theme.space16; rightMargin: Theme.space16 }
        spacing: Theme.space16
        Label {
            Layout.fillWidth: true
            text: r.title
            font.weight: Font.Medium
            color: Qt.rgba(Theme.text.r + (Theme.accentInk.r - Theme.text.r) * r.flash,
                           Theme.text.g + (Theme.accent.g - Theme.text.g) * r.flash,
                           Theme.text.b + (Theme.accent.b - Theme.text.b) * r.flash, 1)
        }
        Item {
            id: slot
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
            implicitHeight: Math.max(30, childrenRect.height)
        }
    }
}
