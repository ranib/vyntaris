import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Scope {
    id: root

    property string path: ""
    readonly property bool shown: path !== ""
    readonly property string name: path.split("/").pop()
    readonly property string ext: name.includes(".") ? name.split(".").pop().toLowerCase() : ""
    readonly property string kind: info.dir ? "folder"
        : ["png", "jpg", "jpeg", "webp", "bmp", "svg", "avif", "tif", "tiff", "ico"].includes(ext) ? "image"
        : ext === "gif" ? "animation"
        : ext === "pdf" ? "pdf"
        : ["mp4", "mkv", "webm", "mov", "avi", "m4v", "ogv"].includes(ext) ? "video"
        : ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac"].includes(ext) ? "audio"
        : ["xlsx", "ods", "vsheet", "csv", "tsv"].includes(ext) ? "sheet"
        : ["docx", "pptx", "odt", "odp", "vdoc", "rtf"].includes(ext) ? "document"
        : info.size > 2e6 ? "other"
        : info.mime.startsWith("text/") || ["json", "xml", "yaml", "yml", "toml", "ini", "conf", "sh", "py", "js", "qml", "rs", "c", "h", "cpp", "lua", "md", "csv", "log"].includes(ext) ? "text"
        : info.mime.startsWith("image/") ? "image"
        : "other"

    IpcHandler {
        target: "quicklook"
        function open(file: string): void { root.show(file) }
        function close(): void { root.close() }
    }

    function show(p) {
        path = p.replace(/^file:\/\//, "");
        info.read();
    }
    function close() { path = ""; pages = []; text = ""; folder = []; rows = []; }
    function open() { Config.launch(["xdg-open", path]); close(); }

    QtObject {
        id: info
        property bool dir: false
        property string mime: ""
        property real size: 0
        property real modified: 0
        function read() { statProc.running = false; statProc.running = true; }
    }
    Process {
        id: statProc
        command: ["sh", "-c", 'stat -L -c "%F|%s|%Y" "$1" && file -Lb --mime-type "$1"', "sh", root.path]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const f = (lines[0] ?? "").split("|");
                info.dir = f[0] === "directory";
                info.size = parseFloat(f[1]) || 0;
                info.modified = parseFloat(f[2]) || 0;
                info.mime = lines[1] ?? "";
                root.load();
            }
        }
    }
    function load() {
        pages = []; text = ""; folder = []; frame = ""; rows = [];
        if (kind === "pdf" || kind === "video") render.running = true;
        else if (kind === "document") docText.running = true;
        else if (kind === "sheet") sheet.running = true;
        else if (kind === "text") textFile.reload();
        else if (kind === "folder") listing.running = true;
        siblings.running = true;
    }

    property var pages: []
    property string frame: ""
    readonly property string tmp: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vyntaris-quicklook"
    Process {
        id: render
        command: root.kind === "pdf"
            ? ["sh", "-c", 'rm -rf "$2" && mkdir -p "$2" && pdftoppm -l 12 -r 90 -png "$1" "$2/p" && ls "$2"/p*.png', "sh", root.path, root.tmp]
            : ["sh", "-c", 'rm -rf "$2" && mkdir -p "$2" && ffmpegthumbnailer -i "$1" -o "$2/frame.png" -s 1280 -q 8 && echo "$2/frame.png"', "sh", root.path, root.tmp]
        stdout: StdioCollector {
            onStreamFinished: {
                const files = text.trim().split("\n").filter(l => l);
                if (root.kind === "pdf") root.pages = files.map(f => "file://" + f);
                else root.frame = files.length ? "file://" + files[0] + "?" + Date.now() : "";
            }
        }
    }

    property string text: ""
    Process {
        id: docText
        command: ["/usr/lib/vyntaris/doc-index", "text", root.path]
        stdout: StdioCollector { onStreamFinished: root.text = text.replace(/[ \t]*\n[ \t]*\n+/g, "\n\n").trim().slice(0, 60000) }
    }
    property var rows: []
    readonly property int columns: rows.reduce((n, r) => Math.max(n, r.length), 0)
    Process {
        id: sheet
        command: ["/usr/lib/vyntaris/doc-index", "table", root.path]
        stdout: StdioCollector { onStreamFinished: root.rows = text.split("\n").filter(l => l !== "").map(l => l.split("\t")) }
    }
    FileView {
        id: textFile
        path: root.kind === "text" ? root.path : ""
        printErrors: false
        onLoaded: root.text = text().slice(0, 120000)
    }

    property var folder: []
    Process {
        id: listing
        command: ["sh", "-c", 'ls -A --group-directories-first -p "$1" | head -n 200', "sh", root.path]
        stdout: StdioCollector { onStreamFinished: root.folder = text.split("\n").filter(l => l) }
    }

    property var others: []
    Process {
        id: siblings
        command: ["sh", "-c", 'cd "$(dirname "$1")" && ls -A | grep -v "^\\." ', "sh", root.path]
        stdout: StdioCollector { onStreamFinished: root.others = text.split("\n").filter(l => l) }
    }
    function step(delta) {
        const i = others.indexOf(name);
        if (i < 0 || others.length < 2) return;
        const dir = path.slice(0, path.length - name.length);
        show(dir + others[(i + delta + others.length) % others.length]);
    }

    function size(b) {
        return b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : b >= 1e6 ? (b / 1e6).toFixed(1) + " MB"
             : b >= 1e3 ? Math.round(b / 1e3) + Tr.t(" kB") : b + Tr.t(" B");
    }

    PanelWindow {
        id: win
        visible: root.shown
        screen: Quickshell.screens.find(s => s.name === Monitors.focused?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell-quicklook"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onVisibleChanged: if (visible) card.forceActiveFocus()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.72, 1300)
            height: Math.min(parent.height * 0.82, 1000)
            radius: Theme.r(24)
            color: Theme.base
            border { width: 1; color: Theme.rimOn(parent) }
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Space) root.close();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.open();
                else if (event.key === Qt.Key_Right) root.step(1);
                else if (event.key === Qt.Key_Left) root.step(-1);
                else return;
                event.accepted = true;
            }
            MouseArea { anchors.fill: parent }

            RowLayout {
                id: head
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.space20 }
                spacing: Theme.space12
                Image {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 28
                    sourceSize: Qt.size(56, 56)
                    source: Quickshell.iconPath(info.dir ? "folder" : (info.mime.replace("/", "-") || "text-x-generic"), true)
                            || Quickshell.iconPath("text-x-generic", true)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space2
                    Label { Layout.fillWidth: true; elide: Text.ElideMiddle; font.weight: Font.DemiBold; font.pixelSize: Theme.fontSizeLarge; text: root.name }
                    Caption {
                        text: (info.dir ? Tr.f("{0} items", root.folder.length) : root.size(info.size))
                            + (info.modified ? " · " + Qt.formatDateTime(new Date(info.modified * 1000), "d MMM yyyy, hh:mm") : "")
                            + (info.mime ? " · " + info.mime : "")
                    }
                }
                Button { icon: "external"; text: Tr.t("Open"); primary: true; onClicked: root.open() }
                IconButton { icon: "close"; label: Tr.t("Close"); onClicked: root.close() }
            }

            Item {
                id: body
                anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; margins: Theme.space20; topMargin: Theme.space14 }
                clip: true

                Image {
                    anchors.fill: parent
                    visible: root.kind === "image"
                    source: visible ? "file://" + root.path : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(body.width * 1.5, body.height * 1.5)
                }
                AnimatedImage {
                    anchors.fill: parent
                    visible: root.kind === "animation"
                    source: visible ? "file://" + root.path : ""
                    fillMode: Image.PreserveAspectFit
                }

                ListView {
                    anchors.fill: parent
                    visible: root.kind === "pdf"
                    model: root.pages
                    spacing: Theme.space12
                    clip: true
                    delegate: Image {
                        required property string modelData
                        width: ListView.view.width
                        source: modelData
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }

                Loader {
                    id: media
                    anchors.fill: parent
                    active: root.shown && (root.kind === "video" || root.kind === "audio")
                    source: active ? "MediaPreview.qml" : ""
                    onLoaded: item.path = Qt.binding(() => root.path)
                }
                Image {
                    anchors.fill: parent
                    visible: root.kind === "video" && media.status === Loader.Error
                    source: visible ? root.frame : ""
                    fillMode: Image.PreserveAspectFit
                }

                Flickable {
                    anchors.fill: parent
                    visible: root.kind === "text" || root.kind === "document"
                    contentHeight: textView.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    TextEdit {
                        id: textView
                        width: parent.width
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        color: Theme.text
                        selectionColor: Theme.accent
                        font.family: root.kind === "text" ? Theme.monoFamily : Theme.fontFamily
                        font.pixelSize: root.kind === "text" ? Theme.fontSize : Theme.fontSizeMedium
                        text: root.text
                    }
                }

                Flickable {
                    anchors.fill: parent
                    visible: root.kind === "sheet"
                    contentWidth: grid.width
                    contentHeight: grid.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: grid
                        readonly property int cell: 120
                        Row {
                            Rectangle { width: 40; height: 26; color: Theme.tint(parent, Theme.text, 0.06) }
                            Repeater {
                                model: root.columns
                                Rectangle {
                                    required property int index
                                    width: grid.cell; height: 26
                                    color: Theme.tint(parent, Theme.text, 0.06)
                                    border { width: 1; color: Theme.hairlineOn(parent) }
                                    Label { anchors.centerIn: parent; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall; text: String.fromCharCode(65 + index % 26) + (index >= 26 ? Math.floor(index / 26) : "") }
                                }
                            }
                        }
                        Repeater {
                            model: root.rows
                            Row {
                                id: sheetRow
                                required property var modelData
                                required property int index
                                Rectangle {
                                    width: 40; height: 26
                                    color: Theme.tint(parent, Theme.text, 0.06)
                                    border { width: 1; color: Theme.hairlineOn(parent) }
                                    Label { anchors.centerIn: parent; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall; text: sheetRow.index + 1 }
                                }
                                Repeater {
                                    model: root.columns
                                    Rectangle {
                                        required property int index
                                        readonly property string value: sheetRow.modelData[index] ?? ""
                                        width: grid.cell; height: 26
                                        color: "transparent"
                                        border { width: 1; color: Theme.hairlineOn(parent) }
                                        Label {
                                            anchors { fill: parent; leftMargin: Theme.space6; rightMargin: Theme.space6 }
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: /^-?[\d.,]+%?$/.test(parent.value) ? Text.AlignRight : Text.AlignLeft
                                            elide: Text.ElideRight
                                            textFormat: Text.PlainText
                                            font.pixelSize: Theme.fontSizeLabel
                                            text: parent.value
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ListView {
                    anchors.fill: parent
                    visible: root.kind === "folder"
                    model: root.folder
                    clip: true
                    delegate: RowLayout {
                        required property string modelData
                        width: ListView.view.width
                        height: 30
                        spacing: Theme.space10
                        Icon { name: modelData.endsWith("/") ? "folder" : "copy"; size: 14; color: Theme.overlay1 }
                        Label { Layout.fillWidth: true; elide: Text.ElideRight; text: modelData.replace(/\/$/, "") }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.kind === "other" || (root.kind === "document" && root.text === "" && !docText.running)
                        || (root.kind === "sheet" && root.rows.length === 0 && !sheet.running)
                        || (root.kind === "pdf" && root.pages.length === 0 && !render.running)
                    spacing: Theme.space10
                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 96; Layout.preferredHeight: 96
                        sourceSize: Qt.size(192, 192)
                        source: Quickshell.iconPath(info.mime.replace("/", "-") || "text-x-generic", true) || Quickshell.iconPath("text-x-generic", true)
                    }
                    Label { Layout.alignment: Qt.AlignHCenter; color: Theme.subtext0; text: Tr.t("No preview · Enter opens it") }
                }
                Column {
                    anchors.centerIn: parent
                    visible: render.running || docText.running || sheet.running
                    spacing: Theme.space10
                    Spinner { anchors.horizontalCenter: parent.horizontalCenter; size: 28 }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.overlay1
                        text: Tr.t("Loading…")
                    }
                }
            }
        }
    }
}
