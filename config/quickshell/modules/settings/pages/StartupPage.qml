import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

SettingsPage {
    id: startupPage
    pageId: "startup"
    spacing: Theme.space8

    function add(item) {
        const list = (Config.startup.apps ?? []).slice();
        list.push(item);
        Config.startup.apps = list;
        Config.saveSoon();
    }
    Label {
        visible: (Config.startup.apps ?? []).length === 0
        color: Theme.overlay1
        text: Tr.t("None")
    }
    Repeater {
        model: Config.startup.apps ?? []
        RowLayout {
            id: startRow
            required property var modelData
            required property int index
            readonly property var entry: modelData.id ? DesktopEntries.byId(modelData.id) : null
            Layout.fillWidth: true
            spacing: Theme.space12
            Image {
                Layout.preferredWidth: 24; Layout.preferredHeight: 24
                sourceSize: Qt.size(48, 48)
                source: Quickshell.iconPath(startRow.entry?.icon ?? "", true) || Quickshell.iconPath("application-x-executable", true)
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.DemiBold; text: startRow.entry?.name ?? startRow.modelData.name }
                Label {
                    Layout.fillWidth: true; elide: Text.ElideRight; mono: true
                    font.pixelSize: Theme.fontSizeSmall; color: Theme.overlay1
                    text: startRow.modelData.command || (startRow.entry ? startRow.entry.command.join(" ") : Tr.t("not installed any more"))
                }
            }
            Button {
                icon: "trash"; text: Tr.t("Remove")
                onClicked: {
                    const list = (Config.startup.apps ?? []).slice();
                    list.splice(startRow.index, 1);
                    Config.startup.apps = list;
                    Config.saveSoon();
                }
            }
        }
    }
    SettingsSection { text: Tr.t("Add") }
    SearchField { id: startSearch; Layout.fillWidth: true; placeholder: Tr.t("Search") }
    Flow {
        Layout.fillWidth: true
        spacing: Theme.space6
        Repeater {
            model: {
                const q = startSearch.text.trim().toLowerCase();
                const have = (Config.startup.apps ?? []).map(a => a.id);
                return DesktopEntries.applications.values
                    .filter(e => !e.noDisplay && !have.includes(e.id) && (!q || e.name.toLowerCase().includes(q) || (e.genericName ?? "").toLowerCase().includes(q)))
                    .sort((a, b) => a.name.localeCompare(b.name))
                    .slice(0, q ? 12 : 8);
            }
            Button {
                required property var modelData
                text: modelData.name
                onClicked: { startupPage.add({ id: modelData.id, name: modelData.name }); startSearch.text = ""; }
            }
        }
    }
    SettingsSection { text: Tr.t("Command") }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space8
        Field { id: startCmd; Layout.fillWidth: true; mono: true; placeholder: "discord --start-minimized" }
        Button {
            icon: "check"; text: Tr.t("Add"); primary: true
            onClicked: {
                const cmd = startCmd.text.trim();
                if (!cmd) return;
                startupPage.add({ id: "", name: cmd.split(" ")[0], command: cmd });
                startCmd.text = "";
            }
        }
    }
}
