import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import "../../components/Slant.js" as Slant
import "../../services/Terminal.js" as Terminal
import qs.services

Item {
    id: root
    readonly property real fullWidth: Updates.upgrading ? Math.max(460, Math.ceil(lines.averageCharacterWidth * 72) + 64) : 460
    readonly property real hang: Updates.upgrading ? console_.height + Theme.space4 + 20 : Math.min(list.contentHeight, 260)
        + (deskColumn.visible ? deskColumn.implicitHeight + 14 : 0)
        + (fwColumn.visible ? fwColumn.implicitHeight + 14 : 0)
        + (heldColumn.visible ? heldColumn.implicitHeight + 14 : 0)
        + (Updates.packages.length > 0 ? 104 : Updates.checking || Updates.failed ? 56 : 12)
    function out(y) { return Theme.slanted ? Slant.out(height, Theme.barHeight, y) : 0; }
    readonly property bool active: Panels.updatesOpen

    width: fullWidth
    height: Theme.barHeight + hang

    Component.onCompleted: if (active) activeChanged()
    onActiveChanged: if (active) { Updates.check(); Updates.checkFirmware(); }

    PanelHeader {
        icon: "package-update"
        title: Updates.upgrading ? Tr.t("Updating…") : Updates.count === 1 ? Tr.t("1 update") : Updates.count > 1 ? Tr.f("{0} updates", Updates.count) : Updates.firmware.length > 0 ? Tr.t("Firmware")
            : Updates.failed ? Tr.t("Couldn't check") : Tr.t("Up to date")
        Spinner { visible: Updates.upgrading; size: 14 }
        HeaderButton {
            visible: !Updates.upgrading
            icon: "refresh"
            label: Tr.t("Check again")
            onClicked: { Updates.check(); Updates.checkFirmware(); }
            RotationAnimation on rotation { running: Updates.checking; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
        }
    }

    ListView {
        id: list
        readonly property real widest: root.out(y)
        function lane(row) { return row ? widest - root.out(y + row.y - contentY + row.height) : 0; }
        x: Theme.panelInset - widest
        y: Theme.panelTop
        width: parent.width - 2 * Theme.panelInset + 2 * widest
        height: Updates.upgrading ? 0 : Math.min(contentHeight, 260)
        visible: !Updates.upgrading
        clip: true
        model: Updates.desktop ? Updates.packages.filter(p => p.name !== "vyntaris") : Updates.packages
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: pkgRow
            required property var modelData
            width: list.width
            height: 26
            RowLayout {
                x: list.lane(pkgRow)
                width: parent.width - 2 * x
                height: parent.height
                spacing: Theme.space10
                Label { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; font.pixelSize: Theme.fontSizeLabel; text: pkgRow.modelData.name }
                Label { visible: pkgRow.modelData.aur; overline: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.overlay1; text: Tr.t("AUR") }
                Label { mono: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.overlay0; text: pkgRow.modelData.from }
                Icon { name: "chevron-right"; size: 11; color: Theme.overlay0 }
                Label { mono: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.accentInk; text: pkgRow.modelData.to }
            }
        }
    }

    ColumnLayout {
        id: deskColumn
        x: 20 - root.out(y + implicitHeight)
        y: list.y + list.height + 10
        width: parent.width - 40 + 2 * root.out(y + implicitHeight)
        visible: Updates.desktop !== null && !Updates.upgrading
        spacing: Theme.space6

        RowLayout {
            Layout.fillWidth: true
            Icon { name: "vyntaris"; size: 16; color: Theme.accentInk }
            Label { Layout.fillWidth: true; overline: true; color: Theme.accentInk; text: Tr.f("Vyntaris {0}", Updates.desktop?.to ?? "") }
            ChipButton { visible: Updates.held.length === 0 && Updates.packages.length === 0; text: Updates.upgrading ? Tr.t("Updating…") : Tr.t("Update"); onClicked: Updates.upgrade() }
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.subtext0
            text: Tr.f("A new version of the desktop, from {0}", Updates.desktop?.from ?? "")
        }
    }

    ColumnLayout {
        id: fwColumn
        x: 20 - root.out(y + implicitHeight)
        y: list.y + list.height + (deskColumn.visible ? deskColumn.implicitHeight + 20 : 10)
        width: parent.width - 40 + 2 * root.out(y + implicitHeight)
        visible: Updates.firmware.length > 0 && !Updates.upgrading
        spacing: Theme.space6
        RowLayout {
            Layout.fillWidth: true
            Icon { name: "cpu"; size: 16; color: Theme.accentInk }
            Label { Layout.fillWidth: true; overline: true; color: Theme.accentInk; text: Tr.t("Firmware") }
            ChipButton { text: Tr.t("Update"); onClicked: { Panels.updatesOpen = false; Updates.upgradeFirmware(); } }
        }
        Repeater {
            model: Updates.firmware
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.space10
                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: Theme.fontSizeLabel; text: modelData.name }
                Label { mono: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.overlay0; text: modelData.from }
                Icon { name: "chevron-right"; size: 11; color: Theme.overlay0 }
                Label { mono: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.accentInk; text: modelData.to }
            }
        }
    }

    ColumnLayout {
        id: heldColumn
        x: 20 - root.out(y + implicitHeight)
        y: list.y + list.height + (deskColumn.visible ? deskColumn.implicitHeight + 10 : 0)
            + (fwColumn.visible ? fwColumn.implicitHeight + 10 : 0) + 10
        width: parent.width - 40 + 2 * root.out(y + implicitHeight)
        visible: Updates.held.length > 0 && !Updates.upgrading
        spacing: Theme.space6
        RowLayout {
            Layout.fillWidth: true
            Icon { name: "schedule"; size: 16; color: Theme.accentInk }
            Label { Layout.fillWidth: true; overline: true; color: Theme.accentInk; text: Tr.t("Waiting for Vyntaris") }
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.subtext0
            text: Tr.f("{0} isn't tested with Vyntaris yet. The update waits until it is, usually a day.",
                Updates.held.map(p => p.name + " " + p.to).join(", "))
        }
    }

    Item {
        id: console_
        readonly property var colours: ({ red: Theme.error, green: Theme.success, yellow: Theme.yellow, blue: Theme.accentInk,
            magenta: Theme.mauve, cyan: Theme.sky, white: Theme.overlay1, dim: Theme.overlay0 })
        y: Theme.panelTop + Theme.space4
        width: parent.width
        height: Updates.upgrading ? lines.lineSpacing * Math.max(1, Updates.output.length) : 0
        visible: Updates.upgrading
        FontMetrics { id: lines; font.family: Theme.monoFamily; font.pixelSize: Theme.fontSizeSmall }
        Repeater {
            model: Updates.output
            Item {
                id: termRow
                required property var modelData
                required property int index
                readonly property var parts: Terminal.split(modelData)
                readonly property real lean: root.out(console_.y + y + lines.lineSpacing)
                readonly property real pad: 20 + Theme.space4
                width: console_.width
                height: lines.lineSpacing
                y: index * lines.lineSpacing
                Text {
                    id: leftText
                    x: termRow.pad - termRow.lean
                    font: lines.font
                    color: Theme.text
                    textFormat: Text.StyledText
                    text: Terminal.html(termRow.parts.left, console_.colours)
                }
                Text {
                    readonly property real end: termRow.width - termRow.pad + termRow.lean
                    readonly property int cells: Math.floor((end - leftText.x - leftText.implicitWidth) / lines.averageCharacterWidth) - 1
                    x: end - implicitWidth
                    font: lines.font
                    color: Theme.text
                    textFormat: Text.StyledText
                    text: Terminal.html(Terminal.candy(termRow.parts.right, cells), console_.colours)
                }
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barHeight + 30
        visible: Updates.count === 0 && Updates.checking && !Updates.upgrading
        spacing: Theme.space8
        Spinner { anchors.verticalCenter: parent.verticalCenter; size: 14 }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.overlay1
            text: Tr.t("Checking…")
        }
    }
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barHeight + 30
        visible: Updates.count === 0 && Updates.failed && !Updates.checking && !Updates.upgrading
        color: Theme.overlay1
        text: Tr.t("No connection to the update servers. It's checked again later.")
    }

    RowLayout {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.space16 }
        spacing: Theme.space12

        Button {
            visible: Updates.packages.length > 0 && !Updates.upgrading
            primary: Updates.held.length === 0
            icon: "arrow-down"
            text: Updates.upgrading ? Tr.t("Updating…") : Updates.held.length > 0 ? Tr.t("Update anyway") : Tr.t("Update now")
            busy: Updates.upgrading
            onClicked: Updates.upgrade()
        }
        Button {
            visible: Updates.lastResult === "failed" && !Updates.upgrading && Updates.packages.length > 0
            icon: "terminal"
            text: Tr.t("Finish in a terminal")
            onClicked: { Panels.updatesOpen = false; Updates.upgradeInTerminal(); }
        }
    }
}
