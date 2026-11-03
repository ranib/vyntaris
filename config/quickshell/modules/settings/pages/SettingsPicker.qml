import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A setting chosen from a list rather than typed: a search over `results` ({ value, title, caption }) in a dropdown
// from `anchor`, its button, while `shown`. Picking several (`currents`) toggles each and leaves it open.
Dropdown {
    id: picker
    property string placeholder: Tr.t("Search…")
    property string current
    property var currents: []
    property var results: []
    property string empty: ""
    property int maxRows: 6
    readonly property alias query: search.text
    signal picked(string value)

    onOpened: { search.text = ""; search.input.forceActiveFocus(); list.showChosen(); }

    SearchField {
        id: search
        Layout.fillWidth: true
        placeholder: picker.placeholder
        input.Keys.onEscapePressed: picker.close()
        onAccepted: if (picker.results.length) picker.picked(picker.results[0].value)
    }
    PickList {
        id: list
        current: picker.current
        chosenValues: picker.currents
        maxRows: picker.maxRows
        model: picker.results
        onPicked: v => picker.picked(v)
    }
    Label {
        visible: picker.results.length === 0 && picker.empty !== ""
        leftPadding: 14
        color: Theme.overlay1
        text: picker.empty
    }
}
