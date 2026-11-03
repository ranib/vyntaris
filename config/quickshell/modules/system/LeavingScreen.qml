import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    visible: Leaving.mode !== ""
    WlrLayershell.namespace: "quickshell-leaving"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property real px: 1 / (modelData.devicePixelRatio || 1)

    readonly property string splashDir: "/usr/share/plymouth/themes/island"
    FileView { id: splashInfo; path: root.splashDir + "/frames.json"; printErrors: false }
    readonly property var splash: { try { return JSON.parse(splashInfo.text()); } catch (e) { return null; } }
    function file(name) { return "file://" + splashDir + "/" + name + ".png"; }

    readonly property var pal: Theme.bootPalette
    readonly property color top: splash?.base ?? pal.base
    readonly property color bottom: splash?.crust ?? pal.crust
    readonly property color text: splash?.text ?? pal.text
    readonly property real size: (splash?.size ?? 176) * px

    Rectangle {
        id: bg
        anchors.fill: parent
        opacity: 0
        gradient: Gradient {
            GradientStop { position: 0; color: root.top }
            GradientStop { position: 1; color: root.bottom }
        }
        NumberAnimation on opacity { running: root.visible; from: 0; to: 1; duration: Theme.durationSlow; easing.type: Easing.OutCubic }
    }

    Item {
        id: scene
        anchors.fill: parent
        visible: root.splash !== null
        opacity: bg.opacity

        readonly property var s: root.splash
        readonly property real k: root.px
        readonly property real x0: (root.width - root.size) / 2
        readonly property real y0: (root.height - root.size) / 2 - 20 * k
        readonly property real unit: (s?.size ?? 176) / 24 * k
        readonly property real cx: x0 + (s?.orbit.cx ?? 0) * unit
        readonly property real cy: y0 + (s?.orbit.cy ?? 0) * unit
        readonly property real rx: (s?.orbit.rx ?? 0) * unit
        readonly property real ry: (s?.orbit.ry ?? 0) * unit
        readonly property real tilt: (s?.orbit.tilt ?? 0) * Math.PI / 180
        function orbitX(a, sc) { return cx + rx * sc * Math.cos(a) * Math.cos(tilt) - ry * sc * Math.sin(a) * Math.sin(tilt); }
        function orbitY(a, sc) { return cy + rx * sc * Math.cos(a) * Math.sin(tilt) + ry * sc * Math.sin(a) * Math.cos(tilt); }

        property int f: 0
        readonly property int turn: Math.floor(f / (s?.loop ?? 1))
        readonly property int i: f - turn * (s?.loop ?? 1)
        readonly property var planet: s ? s.planet.loop[i] : [0, 0, 0]
        property int pulseStart: 0
        FrameAnimation {
            id: clock
            running: root.visible && scene.visible
            onRunningChanged: if (running) { clock.reset(); scene.reset(); }
            onTriggered: {
                const n = Math.floor(elapsedTime * scene.s.fps);
                if (n <= scene.f) return;
                const t = Math.floor(n / scene.s.loop);
                if (t !== scene.turn && t % 2 === 1) scene.pulseStart = t * scene.s.loop;
                scene.f = n;
            }
        }

        function reset() {
            f = 0;
            pulseStart = 0;
        }

        Image {
            readonly property real d: (scene.s?.halo ?? 0) * scene.k
            x: scene.x0 + (root.size - d) / 2
            y: scene.y0 + (root.size - d) / 2
            width: d
            height: d
            source: scene.visible ? root.file("halo") : ""
            opacity: 0.75 + 0.25 * Math.sin(scene.f * 2 * Math.PI / (scene.s?.loop ?? 1))
        }

        Repeater {
            model: scene.visible && scene.s ? [false, true] : []
            Item {
                id: side
                required property bool modelData
                readonly property bool front: modelData
                anchors.fill: parent
                z: front ? 30 : 4
                Repeater {
                    model: scene.s?.paths ?? []
                    Item {
                        id: path
                        required property var modelData
                        required property int index
                        anchors.fill: parent
                        Repeater {
                            model: path.modelData.dots
                            Image {
                                required property int index
                                readonly property real a: scene.f * path.modelData.spin + index * 2 * Math.PI / path.modelData.dots
                                readonly property real u: (index / path.modelData.dots * path.modelData.dashes) % 1
                                visible: (Math.sin(a) > 0) === side.front
                                x: scene.orbitX(a, path.modelData.scale) - 2 * scene.k
                                y: scene.orbitY(a, path.modelData.scale) - 2 * scene.k
                                width: 4 * scene.k
                                height: width
                                source: root.file("dot-1")
                                opacity: path.modelData.alpha * Math.max(0, Math.min(1, Math.min(u, path.modelData.duty - u) * 12)) * (side.front ? 1 : 0.4)
                            }
                        }
                        Image {
                            readonly property real a: scene.f * path.modelData.spin * 3.2 + path.index * 2.2
                            visible: (Math.sin(a) > 0) === side.front
                            x: scene.orbitX(a, path.modelData.scale) - 4 * scene.k
                            y: scene.orbitY(a, path.modelData.scale) - 4 * scene.k
                            width: 8 * scene.k
                            height: width
                            source: root.file("dot-3")
                            opacity: side.front ? 0.85 : 0.45
                        }
                    }
                }
            }
        }

        Image {
            z: 10
            x: scene.x0 + (scene.s?.x ?? 0) * scene.k
            y: scene.y0 + (scene.s?.y ?? 0) * scene.k
            width: (scene.s?.width ?? 0) * scene.k
            height: (scene.s?.height ?? 0) * scene.k
            source: scene.visible ? root.file("loop-" + scene.i) : ""
            smooth: scene.k !== 1
        }

        Image {
            z: 35
            width: (scene.s?.flare[0] ?? 0) * scene.k
            height: (scene.s?.flare[1] ?? 0) * scene.k
            x: scene.x0 + scene.planet[0] * scene.k - width / 2
            y: scene.y0 + scene.planet[1] * scene.k - height / 2
            source: scene.visible ? root.file("flare") : ""
            opacity: scene.planet[2] ? 0.55 : 0.12
        }

        Repeater {
            model: scene.visible && scene.s ? scene.s.pulseDots : 0
            Image {
                required property int index
                readonly property real u: (scene.f - scene.pulseStart) / scene.s.pulseFrames
                readonly property real a: index * 2 * Math.PI / scene.s.pulseDots
                readonly property real sc: 1.05 + 2.4 * (1 - Math.pow(1 - u, 3))
                visible: u >= 0 && u <= 1
                z: 32
                x: scene.orbitX(a, sc) - 3 * scene.k
                y: scene.orbitY(a, sc) - 3 * scene.k
                width: 6 * scene.k
                height: width
                source: root.file("dot-2")
                opacity: (1 - u) * (1 - u) * 0.85 * (Math.sin(a) > 0 ? 1 : 0.6)
            }
        }
    }

    Logo {
        visible: root.splash === null
        x: (root.width - root.size) / 2
        y: (root.height - root.size) / 2 - 20 * root.px
        opacity: bg.opacity
        size: root.size
        colors: root.pal
        accentName: Config.theme.accent
        animated: root.visible
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (root.height - root.size) / 2 - 20 * root.px + root.size + 36 * root.px
        opacity: bg.opacity * 0.55
        text: (Leaving.mode === "reboot" ? Tr.t("R E S T A R T I N G") : Leaving.mode === "logout" ? Tr.t("L O G G I N G   O U T") : Tr.t("S H U T T I N G   D O W N"))
        color: root.text
        font.family: "DejaVu Sans"
        font.pixelSize: 15 * root.px
    }

    Column {
        visible: Leaving.backingUp
        anchors.horizontalCenter: parent.horizontalCenter
        y: (root.height - root.size) / 2 - 20 * root.px + root.size + 84 * root.px
        spacing: Theme.space14
        opacity: bg.opacity
        focus: Leaving.backingUp
        Keys.onEscapePressed: Leaving.skipBackup()

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
            text: CloudBackup.backingUp ? Tr.f("Backing up to Google Drive · {0} {1}%", CloudBackup.folder, Math.round(CloudBackup.progress * 100))
                : Tr.t("Backing up to Google Drive…")
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: 4
            radius: 2
            // Solid: the text colour at 15% over the middle of the screen's gradient.
            color: Qt.tint(Qt.tint(root.top, Qt.rgba(root.bottom.r, root.bottom.g, root.bottom.b, 0.5)), Qt.rgba(root.text.r, root.text.g, root.text.b, 0.15))
            Rectangle {
                width: parent.width * Math.max(0.02, CloudBackup.progress)
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t("Skip backup")
            onClicked: Leaving.skipBackup()
        }
    }
}
