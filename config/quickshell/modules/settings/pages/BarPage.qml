import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import "../../../components/BarStyles.js" as BarStyles

SettingsPage {
    pageId: "bar"

    SettingsRow {
        title: Tr.t("Clock")
        Choice {
            options: [{ value: "time", label: Tr.t("Time") }, { value: "date", label: Tr.t("Date") }, { value: "both", label: Tr.t("Both") }]
            current: Config.bar.clockShow
            onPicked: v => { Config.bar.clockShow = v; Config.saveSoon(); }
        }
    }
    SettingsRow {
        visible: Config.bar.clockShow !== "date"
        title: Tr.t("Time format")
        Choice {
            options: [{ value: "HH:mm", label: Tr.t("24-hour") }, { value: "h:mm AP", label: Tr.t("12-hour") }, { value: "HH:mm:ss", label: Tr.t("Seconds") }]
            current: Config.bar.clockFormat
            onPicked: v => { Config.bar.clockFormat = v; Config.saveSoon(); }
        }
    }
    SettingsRow {
        title: Tr.t("Window title")
        Switch { checked: Config.bar.showWindowTitle; onToggled: on => { Config.bar.showWindowTitle = on; Config.saveSoon(); } }
    }
    SettingsRow {
        title: Tr.t("Workspace icons")
        Switch { checked: Config.bar.workspaceIcons; onToggled: on => { Config.bar.workspaceIcons = on; Config.saveSoon(); } }
    }
    SettingsRow {
        visible: Config.bar.workspaceIcons
        title: Tr.t("Icons")
        Choice {
            options: [{ value: true, label: Tr.t("Accent") }, { value: false, label: Tr.t("Default") }]
            current: Config.bar.workspaceIconsAccent
            onPicked: v => { Config.bar.workspaceIconsAccent = v; Config.saveSoon(); }
        }
    }
    SettingsRow {
        title: Tr.t("Privacy indicator")
        Switch { checked: Config.bar.privacy; onToggled: on => { Config.bar.privacy = on; Config.saveSoon(); } }
    }
    SettingsRow {
        visible: Gpu.present
        title: Tr.t("NVIDIA GPU indicator")
        Switch { checked: Config.bar.gpu; onToggled: on => { Config.bar.gpu = on; Config.saveSoon(); } }
    }

    SettingsRow {
        title: Tr.t("Height")
        Choice {
            options: [{ value: 28, label: Tr.t("Compact") }, { value: 32, label: Tr.t("Normal") }, { value: 36, label: Tr.t("Tall") }]
            current: Config.bar.height
            onPicked: v => { Config.bar.height = v; Config.saveSoon(); }
        }
    }
    SettingsRow {
        title: Tr.t("Style")
        Row {
            spacing: Theme.space8
            Repeater {
                model: BarStyles.styles
                Rectangle {
                    id: styleTile
                    required property var modelData
                    readonly property bool current: BarStyles.current(Config.bar) === modelData.id
                    readonly property var look: BarStyles.preview(modelData.id)
                    width: 92; height: 74; radius: 12
                    clip: true
                    color: current ? Theme.tint(parent, Theme.text, 0.06) : styleArea.containsMouse ? Theme.hoverOn(parent) : Theme.tint(parent, Theme.text, 0.04)
                    border { width: current ? 2 : 1; color: current ? Theme.accent : Theme.rimOn(parent) }
                    Behavior on color { ColorAnim {} }
                    BarShape {
                        x: 1; y: 8
                        width: parent.width - 2
                        height: 40
                        barHeight: 9
                        corner: 0
                        shoulder: styleTile.look.square ? 0 : 8
                        radius: styleTile.look.radius
                        square: styleTile.look.square
                        notchCorner: styleTile.look.notchCorner
                        style: styleTile.look.style
                        drawers: styleTile.look.flat ? [] : [{ center: width / 2, width: 42, hang: 22 }]
                    }
                    Label {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.space8 }
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: styleTile.current ? Font.DemiBold : Font.Normal
                        color: styleTile.current ? Theme.text : Theme.subtext0
                        text: Tr.t(styleTile.modelData.label)
                    }
                    PressArea {
                        label: Tr.t(styleTile.modelData.label)
                        role: Accessible.RadioButton
                        checked: styleTile.current
                        id: styleArea
                        anchors.fill: parent
                        onClicked: { BarStyles.apply(Config.bar, styleTile.modelData.id); Config.saveSoon(); }
                    }
                }
            }
        }
    }

    SettingsRow {
        title: Tr.t("Corners")
        Choice {
            options: [{ value: true, label: Tr.t("Curved") }, { value: false, label: Tr.t("Flat") }]
            current: Config.bar.endCorners
            onPicked: v => { Config.bar.endCorners = v; Config.saveSoon(); }
        }
    }

    SettingsRow {
        title: Tr.t("Panels")
        Choice {
            options: [{ value: "rounded", label: Tr.t("Rounded") }, { value: "soft", label: Tr.t("Soft") }, { value: "sharp", label: Tr.t("Sharp") }]
            current: Config.bar.inside
            onPicked: v => { Config.bar.inside = v; Config.saveSoon(); }
        }
    }

    SettingsSection { text: Tr.t("Screen recording") }
    SettingsRow {
        title: Tr.t("Countdown")
        Choice {
            options: [{ value: 0, label: Tr.t("Off") }, { value: 3, label: Tr.t("3 s") }, { value: 5, label: Tr.t("5 s") }]
            current: Config.live.countdown
            onPicked: v => { Config.live.countdown = v; Config.saveSoon(); }
        }
    }
}
