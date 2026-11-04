import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

ColumnLayout {
    id: root
    property int maxListHeight: 260
    spacing: Theme.space10

    SystemClock { id: clock; precision: SystemClock.Minutes }
    function ago(t) {
        const s = Math.max(0, (clock.date - t) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Qt.locale("en_US").toString(t, "d MMM");
    }

    readonly property var groups: {
        const out = [], at = {};
        Notifications.history.forEach((e, i) => {
            const app = e.appName || Tr.t("System");
            if (!(app in at)) { at[app] = out.length; out.push({ app, items: [] }); }
            out[at[app]].items.push(i);
        });
        return out;
    }
    property var opened: ({})
    function toggle(app) {
        const next = Object.assign({}, opened);
        next[app] = !next[app];
        opened = next;
    }
    readonly property int count: Notifications.history.length

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space8

        Label { overline: true; color: Theme.overlay1; text: Tr.t("Notifications") }
        Rectangle {
            visible: root.count > 0
            implicitWidth: countText.implicitWidth + 14
            implicitHeight: 18
            radius: Theme.r(10)
            color: Theme.accent
            Label { id: countText; anchors.centerIn: parent; mono: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.textOnAccent; text: root.count }
        }
        Item { Layout.fillWidth: true }
        Label {
            visible: root.count > 0
            overline: true
            font.pixelSize: Theme.fontSizeSmall
            color: clearArea.containsMouse ? Theme.error : Theme.overlay0
            text: Tr.t("Clear all")
            PressArea { label: Tr.t("Clear all"); id: clearArea; anchors.fill: parent; anchors.margins: -6; onClicked: Notifications.clearHistory() }
        }
        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: Notifications.dnd ? Theme.accent : silentArea.containsMouse ? Theme.tint(parent, Theme.text, 0.12) : Theme.tint(parent, Theme.text, 0.06)
            border { width: 1; color: Notifications.dnd ? Theme.accent : Theme.rimOn(parent) }
            Behavior on color { ColorAnim {} }
            Icon { anchors.centerIn: parent; name: Notifications.dnd ? "bell-off" : "bell"; size: 14; color: Notifications.dnd ? Theme.textOnAccent : Theme.subtext0 }
            PressArea { label: Tr.t("Do not disturb"); role: Accessible.CheckBox; checked: Notifications.dnd; id: silentArea; anchors.fill: parent; onClicked: Notifications.dnd = !Notifications.dnd }
        }
    }

    readonly property Item body: {
        for (let p = parent; p; p = p.parent)
            if (typeof p.lane === "function" && p.widest !== undefined) return p;
        return null;
    }

    ListView {
        id: list
        Layout.fillWidth: true
        implicitHeight: Math.min(contentHeight, root.maxListHeight)
        visible: root.count > 0
        clip: true
        spacing: Theme.space8
        model: root.groups
        boundsBehavior: Flickable.StopAtBounds

        delegate: ColumnLayout {
            id: group
            required property var modelData
            readonly property var items: modelData.items
            readonly property bool many: items.length > 1
            readonly property bool open: many && (root.opened[modelData.app] ?? false)
            width: list.width
            spacing: Theme.space6

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space4
                visible: group.open
                spacing: Theme.space8
                Label { overline: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.subtext0; text: group.modelData.app }
                Label { mono: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.overlay0; text: group.items.length }
                Item { Layout.fillWidth: true }
                Label {
                    overline: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: lessArea.containsMouse ? Theme.accentBright : Theme.accentInk
                    text: Tr.t("Show less")
                    PressArea { label: Tr.t("Show less"); id: lessArea; anchors.fill: parent; anchors.margins: -6; onClicked: root.toggle(group.modelData.app) }
                }
                Label {
                    overline: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: groupClear.containsMouse ? Theme.error : Theme.overlay0
                    text: Tr.t("Clear")
                    PressArea { label: Tr.t("Clear"); id: groupClear; anchors.fill: parent; anchors.margins: -6; onClicked: Notifications.removeIndexes(group.items) }
                }
            }

            Repeater {
                model: group.open ? group.items : [group.items[0]]
                NotificationCard {
                    id: noteCard
                    readonly property real lane: root.body ? root.body.lane({ y: group.y + y, height: height }, list) : 0
                    Layout.leftMargin: lane
                    Layout.rightMargin: lane
                    required property int modelData
                    Layout.fillWidth: true
                    entry: Notifications.history[modelData] ?? ({})
                    ago: root.ago(entry.time)
                    stacked: group.many && !group.open ? Math.min(2, group.items.length - 1) : 0
                    more: group.many && !group.open ? group.items.length - 1 : 0
                    // A stack opens; a notification takes you to its app.
                    onClicked: {
                        if (group.many && !group.open) { root.toggle(group.modelData.app); return; }
                        Notifications.focusApp(entry.desktopEntry, entry.appName);
                        Panels.closeAll?.();
                    }
                    onDismissed: group.many && !group.open ? Notifications.removeIndexes(group.items) : Notifications.removeAt(modelData)
                }
            }
        }
    }
}
