import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import Quickshell.Hyprland
import "pages"
import "SettingsIndex.js" as SettingsIndex

Scope {
    id: root

    Connections {
        target: Panels
        function onSettingsSearchRequested(text) { side.search.text = text; side.search.input.forceActiveFocus(); }
        function onSettingsPageChanged() { root.markOpened(); root.readPage(); }
        function onSettingsFocusChanged() { root.focusRow(); }
    }
    function readPage() {
        const page = Panels.settingsPage;
        if (page === "displays") Hyprland.refreshMonitors();
        if (page === "backups") { Snapshots.refresh(); CloudBackup.refresh(); }
        if (page === "power") Sleep.refresh();
        if (page === "printers") Printers.refresh();
    }
    Component.onCompleted: { markOpened(); readPage(); focusRow(); }

    property var opened: []
    function markOpened() {
        if (!opened.includes(Panels.settingsPage)) opened = opened.concat([Panels.settingsPage]);
    }
    function findRow(title) {
        let found = null;
        const walk = (item, pageId) => {
            for (const child of item.children) {
                if (found) return;
                const id = child.pageId ?? pageId;
                if (child.isOption === true && child.title === title && id === Panels.settingsPage) { found = child; return; }
                walk(child, id);
            }
        };
        walk(pageColumn, "");
        return found;
    }

    function focusRow() {
        const title = Panels.settingsFocus;
        if (!title) return;
        Panels.settingsFocus = "";
        query = "";
        side.search.text = "";
        jump.title = title;
        jump.restart();
    }

    property string query: ""
    property var results: []
    onQueryChanged: searchTimer.restart()
    Timer { id: searchTimer; interval: 120; onTriggered: root.results = root.search(root.query) }

    function search(text) {
        const words = text.trim().toLowerCase().split(/\s+/).filter(w => w);
        if (words.length === 0) return [];
        const out = [];
        const matches = hay => words.every(w => hay.toLowerCase().includes(w));
        for (const p of pages)
            if (matches(p.label + " " + Tr.t(p.label) + " " + p.keywords)) out.push({ page: p.id, title: p.label, row: false });
        const shown = pages.map(p => p.id);
        for (const r of SettingsIndex.rows)
            if (shown.includes(r.page) && matches(r.title + " " + Tr.t(r.title))) out.push({ page: r.page, title: r.title, row: true });
        return out.slice(0, 60);
    }

    function openResult(r) {
        query = "";
        side.search.text = "";
        Panels.settingsPage = r.page;
        if (!r.row) { flick.contentY = 0; return; }
        jump.title = Tr.t(r.title);
        jump.restart();
    }
    Timer {
        id: jump
        property string title: ""
        interval: 120
        onTriggered: {
            const row = root.findRow(title);
            if (!row) { flick.contentY = 0; return; }
            const y = row.mapToItem(pageColumn, 0, 0).y + pageColumn.y - 60;
            flick.contentY = Math.max(0, Math.min(y, flick.contentHeight - flick.height));
            row.highlight();
        }
    }

    readonly property var pages: SettingsIndex.pages.filter(p => !p.panel)

    // The keyboard can go to a row below the fold, and it comes into view.
    function reveal(item) {
        let inside = false;
        for (let p = item; p; p = p.parent) if (p === pageColumn) inside = true;
        if (!inside) return;
        const y = item.mapToItem(pageColumn, 0, 0).y + pageColumn.y, margin = 24;
        if (y < flick.contentY + margin) flick.contentY = Math.max(0, y - margin);
        else if (y + item.height > flick.contentY + flick.height - margin)
            flick.contentY = Math.min(flick.contentHeight - flick.height, y + item.height + margin - flick.height);
    }
    Connections {
        target: flick.Window
        function onActiveFocusItemChanged() { if (flick.Window.activeFocusItem) root.reveal(flick.Window.activeFocusItem); }
    }

    component Page: Loader {
        required property string pageId
        Layout.fillWidth: true
        active: root.opened.includes(pageId)
        visible: active && Panels.settingsPage === pageId
    }

    FloatingWindow {
        id: win
        visible: Panels.settingsOpen
        title: Tr.t("Settings")
        // Wide for the cards, and as tall as the whole sidebar.
        implicitWidth: Math.min(1060, (screen?.width ?? 1920) * 0.8)
        readonly property real sideNeeded: side.needed
        implicitHeight: Math.min(sideNeeded, (screen?.height ?? 1080) * 0.9)
        minimumSize: Qt.size(760, 480)
        color: Theme.base

        onVisibleChanged: if (!visible) Panels.settingsOpen = false

        RowLayout {
            anchors.fill: parent
            spacing: 0
            focus: true
            Keys.onEscapePressed: {
                if (root.query !== "") side.search.text = "";
                else Panels.settingsOpen = false;
            }

            SideNav {
                id: side
                icon: Distro.glyph
                title: Tr.t("Settings")
                subtitle: Distro.name
                searchHint: Tr.t("Search settings")
                pages: root.pages
                current: Panels.settingsPage
                onPicked: id => Panels.settingsPage = id
                Connections {
                    target: side.search.input
                    function onTextChanged() { root.query = side.search.text; }
                    function onAccepted() { if (root.results.length > 0) root.openResult(root.results[0]); }
                }
                Shortcut {
                    sequence: "Ctrl+F"
                    onActivated: side.search.input.forceActiveFocus()
                }
            }

            Flickable {
                id: resultsView
                visible: root.query.trim() !== ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: resultColumn.implicitHeight + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: resultColumn
                    x: Math.max(30, (parent.width - width) / 2)
                    y: 28
                    width: Math.min(parent.width - 60, 680)
                    spacing: Theme.space6

                    Label { font.pixelSize: Theme.fontSizeHeading; font.weight: Font.Bold; text: Tr.t("Search") }
                    Label {
                        visible: root.results.length === 0
                        Layout.topMargin: Theme.space10
                        color: Theme.overlay1
                        text: Tr.f("No settings match \u201c{0}\u201d", root.query.trim())
                    }
                    Repeater {
                        model: root.results
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: resRow.implicitHeight + 20
                            radius: Theme.r(12)
                            color: resArea.containsMouse ? Theme.hover : Theme.alpha(Theme.text, 0.04)
                            border { width: 1; color: resArea.containsMouse ? Theme.accent : Theme.glassRim }
                            RowLayout {
                                id: resRow
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Theme.space14; rightMargin: Theme.space14 }
                                spacing: Theme.space12
                                Icon { name: root.pages.find(p => p.id === modelData.page)?.icon ?? "settings"; size: 15; color: Theme.accentInk }
                                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.DemiBold; text: Tr.t(modelData.title) }
                                Label { overline: true; color: Theme.overlay1; text: Tr.t(root.pages.find(p => p.id === modelData.page)?.label ?? "") }
                            }
                            PressArea { label: Tr.t(modelData.title); id: resArea; anchors.fill: parent; onClicked: root.openResult(modelData) }
                        }
                    }
                }
            }

            Flickable {
                id: flick
                visible: !resultsView.visible
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: pageColumn.implicitHeight + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: pageColumn
                    x: Math.max(30, (parent.width - width) / 2)
                    y: 28
                    width: Math.min(parent.width - 60, 680)
                    spacing: Theme.space12

                    Label {
                        id: pageTitle
                        font.pixelSize: Theme.fontSizeHeading
                        font.weight: Font.Bold
                        text: Tr.t(root.pages.find(p => p.id === Panels.settingsPage)?.label ?? "")
                    }

                    Page { pageId: "appearance"; sourceComponent: Component { AppearancePage {} } }

                    Page { pageId: "wallpaper"; sourceComponent: Component { WallpaperPage {} } }

                    Page { pageId: "bar"; sourceComponent: Component { BarPage {} } }

                    Page { pageId: "notifications"; sourceComponent: Component { NotificationsPage {} } }

                    Page { pageId: "windows"; sourceComponent: Component { WindowsPage {} } }

                    Page { pageId: "startup"; sourceComponent: Component { StartupPage {} } }

                    Page { pageId: "apps"; sourceComponent: Component { AppsPage {} } }

                    Page { pageId: "input"; sourceComponent: Component { InputPage {} } }

                    Page { pageId: "displays"; sourceComponent: Component { DisplaysPage {} } }

                    Page { pageId: "power"; sourceComponent: Component { PowerPage {} } }

                    Page { pageId: "users"; sourceComponent: Component { UsersPage {} } }

                    Page { pageId: "time"; sourceComponent: Component { RegionPage {} } }

                    Page { pageId: "lock"; sourceComponent: Component { LockScreenPage {} } }

                    Page { pageId: "printers"; sourceComponent: Component { PrintersPage {} } }

                    Page { pageId: "drivers"; sourceComponent: Component { DriversPage {} } }

                    Page { pageId: "backups"; sourceComponent: Component { BackupsPage {} } }

                    Page { pageId: "access"; sourceComponent: Component { AccessibilityPage {} } }

                    Page { pageId: "about"; sourceComponent: Component { AboutPage {} } }
                }
            }
        }
    }
}
