import QtQuick
import qs.config

FocusScope {
    id: root
    property bool busy: false
    property bool wrong: false
    property bool reveal: false
    property alias text: input.text
    readonly property alias input: input
    signal submitted()

    implicitHeight: 34
    readonly property int count: 20
    readonly property int lit: Math.min(count, input.text.length)

    property real runner: 0
    NumberAnimation on runner { running: root.busy; from: 0; to: root.count; duration: 700; loops: Animation.Infinite }

    Row {
        id: cells
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space4
        opacity: !root.reveal ? 1 : 0
        Behavior on opacity { Anim { duration: Theme.durationFast } }
        Repeater {
            model: root.count
            Rectangle {
                required property int index
                readonly property bool on: index < root.lit
                readonly property real run: root.busy ? Math.max(0, 1 - Math.abs(index - root.runner) / 3) : 0
                width: (root.width - (root.count - 1) * cells.spacing) / root.count
                height: on || run > 0.3 ? 16 : 10
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: root.wrong ? Theme.tint(parent, Theme.error, 0.75)
                    : root.busy ? Theme.tint(parent, Theme.accent, 0.15 + 0.85 * run)
                    : !on ? Theme.tint(parent, Theme.text, 0.16)
                    : index === root.lit - 1 ? Theme.accentBright : Theme.accent
                Behavior on height { Anim { duration: Theme.durationFast } }
                Behavior on color { ColorAnim {} }
            }
        }
    }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: Theme.space2 }
        opacity: root.reveal && !root.busy && !root.wrong ? 1 : 0
        echoMode: root.reveal ? TextInput.Normal : TextInput.Password
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.textOnAccent
        font.family: Theme.monoFamily
        font.pixelSize: Theme.fontSizeLarge
        focus: true
        Keys.onReturnPressed: root.submitted()
        Keys.onEnterPressed: root.submitted()
        Keys.onEscapePressed: event => { if (text) text = ""; else event.accepted = false; }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: input.forceActiveFocus() }
}
