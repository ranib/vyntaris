import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import "../../../config/Palettes.js" as Palettes

SettingsPage {
    pageId: "appearance"

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
        Field { implicitWidth: 100; mono: true; text: Config.theme.lightFrom; onCommitted: t => { Config.theme.lightFrom = t.trim(); Config.saveSoon(); } }
    }
    SettingsRow {
        visible: Config.theme.autoFlavor
        title: Tr.t("Dark from")
        Field { implicitWidth: 100; mono: true; text: Config.theme.darkFrom; onCommitted: t => { Config.theme.darkFrom = t.trim(); Config.saveSoon(); } }
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
        Field { implicitWidth: 220; text: Config.theme.fontFamily; placeholder: "Inter"; onCommitted: t => { Config.theme.fontFamily = t.trim(); Config.saveSoon(); } }
    }
    SettingsRow {
        title: Tr.t("Monospace font")
        Field { implicitWidth: 220; mono: true; text: Config.theme.monoFamily; placeholder: "JetBrains Mono"; onCommitted: t => { Config.theme.monoFamily = t.trim(); Config.saveSoon(); } }
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
    SettingsRow {
        title: Tr.t("Animation style")
        Choice {
            options: [{ value: "bouncy", label: Tr.t("Bouncy") }, { value: "smooth", label: Tr.t("Smooth") }, { value: "snappy", label: Tr.t("Snappy") }]
            current: Config.theme.animationStyle
            onPicked: v => { Config.theme.animationStyle = v; Config.saveSoon(); }
        }
    }
    SettingsRow {
        title: Tr.t("Windows open")
        Choice {
            options: [{ value: "slidevert", label: Tr.t("Rise") }, { value: "popin", label: Tr.t("Pop") }, { value: "fade", label: Tr.t("Fade") }]
            current: Config.theme.windowAnimation
            onPicked: v => { Config.theme.windowAnimation = v; Config.saveSoon(); }
        }
    }
    SettingsRow {
        title: Tr.t("Workspace switch")
        Choice {
            options: [{ value: "slidevert", label: Tr.t("Vertical") }, { value: "slide", label: Tr.t("Sideways") }, { value: "fade", label: Tr.t("Fade") }]
            current: Config.theme.workspaceAnimation
            onPicked: v => { Config.theme.workspaceAnimation = v; Config.saveSoon(); }
        }
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
