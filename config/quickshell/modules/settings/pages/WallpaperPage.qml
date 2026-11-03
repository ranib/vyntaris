import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import Quickshell
import QtQuick.Dialogs

SettingsPage {
    pageId: "wallpaper"

    SettingsRow {
        title: Tr.t("Wallpaper")
        Button { icon: "image"; text: Tr.t("Open"); onClicked: Panels.wallpaperOpen = true }
    }
    SettingsRow {
        title: Tr.t("Folder")
        Button { icon: "folder"; text: Config.wallpaper.directory.replace(/^~\//, ""); onClicked: folderDialog.open() }
    }
    // Picked, not typed: the system's folder chooser, starting in the folder it is now.
    FolderDialog {
        id: folderDialog
        title: Tr.t("Folder")
        currentFolder: "file://" + Config.wallpaper.directory.replace(/^~/, Quickshell.env("HOME"))
        onAccepted: {
            const path = decodeURIComponent(String(selectedFolder).replace(/^file:\/\//, ""));
            const home = Quickshell.env("HOME");
            Config.wallpaper.directory = path === home ? "~" : path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
            Config.saveSoon();
        }
    }
    SettingsRow {
        title: Tr.t("Fit")
        Choice {
            options: [{ value: "crop", label: Tr.t("Fill") }, { value: "fit", label: Tr.t("Fit") }, { value: "stretch", label: Tr.t("Stretch") }]
            current: Config.wallpaper.fillMode
            onPicked: v => { Config.wallpaper.fillMode = v; Config.saveSoon(); }
        }
    }
}
