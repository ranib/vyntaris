pragma Singleton
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import qs.config
import "../components/Icons.js" as Icons

Singleton {
    id: root

    property string kind: ""
    property bool shown: false

    function show(k) {
        if (Panels.anyIslandPanel) return;
        if ((k === "wifi" || k === "bluetooth") && shown && kind === "airplane") return;
        kind = k;
        shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: root.kind === "media" ? 2600 : 1600
        onTriggered: root.shown = false
    }

    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var source: Pipewire.defaultAudioSource?.audio ?? null
    PwObjectTracker { objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ] }

    property bool armed: false
    Timer { running: true; interval: 1500; onTriggered: root.armed = true }

    Connections {
        target: root.sink
        enabled: root.armed
        function onVolumeChanged() { root.show("volume"); }
        function onMutedChanged() { root.show("volume"); }
    }
    Connections {
        target: root.source
        enabled: root.armed
        function onMutedChanged() { root.show("mic"); }
    }
    // Without the boost nothing stays above full.
    Connections {
        target: Config.audio
        function onBoostChanged() { if (!Config.audio.boost && root.sink && root.sink.volume > 1) root.sink.volume = 1; }
    }
    Connections {
        target: Brightness
        function onChanged() { root.show("brightness"); }
    }
    Connections {
        target: Media
        function onChanged() { mediaDelay.restart(); }
    }
    Connections {
        target: Keyboard
        enabled: root.armed
        function onChanged() { root.show("layout"); }
    }
    Connections {
        target: Networking
        enabled: root.armed
        function onWifiEnabledChanged() { root.show("wifi"); }
    }
    Connections {
        target: BluetoothCtl
        enabled: root.armed
        function onEnabledChanged() { root.show("bluetooth"); }
    }
    Connections {
        target: NightLight
        enabled: root.armed
        function onActiveChanged() { root.show("night"); }
    }
    Connections {
        target: KeepAwake
        enabled: root.armed
        function onModeChanged() { root.show("awake"); }
    }
    Connections {
        target: Notifications
        enabled: root.armed
        function onDndChanged() { if (!GameMode.wanted) root.show("silent"); }
    }
    Connections {
        target: PowerProfiles
        enabled: root.armed
        function onProfileChanged() { root.show("power"); }
    }

    function toggleView(icon, label, on, onText, offText, sub) {
        return { icon, level: -1, label: label, value: -1, toggle: true, text: (on ? (onText ?? Tr.t("On")) : (offText ?? Tr.t("Off"))), sub: (sub ?? ""), dimmed: !on };
    }

    Timer { id: mediaDelay; interval: 250; onTriggered: root.show("media") }

    readonly property var view: {
        const vol = sink?.volume ?? 0;
        switch (kind) {
        case "volume": return {
            icon: sink?.muted ? "volume-x" : "volume",
            level: Icons.volumeLevel(vol),
            label: sink?.muted ? Tr.t("Muted") : Tr.t("Volume"),
            value: vol / Config.maxVolume,
            text: sink?.muted ? "--" : String(Math.round(vol * 100)),
            sub: "",
            dimmed: sink?.muted ?? false,
        };
        case "mic": return toggleView(source?.muted ? "mic-off" : "mic", Tr.t("Microphone"), !(source?.muted ?? false));
        case "brightness": return {
            icon: "sun",
            level: -1,
            label: Tr.t("Brightness"),
            value: Brightness.value,
            text: String(Math.round(Brightness.value * 100)),
            sub: "",
            dimmed: false,
        };
        case "airplane": return toggleView(Hardware.airplane ? "airplane" : "airplane-off", Tr.t("Airplane mode"), Hardware.airplane);
        case "touchpad": return toggleView(Hardware.touchpad ? "touchpad" : "touchpad-off", Tr.t("Touchpad"), Hardware.touchpad);
        case "camera": {
            const cam = Hardware.camera;
            if (Hardware.cameraHint)
                return { icon: cam ? "camera" : "camera-off", level: -1, label: Tr.t("Camera"), value: -1,
                         text: cam ? Tr.t("On") : Tr.t("Off"), sub: Tr.t("Use the side switch"), dimmed: !cam };
            return toggleView(cam ? "camera" : "camera-off", Tr.t("Camera"), cam);
        }
        case "wifi": return toggleView(Networking.wifiEnabled ? "wifi" : "wifi-off", Tr.t("Wi-Fi"), Networking.wifiEnabled);
        case "bluetooth": return toggleView("bluetooth", Tr.t("Bluetooth"), BluetoothCtl.enabled);
        case "night": return toggleView("sunset", Tr.t("Night light"), NightLight.active);
        case "awake": return toggleView(KeepAwake.icon, Tr.t("Keep awake"), KeepAwake.active,
                                        KeepAwake.mode === "display" ? Tr.t("Screen on") : Tr.t("No sleep"));
        case "silent": return toggleView(Notifications.dnd ? "bell-off" : "bell", Tr.t("Notifications"), !Notifications.dnd, Tr.t("On"), Tr.t("Silent"));
        case "fnlock": return toggleView("keyboard", Tr.t("Fn lock"), Hardware.fnLock);
        case "vrr": return toggleView("refresh", Tr.t("Adaptive sync"), Hardware.vrr);
        case "power": return { icon: Power.icon(Power.profile), level: -1, label: Tr.t("Power mode"), value: -1, toggle: true,
                               text: Power.name(Power.profile), sub: "", dimmed: false };
        case "layout": return {
            icon: "keyboard",
            level: -1,
            label: Tr.t("Keyboard"),
            value: -1,
            text: Keyboard.name || Keyboard.code,
            sub: Keyboard.layouts.map(l => l.toUpperCase()).join(" · "),
            dimmed: false,
        };
        case "media": return {
            icon: Media.active?.isPlaying ? "play" : "pause",
            level: -1,
            label: Media.active?.isPlaying ? Tr.t("Now playing") : Tr.t("Paused"),
            value: -1,
            text: Media.active?.trackTitle || Media.active?.identity || "",
            sub: Media.active?.trackArtist || "",
            dimmed: !(Media.active?.isPlaying ?? false),
        };
        }
        return { icon: "", level: -1, label: "", value: 0, text: "", sub: "", dimmed: false };
    }
}
