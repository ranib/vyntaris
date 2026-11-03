pragma Singleton
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import qs.config

Singleton {
    id: root

    property bool manual: false
    readonly property bool fullscreen: Compositor.fullscreenMode >= 2
    readonly property bool gameFocused: Compositor.activeContentType === "game"
        || /^(steam_app_\d+|gamescope|.*\.exe|minecraft.*|retroarch|com\.libretro\..*|dolphin-emu|pcsx2.*|rpcs3|ryujinx|.*yuzu.*|citra.*|osu!?|factorio|terraria|cs2|dota2|hl2_linux|.*\.x86_64)$/i.test(Compositor.activeClass)
    readonly property bool detected: Config.gameMode.auto && gameFocused && fullscreen

    property bool active: false
    readonly property bool wanted: manual || detected
    onWantedChanged: wanted ? enterDelay.restart() : exitDelay.restart()
    Timer { id: enterDelay; interval: 1500; onTriggered: if (root.wanted) root.enter() }
    Timer { id: exitDelay; interval: 3000; onTriggered: if (!root.wanted) root.leave() }

    property bool dndBefore: false
    property int profileBefore: -1

    function enter() {
        if (active) return;
        active = true;
        if (Config.gameMode.silence) { dndBefore = Notifications.dnd; Notifications.dnd = true; }
        if (Config.gameMode.performance && Power.hasPerformance) {
            profileBefore = PowerProfiles.profile;
            Power.set(PowerProfile.Performance);
        }
        // Blur and shadows are always off, so a game only loses the animations.
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.config({ animations = { enabled = false } })"]);
        Activities.banner("gamepad", Tr.t("Game mode on"), Tr.t("Distractions off"), -1, Theme.accent, 2500);
    }

    function leave() {
        if (!active) return;
        active = false;
        if (Config.gameMode.silence) Notifications.dnd = dndBefore;
        if (profileBefore >= 0) { Power.set(profileBefore); profileBefore = -1; }
        Quickshell.execDetached(["hyprctl", "reload", "config-only"]);
        Activities.banner("gamepad", Tr.t("Game mode off"), "", -1, Theme.overlay1, 2000);
    }

    function toggle() {
        if (active || manual) { manual = false; exitDelay.stop(); leave(); }
        else { manual = true; enterDelay.stop(); enter(); }
    }
}
