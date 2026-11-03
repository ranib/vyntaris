import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import "../../components/Slant.js" as Slant
import "../../services/Terminal.js" as Terminal
import qs.services

Item {
    id: root
    readonly property real fullWidth: 640
    readonly property real hang: 268
    function out(y) { return Theme.slanted ? Slant.out(height, Theme.barHeight, y) : 0; }
    readonly property var pk: Activities.packages

    width: fullWidth
    height: Theme.barHeight + hang

    PanelHeader {
        icon: "package-update"
        tint: root.pk?.state === "failed" ? Theme.red : Theme.accent
        title: !root.pk ? Tr.t("Packages")
            : Activities.removing ? Tr.f("Removing · {0}", root.pk.count)
            : Activities.installing ? (root.pk.count > 0 ? Tr.f("Installing · {0}", root.pk.count) : Tr.t("Installing"))
            : root.pk.state === "failed" ? Tr.t("Installation failed")
            : root.pk.state === "done" && root.pk.count > 0 && root.pk.removed === root.pk.count
                ? (root.pk.count === 1 ? Tr.t("1 package removed") : Tr.f("{0} packages removed", root.pk.count))
            : root.pk.state === "done" ? (root.pk.count === 1 ? Tr.t("1 package installed") : Tr.f("{0} packages installed", root.pk.count))
            : Tr.t("Nothing changed")
        Label {
            visible: Activities.installing && (root.pk?.name ?? "") !== ""
            color: Theme.overlay1
            font.family: Theme.monoFamily
            text: root.pk?.name ?? ""
        }
    }

    PanelSurface {
        x: Theme.panelInset - root.out(y + height)
        y: Theme.panelTop
        width: parent.width - 2 * Theme.panelInset + 2 * root.out(y + height)
        height: root.hang - 18
        radius: Theme.r(Theme.radius)

        // What pacman, yay or a terminal is printing, drawn as a terminal draws it, like the updates' console:
        // a line that redraws itself stays one line, in its colours, with the progress bar.
        ListView {
            id: term
            readonly property bool live: (root.pk?.source ?? "log") !== "log"
            readonly property var colours: ({ red: Theme.error, green: Theme.success, yellow: Theme.yellow, blue: Theme.accentInk,
                magenta: Theme.mauve, cyan: Theme.sky, white: Theme.overlay1, dim: Theme.overlay0 })
            visible: live
            anchors { fill: parent; margins: Theme.space10 }
            clip: true
            model: live ? Terminal.screen((root.pk?.lines ?? []).join("\n"), 200) : []
            onCountChanged: if (following) Qt.callLater(positionViewAtEnd)
            property bool following: true
            onMovementEnded: following = atYEnd
            FontMetrics { id: cell; font.family: Theme.monoFamily; font.pixelSize: Theme.fontSizeSmall }
            delegate: Item {
                id: termRow
                required property var modelData
                readonly property var parts: Terminal.split(modelData)
                width: ListView.view.width
                height: cell.lineSpacing
                Text {
                    id: leftText
                    font: cell.font
                    color: Theme.text
                    textFormat: Text.StyledText
                    text: Terminal.html(termRow.parts.left, term.colours)
                }
                Text {
                    readonly property int cells: Math.floor((termRow.width - leftText.implicitWidth) / cell.averageCharacterWidth) - 1
                    anchors.right: parent.right
                    font: cell.font
                    color: Theme.text
                    textFormat: Text.StyledText
                    text: Terminal.html(Terminal.candy(termRow.parts.right, cells), term.colours)
                }
            }
        }
        ListView {
            id: log
            visible: !term.live
            anchors { fill: parent; margins: Theme.space10 }
            clip: true
            model: ListModel { id: shown }
            readonly property var lines: root.pk?.lines ?? []
            onLinesChanged: {
                for (let i = 0; i < lines.length; i++) {
                    if (i >= shown.count) shown.append({ line: lines[i] });
                    else if (shown.get(i).line !== lines[i]) shown.setProperty(i, "line", lines[i]);
                }
                if (shown.count > lines.length) shown.remove(lines.length, shown.count - lines.length);
                if (following) Qt.callLater(positionViewAtEnd);
            }
            property bool following: true
            onMovementEnded: following = atYEnd
            Component.onCompleted: { linesChanged(); positionViewAtEnd(); }
            delegate: Text {
                required property string line
                readonly property string modelData: line
                width: ListView.view.width
                wrapMode: root.pk?.source === "log" ? Text.WrapAnywhere : Text.NoWrap
                elide: root.pk?.source === "log" ? Text.ElideNone : Text.ElideRight
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSizeSmall
                text: modelData
                color: root.pk?.source !== "log" ? (/error|failed/i.test(modelData) ? Theme.error : /^::/.test(modelData) ? Theme.accentInk : Theme.text)
                    : /\[ALPM\] transaction (failed|interrupted)|error|failed/i.test(modelData) ? Theme.red
                    : /\[ALPM\] (installed|upgraded|reinstalled|downgraded) /.test(modelData) ? Theme.green
                    : /\[ALPM\] removed /.test(modelData) ? Theme.peach
                    : /^\[PACMAN\] Running /.test(modelData) ? Theme.accent
                    : Theme.subtext0
            }
        }
        Label {
            anchors.centerIn: parent
            visible: term.live ? term.count === 0 : log.count === 0
            color: Theme.overlay1
            text: Activities.installing ? Tr.t("Starting…") : Tr.t("No install since the shell started")
        }
    }
}
