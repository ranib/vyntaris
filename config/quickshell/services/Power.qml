pragma Singleton
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import qs.config

Singleton {
    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    readonly property var order: hasPerformance
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]

    function name(p) {
        return (p === PowerProfile.PowerSaver ? Tr.t("Power saver")
             : p === PowerProfile.Performance ? Tr.t("Performance") : Tr.t("Balanced"));
    }

    function icon(p) {
        return (p === PowerProfile.PowerSaver ? "power-saver"
             : p === PowerProfile.Performance ? "power-performance" : "power-balanced");
    }

    function set(p) {
        PowerProfiles.profile = p;
    }

    function cycle() {
        const i = order.indexOf(profile);
        set(order[(i + 1) % order.length]);
    }
}
