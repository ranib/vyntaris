import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Scope {
    id: root

    Connections {
        target: Panels
        function onHelpOpenChanged() { if (Panels.helpOpen) root.opened(); }
    }
    Component.onCompleted: if (Panels.helpOpen) opened()
    function opened() {
        Shortcuts.refresh();
        side.search.text = "";
        focusLater.restart();
    }
    Timer { id: focusLater; interval: 60; onTriggered: side.search.input.forceActiveFocus() }

    property string page: "all"
    property string query: ""
    readonly property var pages: [{ id: "all", label: Tr.t("All shortcuts"), icon: "keyboard" }].concat(Shortcuts.groups)

    readonly property var shown: {
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w);
        if (words.length > 0)
            return Shortcuts.list.filter(b => words.every(w => (b.what + " " + b.keys.join(" ")).toLowerCase().includes(w)));
        return Shortcuts.list.filter(b => page === "all" || b.group === page);
    }
    readonly property var sections: pages.slice(1)
        .map(g => ({ id: g.id, label: g.label, items: shown.filter(b => b.group === g.id) }))
        .filter(g => g.items.length > 0)

    FloatingWindow {
        id: win
        visible: Panels.helpOpen
        title: Tr.t("Help")
        implicitWidth: 866
        implicitHeight: Math.min(Math.max(side.needed, 640), (screen?.height ?? 1080) * 0.9)
        minimumSize: Qt.size(700, 480)
        color: Theme.base

        onVisibleChanged: if (!visible) Panels.helpOpen = false

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Panels.helpOpen = false
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            SideNav {
                id: side
                icon: "keyboard"
                title: Tr.t("Shortcuts")
                subtitle: Distro.name
                searchHint: Tr.t("Search shortcuts")
                pages: root.pages
                current: root.query.trim() !== "" ? "" : root.page
                onPicked: id => { side.search.text = ""; root.page = id; flick.contentY = 0; }
                Connections {
                    target: side.search.input
                    function onTextChanged() { root.query = side.search.text; flick.contentY = 0; }
                }
                Keys.onEscapePressed: Panels.helpOpen = false
                Shortcut {
                    sequence: "Ctrl+F"
                    onActivated: side.search.input.forceActiveFocus()
                }
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: column.implicitHeight + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: column
                    x: 30
                    y: 24
                    width: parent.width - 60
                    spacing: Theme.space12

                    Label {
                        font.pixelSize: Theme.fontSizeHeading
                        font.weight: Font.Bold
                        text: root.query.trim() !== "" ? Tr.t("Search") : Tr.t(root.pages.find(p => p.id === root.page)?.label ?? "")
                    }
                    Label {
                        visible: root.shown.length === 0
                        Layout.topMargin: Theme.space10
                        color: Theme.overlay1
                        text: root.query.trim() !== "" ? Tr.f("No shortcut matches “{0}”", root.query.trim()) : Tr.t("No shortcuts here")
                    }

                    Repeater {
                        model: root.sections
                        ColumnLayout {
                            id: section
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: Theme.space12
                            Label {
                                visible: root.sections.length > 1
                                Layout.topMargin: section.index > 0 ? 10 : 0
                                overline: true
                                color: Theme.accentInk
                                text: Tr.t(section.modelData.label)
                            }
                            Repeater {
                                model: section.modelData.items
                                RowLayout {
                                    id: row
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Theme.space16
                                    Label { Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.DemiBold; text: row.modelData.what }
                                    Row {
                                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                        spacing: Theme.space6
                                        Repeater {
                                            model: row.modelData.keys
                                            Rectangle {
                                                required property string modelData
                                                width: Math.max(30, key.implicitWidth + 18)
                                                height: 30
                                                radius: Theme.r(10)
                                                color: Theme.tint(parent, Theme.text, 0.04)
                                                border { width: 1; color: Theme.rimOn(parent) }
                                                Label {
                                                    id: key
                                                    anchors.centerIn: parent
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.DemiBold
                                                    color: Theme.subtext0
                                                    text: modelData
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
