import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

SettingsPage {
    id: page
    pageId: "input"


    // Layouts and options are picked from what xkb has, not typed as codes.
    property string open: ""
    function toggle(which) { open = open === which ? "" : which; }
    readonly property var options: (Config.input.kbOptions || "").split(",").map(o => o.trim()).filter(o => o)
    function setOptions(list) { Config.input.kbOptions = list.join(","); Config.saveSoon(); }

    SettingsRow {
        title: Tr.t("Keyboard layout")
        ColumnLayout {
            spacing: Theme.space6
            Repeater {
                model: Keyboard.entries
                RowLayout {
                    required property var modelData
                    required property int index
                    Layout.alignment: Qt.AlignRight
                    spacing: Theme.space8
                    Caption { visible: index === 0 && Keyboard.multiple; text: Tr.t("Default") }
                    Label { text: modelData.name }
                    IconButton { visible: index > 0; icon: "arrow-up"; label: Tr.t("Make default"); onClicked: Keyboard.makeDefault(index) }
                    IconButton { visible: Keyboard.multiple; icon: "close"; label: Tr.t("Remove"); onClicked: Keyboard.remove(index) }
                }
            }
            Button { id: layoutButton; Layout.alignment: Qt.AlignRight; icon: "plus"; text: Tr.t("Add"); onClicked: page.toggle("layout") }
        }
    }
    SettingsPicker {
        anchor: layoutButton
        shown: page.open === "layout"
        placeholder: Tr.t("Language")
        results: Keyboard.search(query, 30).map(h => ({ value: h.layout + ":" + h.variant, title: h.name, caption: h.variant ? h.layout + " · " + h.variant : h.layout }))
        empty: query.trim() ? Tr.t("Nothing by that name") : ""
        onPicked: v => { const [l, vr] = v.split(":"); Keyboard.add(l, vr); page.open = ""; }
        onClosed: page.open = ""
    }
    SettingsRow {
        title: Tr.t("Options")
        RowLayout {
            spacing: Theme.space8
            Caption {
                Layout.maximumWidth: 260
                elide: Text.ElideRight
                text: page.options.length === 0 ? Tr.t("None") : page.options.map(o => Keyboard.optionCatalog.find(c => c.value === o)?.title ?? o).join(", ")
            }
            Button { id: optionsButton; icon: "keyboard"; text: Tr.t("Change"); onClicked: page.toggle("options") }
        }
    }
    SettingsPicker {
        anchor: optionsButton
        shown: page.open === "options"
        maxRows: 8
        currents: page.options
        results: {
            const k = query.trim().toLowerCase();
            return Keyboard.optionCatalog
                .filter(c => !k || c.title.toLowerCase().includes(k) || c.group.toLowerCase().includes(k) || c.value.includes(k))
                .map((c, i) => ({ c: c, i: i, on: page.options.includes(c.value) }))
                .sort((a, b) => (b.on - a.on) || (a.i - b.i))
                .map(x => x.c)
                .slice(0, 60)
                .map(c => ({ value: c.value, title: c.title, caption: c.group }));
        }
        // Several can be on: picking one turns it on or off, and the list stays open.
        onPicked: v => page.setOptions(page.options.includes(v) ? page.options.filter(o => o !== v) : page.options.concat([v]))
        onClosed: page.open = ""
    }
    SettingsSection { text: Tr.t("Mouse and touchpad") }
    SettingsRow {
        title: Tr.t("Pointer speed")
        RowLayout {
            spacing: Theme.space10
            Slider { implicitWidth: 180; value: (Config.input.sensitivity + 1) / 2; onMoved: v => { Config.input.sensitivity = Math.round((v * 2 - 1) * 10) / 10; Config.saveSoon(); } }
            Label { mono: true; Layout.preferredWidth: 40; text: (Config.input.sensitivity > 0 ? "+" : "") + Config.input.sensitivity.toFixed(1) }
        }
    }
    SettingsRow {
        title: Tr.t("Acceleration")
        Switch { checked: Config.input.mouseAccel; onToggled: on => { Config.input.mouseAccel = on; Config.saveSoon(); } }
    }
    SettingsRow {
        title: Tr.t("Natural scrolling")
        Switch { checked: Config.input.naturalScroll; onToggled: on => { Config.input.naturalScroll = on; Config.saveSoon(); } }
    }
    SettingsRow {
        title: Tr.t("Tap to click")
        Switch { checked: Config.input.tapToClick; onToggled: on => { Config.input.tapToClick = on; Config.saveSoon(); } }
    }

    SettingsSection { text: Tr.t("Screen edges") }
    SettingsRow {
        title: Tr.t("Volume edge")
        Switch { checked: Config.edges.volume; onToggled: on => { Config.edges.volume = on; Config.saveSoon(); } }
    }
    SettingsRow {
        title: Tr.t("Brightness edge")
        Switch { checked: Config.edges.brightness; onToggled: on => { Config.edges.brightness = on; Config.saveSoon(); } }
    }
    SettingsRow {
        title: Tr.t("Hot corner")
        Choice {
            options: [{ value: "off", label: Tr.t("Off") }, { value: "top-left", label: "↖" }, { value: "bottom-left", label: "↙" }]
            current: Config.edges.corner
            onPicked: v => { Config.edges.corner = v; Config.saveSoon(); }
        }
    }
}
