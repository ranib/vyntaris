import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.config
import qs.services
import "../../config/Wallpapers.js" as Walls

Scope {
    component Key: GlobalShortcut {
        property var run: () => {}
        property bool down: false
        onPressed: { down = true; run(); }
        onReleased: { if (!down) run(); down = false; }
    }
    Key { name: "control"; run: () => Panels.controlOpen = !Panels.controlOpen }
    Key { name: "apps"; run: () => Panels.appsOpen = !Panels.appsOpen }
    Key { name: "run"; run: () => Panels.search(">") }
    Key { name: "files"; run: () => Panels.search("/") }
    Key { name: "emoji"; run: () => Panels.search(";") }
    Key { name: "clipboard"; run: () => Panels.search(":") }
    Key { name: "power"; run: () => Panels.powerOpen = !Panels.powerOpen }
    Key { name: "wallpaper"; run: () => Panels.wallpaperOpen = !Panels.wallpaperOpen }
    Key { name: "timer"; run: () => Panels.timerOpen = !Panels.timerOpen }
    Key { name: "sound"; run: () => Panels.soundOpen = !Panels.soundOpen }

    IpcHandler {
        target: "launcher"
        function toggle(): void { Panels.launcherOpen = !Panels.launcherOpen }
        function open(): void { Panels.launcherOpen = true }
        function close(): void { Panels.launcherOpen = false }
        function query(text: string): void {
            Panels.launcherQuery = text;
            Panels.launcherOpen = true;
        }
    }

    IpcHandler {
        target: "island"
        function open(name: string): void { if (Panels.islandPanels.includes(name)) Panels[name + "Open"] = true }
        function toggle(name: string): void { if (Panels.islandPanels.includes(name)) Panels[name + "Open"] = !Panels[name + "Open"] }
        function close(): void { Panels.closeAll() }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void { Panels.controlOpen = !Panels.controlOpen }
        function open(): void { Panels.controlOpen = true }
        function close(): void { Panels.controlOpen = false }
    }

    IpcHandler {
        target: "system"
        function toggle(): void { Panels.systemOpen = !Panels.systemOpen }
        function open(): void { Panels.systemOpen = true }
        function close(): void { Panels.systemOpen = false }
    }

    IpcHandler {
        target: "battery"
        function toggle(): void { Panels.batteryOpen = !Panels.batteryOpen }
        function open(): void { Panels.batteryOpen = true }
        function close(): void { Panels.batteryOpen = false }
    }

    Process {
        id: randomWallpaper
        command: ["sh", "-c", 'find "$1" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.heic" -o -iname "*.heif" \\) | sort',
                  "sh", Config.expandHome(Config.wallpaper.directory)]
        stdout: StdioCollector {
            onStreamFinished: {
                const current = Config.expandHome(Config.wallpaper.path);
                const others = Walls.group(text.split("\n").filter(p => p), Theme.isDark).filter(e => !Walls.same(e.path, current));
                if (others.length === 0) return;
                Config.wallpaper.path = others[Math.floor(Math.random() * others.length)].path;
                Config.save();
            }
        }
    }

    IpcHandler {
        target: "wallpaper"
        function random(): void { randomWallpaper.running = true }
        function set(path: string): void { if (path) { Config.wallpaper.path = (/\.hei[cf]$/i.test(path) ? "heic:" : "") + path; Config.save(); } }
        function toggle(): void { Panels.wallpaperOpen = !Panels.wallpaperOpen }
        function open(): void { Panels.wallpaperOpen = true }
        function close(): void { Panels.wallpaperOpen = false }
    }

    IpcHandler {
        target: "control"
        function toggle(): void { Panels.controlOpen = !Panels.controlOpen }
        function open(): void { Panels.controlOpen = true }
        function close(): void { Panels.controlOpen = false }
    }

    IpcHandler {
        target: "player"
        function toggle(): void { Panels.mediaOpen = !Panels.mediaOpen }
        function open(): void { Panels.mediaOpen = true }
        function close(): void { Panels.mediaOpen = false }
    }

    IpcHandler {
        target: "updates"
        function toggle(): void { Panels.updatesOpen = !Panels.updatesOpen }
        function open(): void { Panels.updatesOpen = true }
        function close(): void { Panels.updatesOpen = false }
    }

    IpcHandler {
        target: "overview"
        function toggle(): void { Panels.overviewOpen = !Panels.overviewOpen }
        function open(): void { Panels.overviewOpen = true }
        function close(): void { Panels.overviewOpen = false }
    }

    IpcHandler {
        target: "privacy"
        function toggle(): void { Panels.privacyOpen = !Panels.privacyOpen }
        function status(): string { return Privacy.entries.map(e => e.kind + ":" + e.app).join("\n") }
    }

    IpcHandler {
        target: "timer"
        function toggle(): void { Panels.timerOpen = !Panels.timerOpen }
        function start(duration: string): void { Chrono.startTimer(Chrono.parseDuration(duration)) }
        function pause(): void { Chrono.toggleTimer() }
        function cancel(): void { Chrono.cancelTimer() }
        function stopwatch(): void { Chrono.toggleStopwatch() }
        function reset(): void { Chrono.resetStopwatch() }
    }

    IpcHandler {
        target: "activity"
        function banner(icon: string, title: string, sub: string): void { Activities.banner(icon || "bell", title, sub, -1) }
        function list(): string { return JSON.stringify(Activities.items.map(i => ({ kind: i.kind, text: i.text }))) }
        function progress(title: string, percent: int): void { Activities.banner("refresh", title, percent + "%", percent / 100, undefined, 2500) }
    }

    IpcHandler {
        target: "gamemode"
        function toggle(): void { GameMode.toggle() }
        function panel(): void { Panels.gameOpen = true }
        function status(): string { return GameMode.active ? "on" : "off" }
    }

    IpcHandler {
        target: "wifi"
        function toggle(): void { Panels.wifiOpen = !Panels.wifiOpen }
    }

    IpcHandler {
        target: "wiki"
        function open(): void { Panels.wiki() }
        function toggle(): void { if (Panels.wikiOpen) Panels.wikiOpen = false; else Panels.wiki() }
        function search(query: string): void { Panels.wiki(query) }
    }

    IpcHandler {
        target: "vpn"
        function toggle(): void { Panels.vpnOpen = !Panels.vpnOpen }
    }

    IpcHandler {
        target: "apps"
        function toggle(): void { Panels.appsOpen = !Panels.appsOpen }
        function open(): void { Panels.appsOpen = true }
        function close(): void { Panels.appsOpen = false }
    }

    IpcHandler {
        target: "health"
        function open(): void { Panels.openApp("doctor") }
        function close(): void { Panels.closeApp("doctor") }
        function toggle(): void { Panels.openApp("doctor", "toggle") }
    }

    IpcHandler {
        target: "switcher"
        function next(): void { Panels.overview(1) }
        function previous(): void { Panels.overview(-1) }
        function commit(): void { Panels.overviewCommit() }
    }

    IpcHandler {
        target: "nightlight"
        function toggle(): void { NightLight.toggle() }
        function panel(): void { Panels.nightOpen = true }
        function status(): string { return NightLight.active ? "on" : "off" }
    }

    IpcHandler {
        target: "capture"
        function open(): void { Panels.captureOpen = true }
        function toggle(): void { Panels.captureOpen = !Panels.captureOpen }
    }
    IpcHandler {
        target: "phone"
        function toggle(): void { Panels.phoneOpen = !Panels.phoneOpen }
        function open(): void { Panels.phoneOpen = true }
        function ring(): void { if (Phone.phone) Phone.ring(Phone.phone.id) }
        function status(): string { return !Phone.enabled ? "off" : Phone.phone ? Phone.phone.name : "not connected" }
    }

    IpcHandler {
        target: "bluetooth_menu"
        function toggle(): void { Panels.bluetoothOpen = !Panels.bluetoothOpen }
        function open(): void { Panels.bluetoothOpen = true }
    }
    IpcHandler {
        target: "network"
        function open(): void { Panels.wifiOpen = true }
    }

    IpcHandler {
        target: "record"
        function toggle(): void { Recorder.toggle("region") }
        function region(): void { Panels.closeAll(); Recorder.start("region") }
        function screen(): void { Panels.closeAll(); Recorder.start("screen") }
        function stop(): void { Recorder.stop() }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { LockState.lock() }
        function woke(): void { LockState.woke() }
        function preview(): void { LockState.preview = !LockState.preview }
        function status(): string { return LockState.locked ? "locked" : "unlocked" }
    }

    IpcHandler {
        target: "accessibility"
        function contrast(): void { Config.accessibility.highContrast = !Config.accessibility.highContrast; Config.save() }
    }

    IpcHandler {
        target: "notifications"
        function clear(): void { Notifications.clearHistory() }
        function silent(): void { Notifications.dnd = !Notifications.dnd }
    }

    IpcHandler {
        target: "session"
        function preview(kind: string): void { Leaving.preview(kind || "shutdown") }
        function leave(kind: string): void { if (["reboot", "shutdown", "logout"].includes(kind)) Leaving.run(kind, Config.power[kind]) }
        function lid(): void { Sleep.lidClosed() }
    }

    IpcHandler {
        target: "hardware"
        function airplane(): void { Hardware.toggleAirplane() }
        function airplaneKey(): void { Hardware.airplaneKey() }
        function touchpad(): void { Hardware.toggleTouchpad() }
        function touchpadOn(): void { Hardware.setTouchpad(true) }
        function touchpadOff(): void { Hardware.setTouchpad(false) }
        function camera(): void { Hardware.cameraKey() }
        function vrr(): void { Hardware.toggleVrr() }
        function powerMode(): void { Power.cycle() }
    }

    IpcHandler {
        target: "bluetooth"
        function toggle(): void { BluetoothCtl.toggle() }
        function on(): void { BluetoothCtl.setEnabled(true) }
        function off(): void { BluetoothCtl.setEnabled(false) }
        function status(): string { return BluetoothCtl.enabled ? "on" : "off" }
    }

    IpcHandler {
        target: "keyboard"
        function next(): void { Keyboard.next() }
        function open(): void { Panels.keyboard() }
        function switchLayout(): void { if (Keyboard.entries.length > 1) Keyboard.next(); else Panels.keyboard(); }
    }

    IpcHandler {
        target: "help"
        function toggle(): void { Panels.openApp("help", "toggle") }
        function open(): void { Panels.openApp("help") }
    }

    IpcHandler {
        target: "store"
        function open(): void { Panels.openApp("store") }
        function close(): void { Panels.closeApp("store") }
        function toggle(): void { Panels.openApp("store", "toggle") }
        function search(text: string): void { Panels.store(text) }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { Panels.openApp("settings", "toggle") }
        function page(name: string): void { Panels.settings(name) }
        function search(text: string): void { Panels.settingsSearch(text) }
        function open(): void { Panels.openApp("settings") }
        function close(): void { Panels.closeApp("settings") }
    }

    IpcHandler {
        target: "awake"
        function toggle(): void { KeepAwake.toggle() }
        function display(): void { KeepAwake.set("display") }
        function system(): void { KeepAwake.set("system") }
        function off(): void { KeepAwake.set("off") }
        function panel(): void { Panels.awakeOpen = !Panels.awakeOpen }
    }

    IpcHandler {
        target: "screenshot"
        function region(): void { Screenshot.capture("region") }
        function screen(): void { Screenshot.capture("screen") }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { Panels.powerOpen = !Panels.powerOpen }
        function open(): void { Panels.powerOpen = true }
        function close(): void { Panels.powerOpen = false }
    }

    IpcHandler {
        target: "brightness"
        function up(): void { Brightness.step(0.05) }
        function down(): void { Brightness.step(-0.05) }
        function dim(): void { Brightness.dim() }
        function restore(): void { Brightness.restore() }
    }

    IpcHandler {
        target: "media"
        function toggle(): void { Media.toggle() }
        function next(): void { Media.next() }
        function previous(): void { Media.previous() }
    }
}
