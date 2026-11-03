import QtQuick
import QtQuick.Layouts
import qs.config
import "Slant.js" as Slant

ColumnLayout {
    id: root
    readonly property Item island: {
        let v = parent;
        for (let p = parent; p; p = p.parent)
            if (p.hang !== undefined && p.fullWidth !== undefined) v = p;
        return v;
    }
    readonly property bool inIsland: island !== null && island.hang !== undefined && island.fullWidth !== undefined
    readonly property real drop: island ? island.height - Theme.barHeight : 0
    readonly property real lean: inIsland && Theme.slanted && drop > 1 ? Slant.lean(drop) : 0
    function out(y) {
        return lean > 0 ? Math.max(0, lean * (island.height - y) / drop) : 0;
    }
    readonly property real atTop: (void [y, parent?.y, island?.height], parent && island ? parent.mapToItem(island, 0, y).y : y)
    readonly property real widest: out(atTop)

    x: Theme.panelInset - widest
    y: Theme.panelTop
    width: parent.width - 2 * Theme.panelInset + 2 * widest
    spacing: Theme.space12

    property var blocks: []
    property var kept: []
    function blockOf(item) {
        for (let p = item; p && p !== root; p = p.parent)
            if (blocks.indexOf(p) >= 0) return p;
        return null;
    }
    function isColumn(item) {
        return item instanceof ColumnLayout;
    }
    function isList(item) {
        return item instanceof ListView;
    }
    function lane(row, list) {
        if (lean <= 0 || !row || !list) return 0;
        void [row.y, row.height, list.contentY, list.x, list.y, list.width, list.height, island.height, lean, x];
        const at = list.mapToItem(island, 0, 0);
        return Math.max(0, (Theme.panelInset - out(at.y + row.y - list.contentY + row.height)) - at.x);
    }
    function keep(item) {
        if (kept.some(k => k.item === item)) return;
        kept.push({ item: item, left: item.Layout.leftMargin, right: item.Layout.rightMargin });
    }
    // `at` is where the column will be once its own margins apply ({ x, y, width } in the island): margins set on a
    // nested column only move it at the next polish, and its rows placed from where it was would follow another
    // part of the edge (the Sound panel's inputs took its outputs').
    function place(column, at) {
        const view = island, W = view.width, inset = Theme.panelInset;
        const m = column.mapToItem(view, 0, 0);
        const c = at ?? { x: m.x, y: m.y, width: column.width };
        for (let i = 0; i < column.children.length; i++) {
            const it = column.children[i];
            if (!it.visible || !it.Layout || it.height <= 0) continue;
            const y = c.y + it.y, nested = isColumn(it), list = isList(it);
            const o = out(nested || list ? y : y + it.height);
            keep(it);
            const left = Math.round((inset - o) - c.x), right = Math.round((c.x + c.width) - (W - inset + o));
            it.Layout.leftMargin = left;
            it.Layout.rightMargin = right;
            // Filling the width, a nested column will sit exactly between its margins; otherwise it's measured.
            if (nested) place(it, it.Layout.fillWidth ? { x: c.x + left, y: y, width: c.width - left - right } : undefined);
            else blocks.push(it);
        }
    }
    function fit() {
        if (lean <= 0) {
            for (const k of kept) { k.item.Layout.leftMargin = k.left; k.item.Layout.rightMargin = k.right; }
            kept = []; blocks = [];
            return;
        }
        blocks = [];
        place(root);
        blocksChanged();
    }
    function refit() { Qt.callLater(fit); fitAgain.restart(); }
    Timer { id: fitAgain; interval: 60; onTriggered: root.fit() }
    onHeightChanged: refit()
    // A list whose rows are replaced keeps its height, and the new rows still need their margins.
    onChildrenChanged: refit()
    onWidestChanged: refit()
    onVisibleChanged: refit()
    Component.onCompleted: refit()
}
