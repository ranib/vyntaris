import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import Quickshell.Io
import "../../../config/Palettes.js" as Palettes

SettingsPage {
    id: page
    pageId: "appearance"

    // Which list is open under its row ("" for none): every value here is picked, none typed.
    property string open: ""
    function toggle(which) { open = open === which ? "" : which; }
    readonly property var times: {
        const out = [];
        for (let m = 0; m < 24 * 60; m += 15) out.push(String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0"));
        return out;
    }
    function timeRows(q) {
        const k = q.replace(/[^0-9]/g, "");
        return times.filter(t => !k || t.replace(":", "").includes(k)).map(t => ({ value: t, title: t }));
    }
    readonly property var fonts: Qt.fontFamilies().filter(f => !f.startsWith(".") && !/emoji|^Symbols|nerd font/i.test(f))
    property var monoFonts: []
    Process {
        running: true
        command: ["fc-list", ":spacing=mono", "family"]
        stdout: StdioCollector { onStreamFinished: page.monoFonts = [...new Set(text.split("\n").map(l => l.split(",")[0].trim()).filter(l => l && !/nerd font|^Symbols/i.test(l)))].sort((a, b) => a.localeCompare(b)) }
    }
    function fontRows(list, q) {
        const k = q.trim().toLowerCase();
        return list.filter(f => !k || f.toLowerCase().includes(k)).map(f => ({ value: f, title: f }));
    }

    SettingsSection { text: Tr.t("Style") }
    SettingsRow {
        title: Tr.t("Theme")
        Choice {
            options: [{ value: "mocha", label: Tr.t("Dark") }, { value: "latte", label: Tr.t("Light") }, { value: "auto", label: Tr.t("Auto") }]
            current: Config.theme.autoFlavor ? "auto" : Config.theme.flavor
            onPicked: v => {
                Config.theme.autoFlavor = v === "auto";
                if (v !== "auto") Config.theme.flavor = v;
                if (v === "mocha") Config.theme.darkFlavor = v;
                Config.saveSoon();
            }
        }
    }
    SettingsRow {
        visible: Config.theme.autoFlavor
        title: Tr.t("Light from")
        Button { id: lightButton; icon: "sun"; text: Config.theme.lightFrom; onClicked: page.toggle("light") }
    }
    SettingsPicker {
        anchor: lightButton
        shown: Config.theme.autoFlavor && page.open === "light"
        placeholder: Tr.t("Search…")
        current: Config.theme.lightFrom
        results: page.timeRows(query)
        onPicked: v => { Config.theme.lightFrom = v; Config.saveSoon(); page.open = ""; }
        onClosed: page.open = ""
    }
    SettingsRow {
        visible: Config.theme.autoFlavor
        title: Tr.t("Dark from")
        Button { id: darkButton; icon: "moon"; text: Config.theme.darkFrom; onClicked: page.toggle("dark") }
    }
    SettingsPicker {
        anchor: darkButton
        shown: Config.theme.autoFlavor && page.open === "dark"
        current: Config.theme.darkFrom
        results: page.timeRows(query)
        onPicked: v => { Config.theme.darkFrom = v; Config.saveSoon(); page.open = ""; }
        onClosed: page.open = ""
    }
    SettingsRow {
        title: Tr.t("Accent")
        Row {
            spacing: Theme.space12
            Caption {
                anchors.verticalCenter: parent.verticalCenter
                text: Config.theme.wallpaperAccent ? Tr.t("From wallpaper") : Theme.accentLabel(Theme.accentName)
            }
          Grid {
            anchors.verticalCenter: parent.verticalCenter
            columns: 8
            spacing: Theme.space8
            Repeater {
                model: Palettes.accentChoices
                AccentSwatch { required property string modelData; accent: modelData; size: 24 }
            }
          }
        }
    }
    SettingsRow {
        title: Tr.t("Accent from wallpaper")
        RowLayout {
            spacing: Theme.space10
            Rectangle {
                visible: WallpaperColors.ready && WallpaperColors.chosen !== ""
                implicitWidth: 18; implicitHeight: 18; radius: 9
                color: Theme.colorOf(WallpaperColors.chosen)
                border { width: 1; color: Theme.rimOn(parent) }
            }
            Switch { checked: Config.theme.wallpaperAccent; onToggled: on => { Config.theme.wallpaperAccent = on; Config.saveSoon(); } }
        }
    }
    SettingsRow {
        title: Tr.t("Match apps to theme")
        Switch { checked: Config.theme.syncApps; onToggled: on => { Config.theme.syncApps = on; Config.saveSoon(); } }
    }
    SettingsSection { text: Tr.t("Text") }
    SettingsRow {
        title: Tr.t("Text size")
        Choice {
            options: [{ value: 12, label: Tr.t("Small") }, { value: 13, label: Tr.t("Normal") }, { value: 15, label: Tr.t("Large") }, { value: 17, label: Tr.t("Larger") }]
            current: Config.theme.fontSize
            onPicked: v => { Config.theme.fontSize = v; Config.saveSoon(); }
        }
    }
    SettingsRow {
        title: Tr.t("Font")
        Button { id: fontButton; icon: "font"; text: Config.theme.fontFamily || "Inter"; onClicked: page.toggle("font") }
    }
    SettingsPicker {
        anchor: fontButton
        shown: page.open === "font"
        current: Config.theme.fontFamily || "Inter"
        results: page.fontRows(page.fonts, query)
        onPicked: v => { Config.theme.fontFamily = v; Config.saveSoon(); page.open = ""; }
        onClosed: page.open = ""
    }
    SettingsRow {
        title: Tr.t("Monospace font")
        Button { id: monoButton; icon: "terminal"; text: Config.theme.monoFamily || "JetBrains Mono"; onClicked: page.toggle("mono") }
    }
    SettingsPicker {
        anchor: monoButton
        shown: page.open === "mono"
        current: Config.theme.monoFamily || "JetBrains Mono"
        results: page.fontRows(page.monoFonts, query)
        onPicked: v => { Config.theme.monoFamily = v; Config.saveSoon(); page.open = ""; }
        onClosed: page.open = ""
    }
    SettingsSection { text: Tr.t("Motion") }
    SettingsRow {
        title: Tr.t("Animations")
        Choice {
            options: [{ value: 0, label: Tr.t("Off") }, { value: 1, label: Tr.t("Normal") }, { value: 1.5, label: Tr.t("Quick") }]
            current: Config.theme.animationSpeed
            onPicked: v => { Config.theme.animationSpeed = v; Config.saveSoon(); }
        }
    }
    // Vyntaris's own three, then Motion.js's presets: each moves the windows and the shell alike.
    readonly property var styles: [
        { value: "bouncy",   title: Tr.t("Bouncy"),   caption: Tr.t("Springs open, the way Vyntaris does") },
        { value: "smooth",   title: Tr.t("Smooth"),   caption: Tr.t("Eases in and out") },
        { value: "snappy",   title: Tr.t("Snappy"),   caption: Tr.t("Quick, no bounce") },
        { value: "classic",  title: Tr.t("Classic"),  caption: Tr.t("Pops in, eases out") },
        { value: "glide",    title: Tr.t("Glide"),    caption: Tr.t("Slides in with a swing") },
        { value: "brisk",    title: Tr.t("Brisk"),    caption: Tr.t("Quick and straight") },
        { value: "material", title: Tr.t("Material"), caption: Tr.t("Slows into place, speeds away") },
        { value: "drift",    title: Tr.t("Drift"),    caption: Tr.t("Soft, with a little overshoot") },
        { value: "spring",   title: Tr.t("Spring"),   caption: Tr.t("Springs past and settles") },
        { value: "lift",     title: Tr.t("Lift"),     caption: Tr.t("Even, workspaces rise") },
        { value: "calm",     title: Tr.t("Calm"),     caption: Tr.t("One gentle curve for all") },
        { value: "tight",    title: Tr.t("Tight"),    caption: Tr.t("Short, nothing overshoots") },
    ]
    SettingsRow {
        title: Tr.t("Animation style")
        Button { id: styleButton;
            icon: "sliders"
            text: page.styles.find(st => st.value === Config.theme.animationStyle)?.title ?? Config.theme.animationStyle
            onClicked: page.toggle("style")
        }
    }
    SettingsPicker {
        anchor: styleButton
        shown: page.open === "style"
        maxRows: 7
        current: Config.theme.animationStyle
        results: { const k = query.trim().toLowerCase(); return page.styles.filter(st => !k || st.title.toLowerCase().includes(k) || st.caption.toLowerCase().includes(k)); }
        onPicked: v => {
            Config.theme.animationStyle = v;
            Config.saveSoon();
            page.open = "";
        }
        onClosed: page.open = ""
    }
    SettingsSection { text: Tr.t("Sound") }
    SettingsRow {
        title: Tr.t("Login sound")
        Choice {
            options: [{ value: "chime", label: Tr.t("Chime") }, { value: "bloom", label: Tr.t("Bloom") }, { value: "halo", label: Tr.t("Halo") }, { value: "off", label: Tr.t("Off") }]
            current: Config.theme.loginSound
            onPicked: v => {
                Config.theme.loginSound = v; Config.saveSoon();
                if (v !== "off") Quickshell.execDetached(["pw-play", Config.loginSoundPath(v)]);
            }
        }
    }
}
