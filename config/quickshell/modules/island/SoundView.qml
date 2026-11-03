import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import "../../components/Icons.js" as Icons

Item {
    id: root
    readonly property real fullWidth: 460
    readonly property real hang: content.implicitHeight + 26
    readonly property bool active: Panels.soundOpen
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [ root.sink, root.source ] }

    width: fullWidth
    height: Theme.barHeight + hang

    Component.onCompleted: AudioDevices.watching = active
    onActiveChanged: AudioDevices.watching = active

    PanelHeader { icon: "volume"; title: Tr.t("Sound") }

    component Section: ColumnLayout {
        id: section
        property string title
        property bool isInput: false
        property var audio: null
        property var devices: []
        Layout.fillWidth: true
        spacing: Theme.space8

        Caption { text: section.title }

        SegmentSlider {
            Layout.fillWidth: true
            icon: section.isInput ? (section.audio?.muted ? "mic-off" : "mic") : (section.audio?.muted ? "volume-x" : "volume")
            iconLevel: section.isInput ? -1 : Icons.volumeLevel(section.audio?.volume ?? 0)
            label: section.isInput ? Tr.t("Microphone") : Tr.t("Volume")
            iconLabel: Tr.t("Mute")
            value: section.audio?.volume ?? 0
            maximum: section.isInput ? 1 : Config.maxVolume
            dimmed: section.audio?.muted ?? false
            valueText: section.audio?.muted ? "--" : Math.round(level * 100)
            onMoved: v => { if (section.audio) section.audio.volume = v; }
            onIconClicked: if (section.audio) section.audio.muted = !section.audio.muted
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            Caption {
                visible: section.devices.length === 0
                text: Tr.t("None")
            }

            Repeater {
                model: section.devices
                PanelSurface {
                    id: row
                    required property var modelData
                    readonly property bool chosen: modelData.current
                    readonly property bool can: modelData.available
                    readonly property bool twin: section.devices.filter(d => d.label === modelData.label).length > 1
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Theme.r(12)
                    fill: area.containsMouse && can && !chosen ? Theme.hover : "transparent"
                    opacity: can ? 1 : Theme.disabledOpacity
                    Behavior on fill { ColorAnim {} }
                    RowLayout {
                        // The icon lines up with the slider's above.
                        anchors { fill: parent; leftMargin: Theme.space2; rightMargin: Theme.space10 }
                        spacing: Theme.space12
                        Icon { name: row.modelData.icon; size: 16; filled: row.chosen; color: row.chosen ? Theme.accentInk : Theme.overlay1 }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.weight: row.chosen ? Font.DemiBold : Font.Normal
                            color: row.chosen ? Theme.accentInk : Theme.text
                            text: row.twin && row.modelData.sub ? `${row.modelData.label} · ${row.modelData.sub}` : row.modelData.label
                        }
                        Caption {
                            visible: !row.can
                            text: row.modelData.takenOver ? Tr.t("Off") : Tr.t("Not connected")
                        }
                        Icon { visible: row.chosen; name: "check"; size: 15; color: Theme.accentInk }
                    }
                    PressArea {
                        label: row.modelData.label
                        enabled: row.can
                        role: Accessible.RadioButton
                        checked: row.chosen
                        id: area
                        anchors.fill: parent
                        cursorShape: !row.chosen ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (row.can && !row.chosen) AudioDevices.pick(row.modelData, section.isInput)
                    }
                }
            }
        }
    }

    PanelBody {
        id: content
        spacing: Theme.space14

        Section {
            title: Tr.t("Output")
            audio: root.sink?.audio ?? null
            devices: AudioDevices.outputs
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }

        Section {
            title: Tr.t("Input")
            isInput: true
            audio: root.source?.audio ?? null
            devices: AudioDevices.inputs
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space8

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space8
                Caption { Layout.fillWidth: true; text: Tr.t("Noise suppression") }
                Spinner { visible: NoiseSuppression.installing; size: 14 }
            }
            Choice {
                Layout.fillWidth: true
                stretch: true
                options: NoiseSuppression.labels.map((label, i) => ({ value: i, label: label }))
                current: NoiseSuppression.level
                onPicked: v => NoiseSuppression.set(v)
            }

            Label {
                Layout.fillWidth: true
                visible: !NoiseSuppression.available
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.overlay1
                text: NoiseSuppression.installing ? Tr.t("Installing…") : Tr.t("Turning it on installs RNNoise (noise-suppression-for-voice) once.")
            }
        }
    }
}
