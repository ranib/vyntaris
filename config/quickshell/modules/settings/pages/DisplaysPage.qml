import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

SettingsPage {
    id: page

    function monitorValue(name, key, fallback) {
        const m = (Config.display.monitors ?? []).find(m => m.name === name);
        return m && m[key] !== undefined ? m[key] : fallback;
    }
    function setMonitor(name, key, value) {
        const list = (Config.display.monitors ?? []).map(m => Object.assign({}, m));
        let m = list.find(m => m.name === name);
        if (!m) { m = { name }; list.push(m); }
        m[key] = value;
        Config.display.monitors = list;
        Config.saveSoon();
    }

    pageId: "displays"

    SettingsRow {
        title: Tr.t("Default scale")
        Choice {
            options: [{ value: "auto", label: Tr.t("Auto") }, { value: 1, label: "100%" }, { value: 1.5, label: "150%" }]
            current: Config.display.scale
            onPicked: v => { Config.display.scale = v; Config.saveSoon(); }
        }
    }

    SettingsSection { visible: Hyprland.monitors.values.length > 1; text: Tr.t("Arrangement") }
    Rectangle {
        id: arrange
        visible: Hyprland.monitors.values.length > 1
        Layout.fillWidth: true
        implicitHeight: 220
        radius: Theme.r(12)
        color: Theme.tint(parent, Theme.crust, 0.45)
        border { width: 1; color: Theme.rimOn(parent) }

        readonly property var mons: Hyprland.monitors.values.map(m => {
            const o = m.lastIpcObject ?? {};
            const sc = o.scale || 1;
            return { name: m.name, x: o.x ?? 0, y: o.y ?? 0, w: (o.width ?? 1920) / sc, h: (o.height ?? 1080) / sc };
        })
        readonly property real minX: Math.min(...mons.map(m => m.x))
        readonly property real minY: Math.min(...mons.map(m => m.y))
        readonly property real spanW: Math.max(...mons.map(m => m.x + m.w)) - minX
        readonly property real spanH: Math.max(...mons.map(m => m.y + m.h)) - minY
        readonly property real k: Math.min((width - 80) / Math.max(1, spanW * 1.6), (height - 50) / Math.max(1, spanH * 1.3))

        function commit(name, nx, ny) {
            const me = mons.find(m => m.name === name);
            let best = null;
            for (const o of mons) {
                if (o.name === name) continue;
                const cands = [
                    { x: o.x + o.w, y: Math.max(o.y - me.h + 1, Math.min(ny, o.y + o.h - 1)) },
                    { x: o.x - me.w, y: Math.max(o.y - me.h + 1, Math.min(ny, o.y + o.h - 1)) },
                    { x: Math.max(o.x - me.w + 1, Math.min(nx, o.x + o.w - 1)), y: o.y - me.h },
                    { x: Math.max(o.x - me.w + 1, Math.min(nx, o.x + o.w - 1)), y: o.y + o.h },
                ];
                for (const c of cands) {
                    const d = Math.hypot(c.x - nx, c.y - ny);
                    if (!best || d < best.d) best = { x: c.x, y: c.y, d };
                }
            }
            const fx = Math.round(best ? best.x : nx), fy = Math.round(best ? best.y : ny);
            page.setMonitor(name, "position", `${fx}x${fy}`);
        }

        Repeater {
            model: arrange.mons
            Rectangle {
                id: monBox
                required property var modelData
                readonly property real baseX: (arrange.width - arrange.spanW * arrange.k) / 2 + (modelData.x - arrange.minX) * arrange.k
                readonly property real baseY: (arrange.height - arrange.spanH * arrange.k) / 2 + (modelData.y - arrange.minY) * arrange.k
                x: drag.active ? x : baseX
                y: drag.active ? y : baseY
                width: modelData.w * arrange.k
                height: modelData.h * arrange.k
                radius: Theme.r(8)
                color: drag.active ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                border { width: 1.5; color: Theme.accent }
                Column {
                    anchors.centerIn: parent
                    Label { anchors.horizontalCenter: parent.horizontalCenter; font.weight: Font.DemiBold; color: Theme.textOnAccent; text: monBox.modelData.name }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; mono: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.textOnAccent; text: Math.round(monBox.modelData.w) + "×" + Math.round(monBox.modelData.h) }
                }
                DragHandler {
                    id: drag
                    enabled: arrange.mons.length > 1
                    onActiveChanged: if (!active) {
                        const lx = (monBox.x - (arrange.width - arrange.spanW * arrange.k) / 2) / arrange.k + arrange.minX;
                        const ly = (monBox.y - (arrange.height - arrange.spanH * arrange.k) / 2) / arrange.k + arrange.minY;
                        arrange.commit(monBox.modelData.name, lx, ly);
                    }
                }
                HoverHandler { cursorShape: arrange.mons.length > 1 ? Qt.OpenHandCursor : Qt.ArrowCursor }
            }
        }
    }

    Repeater {
        model: Hyprland.monitors.values
        ColumnLayout {
            id: mon
            required property var modelData
            required property int index
            readonly property var ipc: modelData.lastIpcObject ?? {}
            Layout.fillWidth: true
            spacing: Theme.space10

            SettingsSection {
                text: mon.modelData.name + (mon.ipc.model ? "  ·  " + mon.ipc.model : "")
            }
            SettingsRow {
                title: Tr.t("Mode")
                Choice {
                    options: [{ value: "preferred", label: Tr.t("Auto") }, { value: "highrr", label: Tr.t("Fastest") }, { value: "highres", label: Tr.t("Sharpest") }]
                    current: page.monitorValue(mon.modelData.name, "mode", "preferred")
                    onPicked: v => page.setMonitor(mon.modelData.name, "mode", v)
                }
            }
            SettingsRow {
                title: Tr.t("Scale")
                Choice {
                    options: [{ value: "auto", label: Tr.t("Auto") }, { value: 1, label: "100%" }, { value: 1.5, label: "150%" }]
                    current: page.monitorValue(mon.modelData.name, "scale", Config.display.scale)
                    onPicked: v => page.setMonitor(mon.modelData.name, "scale", v)
                }
            }
            SettingsRow {
                id: rateRow
                title: Tr.t("Refresh rate")
                readonly property var modes: mon.ipc.availableModes ?? []
                readonly property real maxRate: Math.max(60, ...modes.map(m => parseFloat(m.split("@")[1]) || 0))
                readonly property string size: modes.length > 0 ? modes[0].split("@")[0] : `${mon.ipc.width}x${mon.ipc.height}`
                readonly property var rates: Math.round(maxRate) > 60 ? [60, Math.round(maxRate)] : [60]
                Choice {
                    options: [{ value: "auto", label: Tr.t("Auto") }].concat(rateRow.rates.map(r => ({ value: r, label: r + Tr.t(" Hz") })))
                    current: {
                        const m = String(page.monitorValue(mon.modelData.name, "mode", "preferred")).match(/@(\d+)/);
                        return m ? Number(m[1]) : "auto";
                    }
                    onPicked: v => page.setMonitor(mon.modelData.name, "mode", v === "auto" ? "preferred" : `${rateRow.size}@${v}`)
                }
            }
            SettingsRow {
                visible: mon.index > 0
                title: Tr.t("Position")
                Choice {
                    options: [{ value: "auto", label: Tr.t("Auto") }, { value: "auto-left", label: Tr.t("Left") }, { value: "auto-right", label: Tr.t("Right") }]
                    current: page.monitorValue(mon.modelData.name, "position", "auto")
                    onPicked: v => page.setMonitor(mon.modelData.name, "position", v)
                }
            }
        }
    }
}
