import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root
    property string icon
    property string title
    property string subtitle
    property alias search: searchField
    property alias searchHint: searchField.placeholder
    property var pages: []
    property string current
    signal picked(string id)
    // While searching the list shows what was found instead of the pages: { icon, title, subtitle } each.
    property bool searching: false
    property var results: []
    property string noResults: ""
    signal resultPicked(var result)

    readonly property real needed: 24 + header.implicitHeight + 12 + 4 + searchField.implicitHeight + 8 + 4 + navColumn.implicitHeight

    Layout.fillHeight: true
    Layout.preferredWidth: Theme.navWidth
    color: Theme.mantle

    ColumnLayout {
        anchors { fill: parent; margins: Theme.navInset }
        spacing: Theme.space4

        RowLayout {
            id: header
            Layout.bottomMargin: Theme.space12
            Layout.leftMargin: Theme.space6
            spacing: Theme.space10
            Icon { name: root.icon; size: 22; color: Theme.accentInk }
            ColumnLayout {
                spacing: 0
                Label { font.weight: Font.Bold; text: root.title }
                Caption { text: root.subtitle }
            }
        }

        SearchField {
            id: searchField
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.space8
        }

        Flickable {
            id: resultScroll
            visible: root.searching
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: resultColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: resultColumn
                width: parent.width
                spacing: Theme.navItemGap
                Caption {
                    visible: root.results.length === 0
                    Layout.fillWidth: true
                    Layout.margins: Theme.space12
                    wrapMode: Text.Wrap
                    text: root.noResults
                }
                Repeater {
                    model: root.results
                    Rectangle {
                        id: hit
                        required property var modelData
                        required property int index
                        // The first is what Enter opens, so it looks picked.
                        readonly property bool first: index === 0
                        Layout.fillWidth: true
                        implicitHeight: hitText.implicitHeight + 2 * Theme.space8
                        radius: Theme.navRadius
                        color: first ? Theme.accent : hitArea.containsMouse ? Theme.surface0 : Theme.mantle
                        Behavior on color { ColorAnim {} }
                        RowLayout {
                            anchors { fill: parent; leftMargin: Theme.space12; rightMargin: Theme.space12 }
                            spacing: Theme.space10
                            Icon { name: hit.modelData.icon; size: 16; filled: hit.first; color: hit.first ? Theme.textOnAccent : Theme.overlay1 }
                            ColumnLayout {
                                id: hitText
                                Layout.fillWidth: true
                                spacing: 0
                                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.DemiBold; color: hit.first ? Theme.textOnAccent : Theme.text; text: hit.modelData.title }
                                Caption { visible: text !== ""; Layout.fillWidth: true; elide: Text.ElideRight; color: hit.first ? Theme.textOnAccent : Theme.overlay1; text: hit.modelData.subtitle }
                            }
                        }
                        PressArea {
                            id: hitArea
                            anchors.fill: parent
                            label: hit.modelData.title
                            onActiveFocusChanged: {
                                if (!activeFocus) return;
                                if (hit.y < resultScroll.contentY) resultScroll.contentY = hit.y;
                                else if (hit.y + hit.height > resultScroll.contentY + resultScroll.height) resultScroll.contentY = hit.y + hit.height - resultScroll.height;
                            }
                            onClicked: root.resultPicked(hit.modelData)
                        }
                    }
                }
            }
        }

        Flickable {
            id: navScroll
            visible: !root.searching
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: navColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: navColumn
                width: parent.width
                spacing: Theme.navItemGap
                Repeater {
                    model: root.pages
                    Rectangle {
                        id: item
                        required property var modelData
                        readonly property bool current: root.current === modelData.id
                        Layout.fillWidth: true
                        implicitHeight: Theme.navItemHeight
                        radius: Theme.navRadius
                        color: current ? Theme.accent : navArea.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnim {} }
                        RowLayout {
                            anchors { fill: parent; leftMargin: Theme.space12; rightMargin: Theme.space12 }
                            spacing: Theme.space10
                            Icon { name: item.modelData.icon; size: 16; filled: item.current; color: item.current ? Theme.textOnAccent : Theme.overlay1 }
                            Label { Layout.fillWidth: true; elide: Text.ElideRight; font.weight: item.current ? Font.DemiBold : Font.Normal; color: item.current ? Theme.textOnAccent : Theme.subtext0; text: Tr.t(item.modelData.label) }
                        }
                        PressArea {
                            id: navArea
                            anchors.fill: parent
                            label: Tr.t(item.modelData.label)
                            role: Accessible.RadioButton
                            checked: item.current
                            onActiveFocusChanged: {
                                if (!activeFocus) return;
                                if (item.y < navScroll.contentY) navScroll.contentY = item.y;
                                else if (item.y + item.height > navScroll.contentY + navScroll.height) navScroll.contentY = item.y + item.height - navScroll.height;
                            }
                            onClicked: root.picked(item.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
