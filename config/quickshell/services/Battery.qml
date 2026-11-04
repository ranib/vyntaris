pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import qs.config

Singleton {
    id: root

    property string path: ""
    readonly property bool available: path !== ""

    readonly property var device: UPower.displayDevice
    readonly property int percent: device?.ready ? Math.round(device.percentage * 100) : 0
    readonly property string status: !device?.ready || device.state === UPowerDeviceState.Unknown ? ""
        : device.state === UPowerDeviceState.FullyCharged ? "Full"
        : device.state === UPowerDeviceState.Charging ? "Charging" : "Discharging"
    readonly property bool charging: status === "Charging" || status === "Full"
    readonly property bool full: status === "Full"

    property real energyNow: 0
    property real energyFull: 0
    property real energyDesign: 0
    property real power: 0
    property int cycles: -1
    property string model: ""

    readonly property real health: energyDesign > 0 ? energyFull / energyDesign : -1
    readonly property real hoursLeft: power <= 0.1 ? -1
        : charging ? Math.max(0, energyFull - energyNow) / power
        : energyNow / power

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/power_supply/*; do [ \"$(cat $d/type)\" = Battery ] && echo $d && break; done"]
        stdout: StdioCollector {
            onStreamFinished: { root.path = text.trim(); root.refresh(); }
        }
    }

    Process {
        id: reader
        command: ["sh", "-c", `cd "${root.path}" && for f in charge_types charge_control_end_threshold energy_now energy_full energy_full_design power_now charge_now charge_full charge_full_design current_now voltage_now cycle_count model_name; do [ -r $f ] && echo "$f=$(cat $f)"; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0) v[line.slice(0, i)] = line.slice(i + 1);
                }
                if (v.charge_types !== undefined) {
                    root.limitKind = "types";
                    root.chargeLimit = /\[Long_Life\]/.test(v.charge_types);
                } else if (v.charge_control_end_threshold !== undefined) {
                    root.limitKind = "threshold";
                    root.chargeLimit = parseInt(v.charge_control_end_threshold) < 100;
                }
                const num = k => parseFloat(v[k]);
                const volts = (num("voltage_now") || 0) / 1e6;
                root.model = v.model_name ?? "";
                root.cycles = v.cycle_count !== undefined ? parseInt(v.cycle_count) : -1;
                if (v.energy_now !== undefined) {
                    root.energyNow = num("energy_now") / 1e6;
                    root.energyFull = num("energy_full") / 1e6;
                    root.energyDesign = num("energy_full_design") / 1e6;
                    root.power = Math.abs(num("power_now") || 0) / 1e6;
                } else if (v.charge_now !== undefined) {
                    root.energyNow = num("charge_now") / 1e6 * volts;
                    root.energyFull = num("charge_full") / 1e6 * volts;
                    root.energyDesign = num("charge_full_design") / 1e6 * volts;
                    root.power = Math.abs(num("current_now") || 0) / 1e6 * volts;
                }
            }
        }
    }

    property string limitKind: ""
    property bool chargeLimit: false
    function setChargeLimit(on) {
        if (!limitKind) return;
        const file = limitKind === "types" ? "charge_types" : "charge_control_end_threshold";
        const value = limitKind === "types" ? (on ? "Long_Life" : "Standard") : (on ? "80" : "100");
        chargeLimit = on;
        Quickshell.execDetached(["sh", "-c", 'printf %s "$2" > "$1" || notify-send -a Battery "Charge limit" "Not allowed yet: restart once after setting Vyntaris up (that lets you switch this)"',
            "sh", path + "/" + file, value]);
        later.restart();
    }
    Timer { id: later; interval: 800; onTriggered: root.refresh() }
    Timer {
        interval: 10000
        running: root.available && Panels.batteryOpen
        repeat: true
        onTriggered: reader.running = true
    }

    function refresh() {
        if (available) reader.running = true;
    }
}
