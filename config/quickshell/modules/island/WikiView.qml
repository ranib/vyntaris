import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    readonly property real fullWidth: 640
    readonly property real hang: content.implicitHeight + 26
    readonly property bool active: Panels.wikiOpen

    property int current: 0

    readonly property bool asking: ArchWiki.query.trim() !== ""
    readonly property var rows: asking ? ArchWiki.results.slice(0, 7)
        : ArchWiki.recent.concat(ArchWiki.starters).filter((p, i, all) => all.findIndex(o => o.path === p.path && (o.anchor ?? "") === (p.anchor ?? "")) === i).slice(0, 7)

    width: fullWidth
    height: Theme.barHeight + hang

    onActiveChanged: if (active) {
        current = 0;
        search.text = Panels.wikiQuery;
        ArchWiki.setQuery(Panels.wikiQuery);
        focusLater.restart();
    }
    Component.onCompleted: if (active) activeChanged()
    Timer { id: focusLater; interval: 30; onTriggered: search.forceActiveFocus() }
    Connections {
        target: Panels
        function onWikiQueryChanged() { if (root.active) search.text = Panels.wikiQuery; }
    }
    onRowsChanged: current = Math.min(current, Math.max(0, rows.length - 1))

    function start(page) {
        if (!page) return;
        ArchWiki.open(page);
        Panels.wikiOpen = false;
    }

    PanelHeader {
        icon: "info"
        title: Tr.t("Arch Wiki")
    }

    PanelBody {
        id: content
        spacing: Theme.space10

        ColumnLayout {
            Layout.fillWidth: true
            visible: ArchWiki.checked && !ArchWiki.installed
            spacing: Theme.space10
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.overlay1
                text: Tr.t("The Arch Wiki isn't on this computer yet. It takes about 240 MB and then works without internet.")
            }
            Button {
                Layout.alignment: Qt.AlignRight
                primary: true
                icon: ArchWiki.installing ? "" : "download"
                active: !ArchWiki.installing
                text: ArchWiki.installing ? Tr.t("Installing…") : Tr.t("Install")
                onClicked: ArchWiki.install()
            }
        }

        PanelSurface {
            id: field
            Layout.fillWidth: true
            visible: ArchWiki.installed
            implicitHeight: Theme.controlHeight
            radius: Theme.r(height / 2)
            fill: Theme.tint(parent, Theme.crust, 0.45)
            edgeWidth: 1; edge: Theme.rimOn(parent)

            Rectangle {
                id: disc
                anchors { left: parent.left; leftMargin: Theme.space6; verticalCenter: parent.verticalCenter }
                width: parent.height - 10
                height: width
                radius: width / 2
                color: Theme.accent
                Icon { anchors.centerIn: parent; name: "search"; size: 16; color: Theme.textOnAccent }
            }
            Rectangle {
                id: count
                anchors { right: parent.right; rightMargin: Theme.space6; verticalCenter: parent.verticalCenter }
                visible: root.asking
                width: Math.max(disc.width, countText.implicitWidth + 16)
                height: disc.height
                radius: Theme.r(height / 2)
                color: Theme.accent
                Label {
                    id: countText
                    anchors.centerIn: parent
                    mono: true
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.textOnAccent
                    text: ArchWiki.results.length
                }
            }
            TextInput {
                id: search
                anchors { left: disc.right; leftMargin: Theme.space12; right: count.visible ? count.left : parent.right; rightMargin: Theme.space12; verticalCenter: parent.verticalCenter }
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.textOnAccent
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeLarge }
                clip: true
                onTextChanged: { root.current = 0; ArchWiki.setQuery(text); }
                Keys.onEscapePressed: Panels.wikiOpen = false
                Keys.onDownPressed: root.current = Math.min(root.current + 1, root.rows.length - 1)
                Keys.onUpPressed: root.current = Math.max(root.current - 1, 0)
                Keys.onReturnPressed: root.start(root.rows[root.current])
                Keys.onEnterPressed: root.start(root.rows[root.current])

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text
                    color: Theme.overlay0
                    font: search.font
                    text: Tr.t("Search the Arch Wiki…")
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: ArchWiki.installed && root.asking && ArchWiki.corrected !== ""
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.overlay1
            text: Tr.f("Showing results for \u201c{0}\u201d", ArchWiki.corrected)
        }

        Caption {
            visible: ArchWiki.installed && !root.asking && root.rows.length > 0
            text: ArchWiki.recent.length > 0 ? Tr.t("Recent") : Tr.t("Start here")
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: ArchWiki.installed
            spacing: Theme.space2

            Repeater {
                model: root.rows
                PanelSurface {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === root.current
                    Layout.fillWidth: true
                    implicitHeight: row.modelData.snippet ? 50 : 40
                    radius: Theme.r(12)
                    fill: chosen ? Theme.accent : area.containsMouse ? Theme.hoverOn(parent) : "transparent"
                    Behavior on fill { ColorAnim {} }
                    RowLayout {
                        anchors { fill: parent; leftMargin: Theme.space14; rightMargin: Theme.space14 }
                        spacing: Theme.space12
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space2
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.space6
                                Label {
                                    Layout.fillWidth: !row.modelData.section
                                    Layout.maximumWidth: row.modelData.section ? 260 : -1
                                    elide: Text.ElideRight
                                    font.weight: row.chosen ? Font.DemiBold : Font.Normal
                                    color: row.chosen ? Theme.textOnAccent : Theme.text
                                    text: row.modelData.title
                                }
                                Icon {
                                    visible: !!row.modelData.section
                                    name: "chevron-right"
                                    size: 12
                                    color: row.chosen ? Theme.textOnAccent : Theme.overlay1
                                }
                                Label {
                                    Layout.fillWidth: true
                                    visible: !!row.modelData.section
                                    elide: Text.ElideRight
                                    color: row.chosen ? Theme.textOnAccent : Theme.subtext0
                                    text: row.modelData.section ?? ""
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: !!row.modelData.snippet
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                                font.pixelSize: Theme.fontSizeSmall
                                color: row.chosen ? Theme.textOnAccent : Theme.overlay1
                                text: ArchWiki.marked(row.modelData.snippet, row.chosen ? Theme.textOnAccent : Theme.accent)
                            }
                        }
                        Icon { name: "external"; size: 14; color: row.chosen ? Theme.textOnAccent : Theme.overlay1 }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.start(row.modelData)
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space4
                Layout.bottomMargin: Theme.space4
                visible: root.asking && root.rows.length === 0
                horizontalAlignment: Text.AlignHCenter
                color: Theme.overlay1
                text: ArchWiki.indexing || ArchWiki.searching || ArchWiki.loading ? Tr.t("Searching…") : Tr.t("No pages found")
            }
        }
    }
}
