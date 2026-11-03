import QtQuick
import QtQuick.Layouts
import qs.config

ListView {
    id: root
    property string current
    // Picking several: each of these is marked as chosen too.
    property var chosenValues: []
    property int maxRows: 6
    readonly property real rowHeight: 42
    signal picked(string value)

    // Opened on the one chosen, wherever it is in the list.
    function showChosen() {
        const i = (model ?? []).findIndex ? model.findIndex(r => r.value === current) : -1;
        if (i >= 0) positionViewAtIndex(i, ListView.Center); else positionViewAtBeginning();
    }
    Layout.fillWidth: true
    implicitHeight: Math.min(count, maxRows) * rowHeight
    clip: true
    interactive: count > maxRows
    boundsBehavior: Flickable.StopAtBounds

    delegate: PanelSurface {
        id: row
        required property var modelData
        readonly property bool chosen: modelData.value === root.current || root.chosenValues.indexOf(modelData.value) >= 0
        required property int index
        width: root.width
        height: root.rowHeight
        radius: Theme.r(12)
        fill: chosen ? Theme.accent : area.containsMouse ? Theme.hoverOn(parent) : "transparent"
        Behavior on fill { ColorAnim {} }

        RowLayout {
            anchors { fill: parent; leftMargin: Theme.space14; rightMargin: Theme.space14 }
            spacing: Theme.space12
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.weight: row.chosen ? Font.DemiBold : Font.Normal
                color: row.chosen ? Theme.textOnAccent : Theme.text
                text: row.modelData.title
            }
            Label {
                visible: text !== ""
                font.pixelSize: Theme.fontSizeLabel
                color: row.chosen ? Theme.tint(parent, Theme.textOnAccent, 0.75) : Theme.overlay1
                text: row.modelData.caption ?? ""
            }
            Icon { visible: row.chosen; name: "check"; size: 16; color: Theme.textOnAccent }
        }
        PressArea {
            id: area
            anchors.fill: parent
            label: row.modelData.title
            role: Accessible.RadioButton
            checked: row.chosen
            onActiveFocusChanged: if (activeFocus) root.positionViewAtIndex(row.index, ListView.Contain)
            onClicked: root.picked(row.modelData.value)
        }
    }
}
