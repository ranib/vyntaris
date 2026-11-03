import QtQuick
import qs.config

PanelSurface {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property bool mono: false
    property bool secret: false
    property bool canReveal: false
    property bool invalid: false
    property bool revealed: false
    property string label: {
        for (let p = parent; p; p = p.parent)
            if (p.isOption === true) return p.title;
        return placeholder;
    }
    readonly property alias input: input
    signal committed(string text)

    implicitWidth: 220
    implicitHeight: Theme.controlHeight
    radius: Theme.r(height / 2)
    fill: Theme.tint(parent, Theme.text, input.activeFocus ? 0.09 : 0.05)
    edgeWidth: input.activeFocus ? 2 : 1
    edge: invalid ? Theme.error : input.activeFocus ? Theme.accentInk : Theme.controlEdge
    Behavior on fill { ColorAnim {} }
    Behavior on edge { ColorAnim {} }

    TextInput {
        id: input
        anchors { fill: parent; leftMargin: Theme.space16; rightMargin: root.canReveal ? 44 : 16 }
        activeFocusOnTab: true
        Accessible.role: Accessible.EditableText
        Accessible.name: root.label
        Accessible.passwordEdit: root.secret
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.textOnAccent
        font.family: root.mono ? Theme.monoFamily : Theme.fontFamily
        font.pixelSize: Theme.fontSize
        clip: true
        echoMode: root.secret && !root.revealed ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        onEditingFinished: root.committed(text)

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: !input.text
            color: Theme.overlay1
            text: root.placeholder
        }
    }

    IconButton {
        visible: root.canReveal
        anchors { right: parent.right; rightMargin: Theme.space6; verticalCenter: parent.verticalCenter }
        size: 30
        icon: root.revealed ? "eye-off" : "eye"
        label: root.revealed ? Tr.t("Hide password") : Tr.t("Show password")
        on: root.revealed
        onClicked: { root.revealed = !root.revealed; input.forceActiveFocus(); }
    }
}
