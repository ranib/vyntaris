import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import Quickshell

SettingsPage {
    id: page
    pageId: "apps"

    // Each is picked from the installed apps of its kind, never typed.
    property string open: ""
    function toggle(which) { open = open === which ? "" : which; }
    // The command an app starts with: its Exec without the %-codes, the program by its name (/usr/lib/firefox/firefox
    // is firefox, as the setting has it).
    function commandOf(e) {
        return (e.command ?? []).filter(t => !t.startsWith("%")).map((t, i) => i === 0 ? t.replace(/^.*\//, "") : t).join(" ");
    }
    function appsOf(category, q) {
        const k = q.trim().toLowerCase();
        const seen = new Set();
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay && (e.categories ?? []).includes(category) && (!k || e.name.toLowerCase().includes(k)))
            .map(e => ({ value: page.commandOf(e), title: e.name, caption: page.commandOf(e) }))
            .filter(r => r.value && !seen.has(r.value) && seen.add(r.value))
            .sort((a, b) => a.title.localeCompare(b.title));
    }
    function nameOf(category, command) {
        const e = DesktopEntries.applications.values.find(e => (e.categories ?? []).includes(category) && page.commandOf(e) === command);
        return e ? e.name : command;
    }
    // How each terminal runs a command it's given ("Run in terminal" follows the terminal).
    function runWith(term) {
        const bin = term.split(" ")[0];
        const known = { kitty: "kitty", foot: "foot", alacritty: "alacritty -e", ghostty: "ghostty -e", konsole: "konsole -e",
                        "gnome-terminal": "gnome-terminal --", "kgx": "kgx --", wezterm: "wezterm start --", xterm: "xterm -e" };
        return known[bin] ?? bin + " -e";
    }

    SettingsRow {
        title: Tr.t("Terminal")
        Button { id: terminalButton; icon: "terminal"; text: page.nameOf("TerminalEmulator", Config.apps.terminal); onClicked: page.toggle("terminal") }
    }
    SettingsPicker {
        anchor: terminalButton
        shown: page.open === "terminal"
        current: Config.apps.terminal
        results: page.appsOf("TerminalEmulator", query)
        empty: Tr.t("Nothing by that name")
        onPicked: v => { Config.apps.terminal = v; Config.apps.terminalRun = page.runWith(v); Config.saveSoon(); page.open = ""; }
        onClosed: page.open = ""
    }
    SettingsRow {
        title: Tr.t("Browser")
        Button { id: browserButton; icon: "globe"; text: page.nameOf("WebBrowser", Config.apps.browser); onClicked: page.toggle("browser") }
    }
    SettingsPicker {
        anchor: browserButton
        shown: page.open === "browser"
        current: Config.apps.browser
        results: page.appsOf("WebBrowser", query)
        empty: Tr.t("Nothing by that name")
        onPicked: v => { Config.apps.browser = v; Config.saveSoon(); page.open = ""; }
        onClosed: page.open = ""
    }
    SettingsRow {
        title: Tr.t("File manager")
        Button { id: filesButton; icon: "folder"; text: page.nameOf("FileManager", Config.apps.fileManager); onClicked: page.toggle("files") }
    }
    SettingsPicker {
        anchor: filesButton
        shown: page.open === "files"
        current: Config.apps.fileManager
        results: page.appsOf("FileManager", query)
        empty: Tr.t("Nothing by that name")
        onPicked: v => { Config.apps.fileManager = v; Config.saveSoon(); page.open = ""; }
        onClosed: page.open = ""
    }
    SettingsRow {
        title: Tr.t("Editor")
        Button { id: editorButton; icon: "edit"; text: page.nameOf("TextEditor", Config.apps.editor); onClicked: page.toggle("editor") }
    }
    SettingsPicker {
        anchor: editorButton
        shown: page.open === "editor"
        current: Config.apps.editor
        results: page.appsOf("TextEditor", query)
        empty: Tr.t("Nothing by that name")
        onPicked: v => { Config.apps.editor = v; Config.saveSoon(); page.open = ""; }
        onClosed: page.open = ""
    }

    SettingsSection { text: Tr.t("Store") }
    SettingsRow {
        title: Tr.t("Apps from the AUR")
        Switch { checked: Config.apps.aur; onToggled: on => { Config.apps.aur = on; Config.saveSoon(); } }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.subtext0
        font.pixelSize: Theme.fontSizeLabel
        text: Tr.t("The AUR holds recipes anyone can upload, and Arch doesn't check them: one could install something harmful. The Store shows each one's votes and when it last changed, and asks before it builds one.")
    }
}
