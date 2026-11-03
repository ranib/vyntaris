pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.config

Singleton {
    id: root

    readonly property var layouts: (Config.input.kbLayout || "us").split(",").map(s => s.trim()).filter(s => s)
    readonly property var variants: {
        const v = (Config.input.kbVariant || "").split(",").map(s => s.trim());
        return layouts.map((_, i) => v[i] ?? "");
    }
    readonly property bool multiple: layouts.length > 1
    property int index: 0
    property string name: ""
    readonly property string code: (layouts[index] ?? layouts[0] ?? "").toUpperCase()

    property var names: ({})
    property var catalog: []
    // xkb options ({ value: "grp:alt_shift_toggle", title, group }), to pick from in Settings.
    property var optionCatalog: []

    readonly property var entries: layouts.map((l, i) => ({
        layout: l, variant: variants[i],
        code: l.toUpperCase(),
        name: names[variants[i] ? l + ":" + variants[i] : l] ?? (variants[i] ? `${l} (${variants[i]})` : l),
    }))

    signal changed()

    function next() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
    }
    function select(i) {
        if (i < 0 || i >= layouts.length) return;
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", String(i)]);
    }

    function save(ls, vs) {
        Config.input.kbLayout = ls.join(",");
        Config.input.kbVariant = vs.some(v => v) ? vs.join(",") : "";
        Config.save();
    }
    function add(layout, variant) {
        const ls = layouts.slice(), vs = variants.slice();
        if (ls.some((l, i) => l === layout && vs[i] === (variant ?? ""))) return;
        ls.push(layout); vs.push(variant ?? "");
        save(ls, vs);
    }
    function remove(i) {
        if (layouts.length <= 1) return;
        const ls = layouts.slice(), vs = variants.slice();
        ls.splice(i, 1); vs.splice(i, 1);
        save(ls, vs);
    }
    function makeDefault(i) {
        if (i <= 0) return;
        const ls = layouts.slice(), vs = variants.slice();
        ls.unshift(ls.splice(i, 1)[0]); vs.unshift(vs.splice(i, 1)[0]);
        save(ls, vs);
    }

    function search(text, max) {
        const q = text.trim().toLowerCase();
        if (!q) return [];
        const have = new Set(layouts.map((l, i) => l + ":" + variants[i]));
        const hits = catalog.filter(c => !have.has(c.layout + ":" + c.variant)
            && (c.name.toLowerCase().includes(q) || c.layout === q));
        hits.sort((a, b) => (a.variant ? 1 : 0) - (b.variant ? 1 : 0) || a.name.length - b.name.length);
        return hits.slice(0, max ?? 6);
    }

    function refresh() { devices.running = true; }

    Process {
        id: devices
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards.find(k => k.main);
                    if (!kb) return;
                    const changed = kb.active_layout_index !== root.index;
                    root.index = kb.active_layout_index ?? 0;
                    root.name = kb.active_keymap ?? "";
                    if (changed) root.changed();
                } catch (e) {}
            }
        }
    }

    Process {
        id: xkb
        running: true
        command: ["cat", "/usr/share/X11/xkb/rules/base.lst"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = {}, list = [], groups = {}, opts = [];
                let section = "";
                for (const line of text.split("\n")) {
                    if (line.startsWith("! ")) { section = line.slice(2).trim(); continue; }
                    let m;
                    if (section === "layout" && (m = line.match(/^\s+(\S+)\s+(.+)$/))) {
                        names[m[1]] = m[2].trim();
                        list.push({ layout: m[1], variant: "", name: m[2].trim() });
                    } else if (section === "variant" && (m = line.match(/^\s+(\S+)\s+(\S+):\s*(.+)$/))) {
                        names[m[2] + ":" + m[1]] = m[3].trim();
                        list.push({ layout: m[2], variant: m[1], name: m[3].trim() });
                    } else if (section === "option" && (m = line.match(/^\s+(\S+)\s+(.+)$/))) {
                        // Groups are named like their options but not always in the same case (Compose, compose:ralt).
                        if (m[1].includes(":")) opts.push({ value: m[1], title: m[2].trim(), group: groups[m[1].split(":")[0].toLowerCase()] ?? "" });
                        else groups[m[1].toLowerCase()] = m[2].trim();
                    }
                }
                root.names = names;
                root.catalog = list;
                root.optionCatalog = opts;
            }
        }
    }

    Component.onCompleted: refresh()
    onLayoutsChanged: refreshLater.restart()
    onVariantsChanged: refreshLater.restart()
    Timer { id: refreshLater; interval: 1500; onTriggered: root.refresh() }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") root.refresh();
        }
    }
}
