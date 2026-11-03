import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Networking
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.config
import qs.components
import qs.services
import qs.modules.wifi
import "../../config/Palettes.js" as Palettes
import "../../config/Wallpapers.js" as Walls
import "../../components/BarStyles.js" as BarStyles

Scope {
    id: root

    FileView {
        id: doneState
        path: Quickshell.statePath("welcome-done")
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                Panels.welcomeOpen = true;
                doneState.setText(new Date().toISOString());
            }
        }
    }

    readonly property var steps: [
        { id: "hello",    label: Tr.t("Hello"),          icon: "vyntaris" },
        { id: "look",     label: Tr.t("Look"),           icon: "image" },
        { id: "desktop",  label: Tr.t("Desktop"),        icon: "windows" },
        { id: "keyboard", label: Tr.t("Keyboard & time"), icon: "keyboard" },
        { id: "you",      label: Tr.t("You"),            icon: "users" },
        { id: "internet", label: Tr.t("Internet"),       icon: "wifi" },
        { id: "extras",   label: Tr.t("Extras"),         icon: "sliders" },
        { id: "ready",    label: Tr.t("Ready"),          icon: "check" },
    ]
    property int step: 0

    property bool shown: false
    property bool leaving: false
    Connections {
        target: Panels
        function onWelcomeOpenChanged() {
            if (Panels.welcomeOpen) { root.step = 0; root.leaving = false; root.shown = true; TimeZone.refresh(); }
        }
    }
    function finish() {
        doneState.setText(new Date().toISOString());
        Config.save();
        leaving = true;
        leaveTimer.restart();
    }
    readonly property int leaveDuration: Theme.duration(760)
    Timer {
        id: leaveTimer
        interval: root.leaveDuration + 60
        onTriggered: {
            root.shown = false;
            root.leaving = false;
            Panels.welcomeOpen = false;
            Activities.banner("check", Tr.t("All set"), "", -1, Theme.accent, 2200);
        }
    }

    IpcHandler {
        target: "welcome"
        function open(): void { Panels.welcomeOpen = true }
        function close(): void { if (root.shown) root.finish() }
        function go(n: int): void { root.step = Math.max(0, Math.min(root.steps.length - 1, n)) }
    }

    function changed() { Config.saveSoon(); }

    property string fullName: ""
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: root.fullName = text.trim().split(" ")[0] }
    }
    readonly property string greetName: fullName || Quickshell.env("USER") || ""

    FolderListModel {
        id: userWalls
        folder: Config.wallpaper.directory ? "file://" + Config.expandHome(Config.wallpaper.directory) : ""
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.heic", "*.heif", "*.PNG", "*.JPG", "*.JPEG", "*.HEIC", "*.HEIF"]
        showDirs: false
    }
    readonly property var walls: {
        const m = userWalls, paths = [];
        for (let k = 0; k < m.count; k++) paths.push(m.get(k, "filePath"));
        return [Config.defaultWallpaper].concat(Walls.group(paths, Theme.isDark).map(e => e.path));
    }

    component Tile: Rectangle {
        id: tile
        property bool selected: false
        property string label
        signal clicked()
        default property alias content: tileBody.data
        radius: Theme.r(16)
        color: selected ? Theme.tint(parent, Theme.text, 0.06) : tileArea.containsMouse ? Theme.hoverOn(parent) : Theme.tint(parent, Theme.text, 0.04)
        border { width: selected ? 2 : 1; color: selected ? Theme.accent : Theme.rimOn(parent) }
        scale: tileArea.pressed ? 0.96 : tileArea.containsMouse ? 1.02 : 1
        Behavior on scale { Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring } }
        Behavior on color { ColorAnim {} }
        Item { id: tileBody; anchors { fill: parent; margins: Theme.space8; bottomMargin: tile.label ? 30 : 8 } }
        Label {
            visible: tile.label !== ""
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.space8 }
            font.pixelSize: Theme.fontSizeLabel
            font.weight: tile.selected ? Font.DemiBold : Font.Normal
            color: tile.selected ? Theme.text : Theme.subtext0
            text: tile.label
        }
        PressArea { label: tile.label; role: Accessible.RadioButton; checked: tile.selected; id: tileArea; anchors.fill: parent; onClicked: tile.clicked() }
    }

    component OptionRow: RowLayout {
        id: opt
        property string title
        property string icon
        default property alias control: optSlot.data
        Layout.fillWidth: true
        spacing: Theme.space14
        Rectangle {
            implicitWidth: 34; implicitHeight: 34; radius: 17
            color: Theme.accent
            Icon { anchors.centerIn: parent; name: opt.icon; size: 16; color: Theme.textOnAccent }
        }
        Label { Layout.fillWidth: true; font.weight: Font.DemiBold; text: opt.title }
        Item {
            id: optSlot
            implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
            implicitHeight: Math.max(34, children.length > 0 ? children[0].implicitHeight : 0)
        }
    }

    component Page: SlidePage {
        default property alias body: pageBody.data
        current: root.step
        slide: 70
        ColumnLayout {
            id: pageBody
            anchors.fill: parent
            spacing: Theme.space16
        }
    }

    component Heading: ColumnLayout {
        property string title
        property string sub
        Layout.fillWidth: true
        spacing: Theme.space4
        Label { font.pixelSize: Theme.fontSizeDisplay; font.weight: Font.Bold; text: parent.title }
        Label { visible: parent.sub !== ""; color: Theme.subtext0; text: parent.sub }
    }

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win
            visible: root.shown
            screen: Quickshell.screens.find(s => s.name === Monitors.focused?.name) ?? Quickshell.screens[0]
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-welcome"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            property bool opened: false
            Component.onCompleted: Qt.callLater(() => win.opened = Qt.binding(() => root.shown))

            property real reveal: win.opened && !root.leaving ? 1 : 0
            Behavior on reveal {
                Anim {
                    duration: root.leaving ? root.leaveDuration : Theme.durationSlow * 2
                    easing.bezierCurve: root.leaving ? Theme.curveStandard : Theme.curveDecelerate
                }
            }

            Item {
                anchors.fill: parent
                opacity: win.reveal

                BlurredWallpaper {
                    anchors.fill: parent
                    source: "file://" + Config.wallpaperFile()
                    blur: win.reveal
                    blurMultiplier: 0.7
                    veil: Theme.isDark ? Theme.alpha(Theme.crust, 0.45) : Theme.wallpaperVeil
                }
            }

            Item {
                id: stage
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: if (root.step > 0) root.step--
                Keys.onReturnPressed: if (root.step < root.steps.length - 1) root.step++; else root.finish()
                Keys.onRightPressed: if (root.step < root.steps.length - 1) root.step++
                Keys.onLeftPressed: if (root.step > 0) root.step--

                Surface {
                    id: card
                    anchors.centerIn: parent
                    width: Math.min(1000, parent.width - 80)
                    height: Math.min(660, parent.height - 80)
                    radius: Theme.r(24)
                    clip: true

                    readonly property real islandY: -(parent.height / 2 - Theme.barHeight / 2)
                    opacity: win.opened && !root.leaving ? 1 : 0
                    scale: root.leaving ? 0.06 : win.opened ? 1 : 0.9
                    transform: Translate {
                        y: root.leaving ? card.islandY : win.opened ? 0 : 40
                        Behavior on y {
                            Anim {
                                duration: root.leaving ? root.leaveDuration : Theme.durationSlow * 1.6
                                easing.bezierCurve: root.leaving ? [0.5, 0, 0.2, 1, 1, 1] : Theme.curveSpring
                            }
                        }
                    }
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: root.leaving ? root.leaveDuration * 0.55 : Theme.duration(180) }
                            Anim { duration: root.leaving ? root.leaveDuration * 0.45 : Theme.durationSlow }
                        }
                    }
                    Behavior on scale {
                        Anim {
                            duration: root.leaving ? root.leaveDuration : Theme.durationSlow * 1.6
                            easing.bezierCurve: root.leaving ? [0.6, 0, 0.3, 1, 1, 1] : Theme.curveSpring
                        }
                    }
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.alpha("#000000", 0.5); shadowBlur: 1.0; shadowVerticalOffset: 10 }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            id: rail
                            Layout.fillHeight: true
                            Layout.preferredWidth: Theme.navItemWidth + 2 * Theme.space24
                            radius: card.radius
                            color: Theme.tint(parent, Theme.crust, 0.35)
                            Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: rail.radius; color: rail.color }

                            ColumnLayout {
                                anchors { fill: parent; margins: Theme.space24 }
                                spacing: Theme.space4

                                Icon { name: Distro.glyph; size: 30; color: Theme.accentInk }
                                Label { Layout.topMargin: Theme.space10; font.pixelSize: Theme.fontSizeTitle; font.weight: Font.Bold; text: Tr.t("Setup") }
                                Caption { Layout.bottomMargin: Theme.space24; text: Distro.name }

                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: root.steps.length * (Theme.navItemHeight + Theme.navItemGap)

                                    Rectangle {
                                        width: parent.width
                                        height: Theme.navItemHeight
                                        radius: Theme.navRadius
                                        y: root.step * (Theme.navItemHeight + Theme.navItemGap)
                                        color: Theme.accent
                                        Behavior on y { Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring } }
                                    }
                                    Column {
                                        width: parent.width
                                        spacing: Theme.navItemGap
                                        Repeater {
                                            model: root.steps
                                            Item {
                                                id: stepItem
                                                required property var modelData
                                                required property int index
                                                readonly property bool current: root.step === index
                                                readonly property bool done: index < root.step
                                                width: parent.width
                                                height: Theme.navItemHeight
                                                RowLayout {
                                                    anchors { fill: parent; leftMargin: Theme.space12; rightMargin: Theme.space12 }
                                                    spacing: Theme.space12
                                                    Rectangle {
                                                        implicitWidth: 22; implicitHeight: 22; radius: 11
                                                        color: stepItem.done ? Theme.accent : "transparent"
                                                        border { width: 1.5; color: stepItem.current ? Theme.textOnAccent : stepItem.done ? Theme.accent : Theme.overlay0 }
                                                        Behavior on color { ColorAnim {} }
                                                        Icon { anchors.centerIn: parent; visible: stepItem.done; name: "check"; size: 12; stroke: 2.4; color: Theme.textOnAccent }
                                                        Label { anchors.centerIn: parent; visible: !stepItem.done; mono: true; font.pixelSize: Theme.fontSizeSmall; color: stepItem.current ? Theme.textOnAccent : stepItem.current ? Theme.accentInk : Theme.overlay1; text: stepItem.index + 1 }
                                                    }
                                                    Label {
                                                        Layout.fillWidth: true
                                                        color: stepItem.current ? Theme.textOnAccent : stepItem.done ? Theme.subtext0 : Theme.overlay1
                                                        font.weight: stepItem.current ? Font.DemiBold : Font.Normal
                                                        text: stepItem.modelData.label
                                                    }
                                                }
                                                PressArea { label: stepItem.modelData.label; anchors.fill: parent; onClicked: root.step = stepItem.index }
                                            }
                                        }
                                    }
                                }
                                Item { Layout.fillHeight: true }
                                KeyHints { keys: [["← →", Tr.t("step")], ["↵", Tr.t("next")]] }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: Theme.space36
                            spacing: Theme.space20

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Page {
                                    index: 0
                                    Item { Layout.fillHeight: true }
                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitWidth: 150; implicitHeight: 150

                                        Repeater {
                                            model: 2
                                            Rectangle {
                                                required property int index
                                                anchors.centerIn: parent
                                                width: 110; height: 110; radius: 55
                                                color: "transparent"
                                                border { width: 2; color: Theme.accent }
                                                opacity: 0
                                                SequentialAnimation on scale {
                                                    running: win.opened && root.step === 0 && Theme.speed > 0
                                                    loops: Animation.Infinite
                                                    PauseAnimation { duration: index * 1200 }
                                                    NumberAnimation { from: 0.95; to: 1.7; duration: 2400; easing.type: Easing.OutCubic }
                                                }
                                                SequentialAnimation on opacity {
                                                    running: win.opened && root.step === 0 && Theme.speed > 0
                                                    loops: Animation.Infinite
                                                    PauseAnimation { duration: index * 1200 }
                                                    NumberAnimation { from: 0.5; to: 0; duration: 2400; easing.type: Easing.OutCubic }
                                                }
                                            }
                                        }
                                        Logo {
                                            id: logo
                                            anchors.centerIn: parent
                                            size: 84
                                            animated: win.opened && Theme.speed > 0
                                            scale: win.opened && !root.leaving ? 1 : 0.3
                                            rotation: win.opened && !root.leaving ? 0 : -120
                                            Behavior on scale { SequentialAnimation { PauseAnimation { duration: Theme.duration(320) } Anim { duration: Theme.durationSlow * 2; easing.bezierCurve: Theme.curveSpring } } }
                                            Behavior on rotation { SequentialAnimation { PauseAnimation { duration: Theme.duration(320) } Anim { duration: Theme.durationSlow * 2; easing.bezierCurve: Theme.curveSpring } } }
                                        }
                                    }
                                    Repeater {
                                        model: [
                                            { text: Tr.t("Welcome") + (root.greetName ? ", " + root.greetName : ""), size: Theme.fontSizeHero, bold: true, color: Theme.text },
                                            { text: Tr.f("Let's make {0} yours.", Distro.name), size: Theme.fontSizeLarge, bold: false, color: Theme.subtext0 },
                                        ]
                                        Label {
                                            required property var modelData
                                            required property int index
                                            Layout.alignment: Qt.AlignHCenter
                                            font.pixelSize: modelData.size
                                            font.weight: modelData.bold ? Font.Bold : Font.Normal
                                            color: modelData.color
                                            text: modelData.text
                                            readonly property bool on: win.opened && !root.leaving
                                            opacity: on ? 1 : 0
                                            transform: Translate { y: on ? 0 : 18; Behavior on y { SequentialAnimation { PauseAnimation { duration: Theme.duration(700 + index * 160) } Anim { duration: Theme.durationSlow; easing.bezierCurve: Theme.curveDecelerate } } } }
                                            Behavior on opacity { SequentialAnimation { PauseAnimation { duration: Theme.duration(700 + index * 160) } Anim { duration: Theme.durationSlow } } }
                                        }
                                    }
                                    Item { Layout.fillHeight: true }
                                }

                                Page {
                                    index: 1
                                    Heading { title: Tr.t("Look") }
                                    Caption { text: Tr.t("Mode") }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.space12
                                        Repeater {
                                            model: [{ value: "mocha", label: Tr.t("Dark") }, { value: "latte", label: Tr.t("Light") }]
                                            Tile {
                                                id: modeTile
                                                required property var modelData
                                                readonly property var pal: Palettes.palettes[modelData.value]
                                                Layout.fillWidth: true
                                                implicitHeight: 112
                                                label: modelData.label
                                                selected: Config.theme.flavor === modelData.value
                                                onClicked: { Config.theme.flavor = modelData.value; root.changed(); }
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 10
                                                    color: modeTile.pal.base
                                                    Rectangle { x: 0; y: 0; width: parent.width; height: 10; radius: 10; color: modeTile.pal.crust }
                                                    Rectangle { x: 10; y: 20; width: parent.width * 0.5; height: 6; radius: 3; color: modeTile.pal.text; opacity: 0.8 }
                                                    Rectangle { x: 10; y: 32; width: parent.width * 0.35; height: 6; radius: 3; color: modeTile.pal.overlay1 }
                                                    Rectangle { anchors { right: parent.right; bottom: parent.bottom; margins: Theme.space10 } width: 26; height: 12; radius: 6; color: Theme.accentIn(modeTile.pal) }
                                                }
                                            }
                                        }
                                    }
                                    Caption { Layout.topMargin: Theme.space4; text: Tr.t("Accent") }
                                    Row {
                                        spacing: Theme.space8
                                        Repeater {
                                            model: Palettes.accentChoices
                                            AccentSwatch { required property string modelData; accent: modelData }
                                        }
                                        Rectangle {
                                            width: 30; height: 30; radius: 15
                                            color: Config.theme.wallpaperAccent ? Theme.accent : Theme.tint(parent, Theme.text, 0.06)
                                            border { width: Config.theme.wallpaperAccent ? 2 : 1; color: Config.theme.wallpaperAccent ? Theme.accent : Theme.rimOn(parent) }
                                            Icon { anchors.centerIn: parent; name: "image"; size: 14; color: Config.theme.wallpaperAccent ? Theme.textOnAccent : Theme.subtext0 }
                                            PressArea { label: Tr.t("Accent from wallpaper"); role: Accessible.CheckBox; checked: Config.theme.wallpaperAccent; anchors.fill: parent; onClicked: { Config.theme.wallpaperAccent = !Config.theme.wallpaperAccent; root.changed(); } }
                                        }
                                    }
                                    Caption { Layout.topMargin: Theme.space4; text: Tr.t("Wallpaper") }
                                    GridLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        columns: 3
                                        columnSpacing: 12
                                        rowSpacing: 12
                                        Repeater {
                                            model: Math.min(root.walls.length, 6)
                                            Tile {
                                                id: wallTile
                                                required property int index
                                                readonly property string path: root.walls[index] ?? ""
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                Layout.minimumHeight: 60
                                                selected: Walls.same(Config.wallpaperPath, path)
                                                onClicked: { Config.wallpaper.path = path; root.changed(); }
                                                ClippingRectangle {
                                                    anchors.fill: parent
                                                    radius: 10
                                                    color: Theme.tint(parent, Theme.text, 0.06)
                                                    Image {
                                                        anchors.fill: parent
                                                        source: wallTile.path ? "file://" + Config.wallpaperFileOf(wallTile.path) : ""
                                                        sourceSize.width: 360
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Page {
                                    index: 2
                                    Heading { title: Tr.t("Desktop") }
                                    Caption { text: Tr.t("Bar") }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.space12
                                        Repeater {
                                            model: BarStyles.styles
                                            Tile {
                                                id: shapeTile
                                                required property var modelData
                                                readonly property var look: BarStyles.preview(modelData.id)
                                                Layout.fillWidth: true
                                                implicitHeight: 104
                                                label: Tr.t(modelData.label)
                                                selected: BarStyles.current(Config.bar) === modelData.id
                                                onClicked: { BarStyles.apply(Config.bar, modelData.id); root.changed(); }
                                                Item {
                                                    anchors.fill: parent
                                                    clip: true
                                                    BarShape {
                                                        y: 6
                                                        width: parent.width
                                                        height: 50
                                                        barHeight: 12
                                                        corner: 0
                                                        shoulder: shapeTile.look.square ? 0 : 10
                                                        radius: shapeTile.look.radius ? 12 : 0
                                                        square: shapeTile.look.square
                                                        notchCorner: shapeTile.look.notchCorner
                                                        style: shapeTile.look.style
                                                        drawers: shapeTile.look.flat ? [] : [{ center: width / 2, width: 70, hang: 28 }]
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    OptionRow {
                                        Layout.topMargin: Theme.space6
                                        icon: "windows"; title: Tr.t("Bar height")
                                        Choice {
                                            options: [{ value: 28, label: Tr.t("Compact") }, { value: 32, label: Tr.t("Normal") }, { value: 36, label: Tr.t("Tall") }]
                                            current: Config.bar.height
                                            onPicked: v => { Config.bar.height = v; root.changed(); }
                                        }
                                    }
                                    OptionRow {
                                        icon: "sliders"; title: Tr.t("Motion")
                                        Choice {
                                            options: [{ value: "bouncy", label: Tr.t("Bouncy") }, { value: "smooth", label: Tr.t("Smooth") }, { value: "snappy", label: Tr.t("Snappy") }]
                                            current: Config.theme.animationStyle
                                            onPicked: v => { Config.theme.animationStyle = v; root.changed(); }
                                        }
                                    }
                                    Item { Layout.fillHeight: true }
                                }

                                Page {
                                    index: 3
                                    Heading { title: Tr.t("Keyboard & time") }
                                    Caption { text: Tr.t("Layouts") }
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: Theme.space8
                                        Repeater {
                                            model: Keyboard.entries
                                            Rectangle {
                                                required property var modelData
                                                required property int index
                                                implicitWidth: kbRow.implicitWidth + 24
                                                implicitHeight: 36
                                                radius: Theme.r(16)
                                                color: Theme.accent
                                                RowLayout {
                                                    id: kbRow
                                                    anchors.centerIn: parent
                                                    spacing: Theme.space8
                                                    Label { mono: true; font.weight: Font.DemiBold; color: Theme.textOnAccent; text: modelData.code }
                                                    Label { color: Theme.textOnAccent; text: modelData.name }
                                                    Icon {
                                                        visible: Keyboard.entries.length > 1
                                                        name: "close"; size: 12
                                                        color: Theme.textOnAccent
                                                        PressArea { label: Tr.t("Remove"); id: kbX; anchors.fill: parent; anchors.margins: -5; onClicked: Keyboard.remove(index) }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Field { id: kbSearch; Layout.fillWidth: true; placeholder: Tr.t("Add a layout") }
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: Theme.space8
                                        visible: kbSearch.text !== ""
                                        Repeater {
                                            model: Keyboard.search(kbSearch.text, 6)
                                            Button {
                                                required property var modelData
                                                icon: "plus"
                                                text: modelData.name
                                                onClicked: { Keyboard.add(modelData.layout, modelData.variant); kbSearch.text = ""; }
                                            }
                                        }
                                    }
                                    Caption { Layout.topMargin: Theme.space6; text: Tr.f("Time zone · {0}", TimeZone.city(TimeZone.current) + ", " + TimeZone.country(TimeZone.current)) }
                                    SearchField { id: tzField; Layout.fillWidth: true; placeholder: Tr.t("A city or a country…") }
                                    PickList {
                                        maxRows: 4
                                        current: TimeZone.current
                                        model: TimeZone.search(tzField.text, 20).map(z => ({ value: z, title: TimeZone.city(z), caption: TimeZone.country(z) }))
                                        onPicked: z => { TimeZone.set(z); tzField.text = ""; }
                                    }
                                    OptionRow {
                                        Layout.topMargin: Theme.space6
                                        icon: "timer"; title: Tr.t("Clock")
                                        Choice {
                                            options: [{ value: "HH:mm", label: "24-hour" }, { value: "h:mm AP", label: "12-hour" }, { value: "HH:mm:ss", label: Tr.t("Seconds") }]
                                            current: Config.bar.clockFormat
                                            onPicked: v => { Config.bar.clockFormat = v; root.changed(); }
                                        }
                                    }
                                    Item { Layout.fillHeight: true }
                                }

                                Page {
                                    index: 4
                                    Heading { title: Tr.t("About you"); sub: "For the control center: the weather where you are, and the weeks ahead" }
                                    OptionRow {
                                        icon: "calendar"; title: Tr.t("Birthday")
                                        Field {
                                            implicitWidth: 150
                                            mono: true
                                            placeholder: Tr.t("DD.MM.YYYY")
                                            text: Config.lifeText()
                                            onCommitted: t => { Config.setBirthday(t); root.changed(); }
                                        }
                                    }
                                    Caption {
                                        Layout.topMargin: Theme.space6
                                        text: Tr.f("Weather for · {0}", Config.weather.city || (TimeZone.current ? TimeZone.city(TimeZone.current) + Tr.t(" (time zone)") : Tr.t("the time zone's city")))
                                    }
                                    CityPicker { Layout.fillWidth: true; maxRows: 4; onChosen: root.changed() }
                                    Item { Layout.fillHeight: true }
                                }

                                Page {
                                    index: 5
                                    Heading { title: Tr.t("Internet") }
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        WifiView {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: Math.min(parent.width, 460)
                                            device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
                                            open: win.opened && root.step === 5
                                        }
                                    }
                                }

                                Page {
                                    index: 6
                                    Heading { title: Tr.t("Extras") }
                                    OptionRow {
                                        icon: "sunset"; title: Tr.t("Night light in the evening")
                                        Switch { checked: Config.nightLight.automatic; onToggled: on => { Config.nightLight.automatic = on; root.changed(); } }
                                    }
                                    OptionRow {
                                        icon: "bell"; title: Tr.t("Sounds")
                                        Switch { checked: Config.theme.sounds; onToggled: on => { Config.theme.sounds = on; root.changed(); } }
                                    }
                                    OptionRow {
                                        icon: "music"; title: Tr.t("Login sound")
                                        Choice {
                                            options: [{ value: "chime", label: Tr.t("Chime") }, { value: "bloom", label: Tr.t("Bloom") }, { value: "halo", label: Tr.t("Halo") }, { value: "off", label: Tr.t("Off") }]
                                            current: Config.theme.loginSound
                                            onPicked: v => {
                                                Config.theme.loginSound = v; root.changed();
                                                if (v !== "off") Quickshell.execDetached(["pw-play", Config.loginSoundPath(v)]);
                                            }
                                        }
                                    }
                                    OptionRow {
                                        icon: "touchpad"; title: Tr.t("Tap to click")
                                        Switch { checked: Config.input.tapToClick; onToggled: on => { Config.input.tapToClick = on; root.changed(); } }
                                    }
                                    Item { Layout.fillHeight: true }
                                }

                                Page {
                                    index: 7
                                    Item { Layout.fillHeight: true }
                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitWidth: 92; implicitHeight: 92; radius: 46
                                        color: Theme.accent
                                        scale: root.step === 7 ? 1 : 0.4
                                        Behavior on scale { Anim { duration: Theme.durationSlow * 1.5; easing.bezierCurve: Theme.curveSpring } }
                                        Icon { anchors.centerIn: parent; name: "check"; size: 42; stroke: 2.6; color: Theme.textOnAccent }
                                    }
                                    Label { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: Theme.space8; font.pixelSize: Theme.fontSizeDisplay; font.weight: Font.Bold; text: Tr.t("All set") }
                                    GridLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.topMargin: Theme.space12
                                        columns: 2
                                        columnSpacing: 18
                                        rowSpacing: 10
                                        Repeater {
                                            model: [
                                                [Tr.t("SUPER"), Tr.t("Start · type to search")], [Tr.t("SUPER + W"), Tr.t("Wallpapers")],
                                                [Tr.t("SUPER + SPACE"), Tr.t("Language")], [Tr.t("SUPER + I"), Tr.t("Settings")],
                                                [Tr.t("SUPER + ESC"), Tr.t("Power")], [Tr.t("SUPER + F1"), Tr.t("Every shortcut")],
                                            ]
                                            RowLayout {
                                                required property var modelData
                                                spacing: Theme.space10
                                                Rectangle {
                                                    implicitWidth: keyText.implicitWidth + 18; implicitHeight: 28; radius: 8
                                                    color: Theme.tint(parent, Theme.text, 0.07)
                                                    border { width: 1; color: Theme.rimOn(parent) }
                                                    Label { id: keyText; anchors.centerIn: parent; mono: true; font.pixelSize: Theme.fontSizeSmall; text: modelData[0] }
                                                }
                                                Label { color: Theme.subtext0; text: modelData[1] }
                                            }
                                        }
                                    }
                                    Item { Layout.fillHeight: true }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.space10
                                Button { visible: root.step > 0; text: Tr.t("Back"); onClicked: root.step-- }
                                Item { Layout.fillWidth: true }
                                Button {
                                    visible: root.step > 0 && root.step < root.steps.length - 1
                                    text: Tr.t("Skip")
                                    onClicked: root.step = root.steps.length - 1
                                }
                                Button {
                                    primary: true
                                    icon: root.step === root.steps.length - 1 ? "check" : "chevron-right"
                                    text: root.step === 0 ? Tr.t("Get started") : root.step === root.steps.length - 1 ? Tr.t("Start") : Tr.t("Next")
                                    onClicked: root.step < root.steps.length - 1 ? root.step++ : root.finish()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
