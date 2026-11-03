import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import "../../components/Slant.js" as Slant
import qs.services
import "Search.js" as Search

Item {
    id: root
    readonly property int gap: 16
    function out(y) { return Theme.slanted ? Slant.out(height, Theme.barHeight, y) : 0; }

    readonly property int columns: 5
    readonly property int rows: 3
    readonly property real cell: 108
    // The rows of icons end level with the menu beside them.
    readonly property real menuHeight: categories.length * Theme.navItemHeight + (categories.length - 1) * side.spacing
    readonly property real cellHeight: Math.max(68, (menuHeight - Theme.controlHeight - 12) / rows)
    readonly property real sideWidth: Theme.navItemWidth
    readonly property real listWidth: columns * cell
    readonly property real fullWidth: gap + sideWidth + gap + listWidth + gap
    readonly property real hang: gap + field.height + 12 + grid.height + gap
    readonly property bool active: Panels.appsOpen

    width: fullWidth
    height: Theme.barHeight + hang

    readonly property var allApps: DesktopEntries.applications.values.filter(a => Search.listed(a))
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var categories: {
        const order = ["Internet", "Development", "Media", "Graphics", "Office", "Games", "Utility", "System"];
        const present = new Set(allApps.map(a => Search.category(a)));
        return ["All"].concat(order.filter(c => present.has(c)));
    }
    property int categoryIndex: 0
    readonly property string category: categories[categoryIndex] ?? "All"
    function categoryName(c) {
        return ({ All: Tr.t("All"), Internet: Tr.t("Internet"), Development: Tr.t("Development"), Media: Tr.t("Media"),
                  Graphics: Tr.t("Graphics"), Office: Tr.t("Office"), Games: Tr.t("Games"), Utility: Tr.t("Utility"),
                  System: Tr.t("System") })[c] ?? c;
    }
    function categoryIcon(c) {
        return ({ All: "apps", Internet: "globe", Development: "terminal", Media: "play", Graphics: "image",
                  Office: "folder", Games: "gamepad", Utility: "settings", System: "cpu" })[c] ?? "apps";
    }
    readonly property var apps: {
        const q = search.text.trim().toLowerCase();
        return allApps.filter(a => (category === "All" || Search.category(a) === category)
            && (!q || a.name.toLowerCase().includes(q) || (a.genericName ?? "").toLowerCase().includes(q)
                || (a.keywords ?? []).some(k => k.toLowerCase().includes(q))));
    }
    function cycle(step) {
        categoryIndex = (categoryIndex + step + categories.length) % categories.length;
        grid.currentIndex = 0;
    }

    property bool moved: false
    readonly property bool choosing: moved || search.text !== ""
    function step(move) { moved = true; move(); }

    property bool entering: false
    Timer { id: enterTimer; interval: Theme.durationSlow + 400; onTriggered: root.entering = false }
    onActiveChanged: if (active) {
        search.text = "";
        categoryIndex = 0;
        moved = false;
        grid.currentIndex = 0;
        grid.positionViewAtBeginning();
        entering = true;
        enterTimer.restart();
        focusLater.restart();
    }
    Component.onCompleted: if (active) activeChanged()
    Timer { id: focusLater; interval: 30; onTriggered: search.forceActiveFocus() }

    function start(app) {
        if (!app) return;
        if (app.runInTerminal) Config.runInTerminal(app.command.join(" "));
        else if (!Games.launch(app)) Config.openEntry(app);
        Panels.appsOpen = false;
    }

    PanelHeader {
        inset: root.gap
        icon: "apps"
        title: Tr.t("Apps")
    }

    Column {
        id: side
        x: root.gap
        y: field.y
        width: root.sideWidth
        spacing: Theme.navItemGap
        Repeater {
            model: root.categories
            Item {
                id: nav
                required property string modelData
                required property int index
                readonly property bool current: root.categoryIndex === index
                readonly property real lean: root.out(side.y + y + height)
                x: -lean
                width: side.width
                height: Theme.navItemHeight
                SlantShape {
                    anchors.fill: parent
                    fill: nav.current ? Theme.accent : navArea.containsMouse ? Theme.hoverOn(parent) : "transparent"
                    radius: Theme.navRadius
                    edges: ({ lt: root.out(side.y + nav.y) - nav.lean, lb: 0, rt: 0, rb: 0 })
                    Behavior on fill { ColorAnim {} }
                }
                RowLayout {
                    anchors { fill: parent; leftMargin: Theme.space12; rightMargin: Theme.space12 }
                    spacing: Theme.space10
                    Icon { name: root.categoryIcon(nav.modelData); size: 16; color: nav.current ? Theme.textOnAccent : Theme.overlay1 }
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.weight: nav.current ? Font.DemiBold : Font.Normal
                        color: nav.current ? Theme.textOnAccent : Theme.subtext0
                        text: root.categoryName(nav.modelData)
                    }
                }
                MouseArea {
                    id: navArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.categoryIndex = nav.index; grid.currentIndex = 0; search.forceActiveFocus(); }
                }
            }
        }
    }

    Item {
        id: field
        readonly property real lean: root.out(y + height)
        x: root.gap + root.sideWidth + root.gap
        y: Theme.barHeight + root.gap
        width: root.listWidth + lean
        height: Theme.controlHeight

        SlantShape {
            anchors.fill: parent
            fill: Theme.tint(parent, Theme.crust, 0.45)
            stroke: Theme.rimOn(parent)
            radius: Theme.r(field.height / 2)
            edges: ({ lt: 0, lb: 0, rt: root.out(field.y) - field.lean, rb: 0 })
        }
        Rectangle {
            id: disc
            anchors { left: parent.left; leftMargin: Theme.space6; verticalCenter: parent.verticalCenter }
            width: parent.height - 10
            height: width
            radius: width / 2
            color: Theme.accent
        }
        Icon {
            anchors.centerIn: disc
            name: "search"
            size: 16
            color: Theme.textOnAccent
        }
        Rectangle {
            id: fieldCount
            anchors { right: parent.right; rightMargin: Theme.space6; verticalCenter: parent.verticalCenter }
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
                text: grid.count
            }
        }
        TextInput {
            id: search
            anchors { left: disc.right; leftMargin: Theme.space12; right: fieldCount.left; rightMargin: Theme.space12; verticalCenter: parent.verticalCenter }
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.textOnAccent
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeLarge }
            clip: true
            onTextChanged: grid.currentIndex = 0
            Keys.onEscapePressed: Panels.appsOpen = false
            Keys.onTabPressed: root.cycle(1)
            Keys.onBacktabPressed: root.cycle(-1)
            Keys.onDownPressed: root.step(grid.moveCurrentIndexDown)
            Keys.onUpPressed: root.step(grid.moveCurrentIndexUp)
            Keys.onRightPressed: root.step(grid.moveCurrentIndexRight)
            Keys.onLeftPressed: root.step(grid.moveCurrentIndexLeft)
            Keys.onReturnPressed: root.start(root.apps[grid.currentIndex])
            Keys.onEnterPressed: root.start(root.apps[grid.currentIndex])

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: !search.text
                text: Tr.t("Search apps…")
                color: Theme.overlay0
                font: search.font
            }
        }
    }

    Item {
        id: gridClip
        x: field.x
        y: field.y + field.height + 12
        width: root.listWidth + root.out(y)
        height: grid.height
        clip: true

        GridView {
            id: grid
            width: root.columns * root.cell
            height: root.rows * root.cellHeight
            cellWidth: root.cell
            cellHeight: root.cellHeight
            function spread(tile) {
                const col = tile.index % root.columns;
                return col / (root.columns - 1) * root.out(gridClip.y + tile.y - contentY + root.cellHeight);
            }
            model: root.apps
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationWraps: true
            highlightMoveDuration: 0

            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool picked: GridView.isCurrentItem && root.choosing
                width: root.cell
                height: root.cellHeight

                Component.onCompleted: if (root.entering && index < root.columns * root.rows) { surface.opacity = 0; intro.start(); }
                SequentialAnimation {
                    id: intro
                    PauseAnimation { duration: Theme.duration(60 + tile.index * 14) }
                    Anim { target: surface; property: "opacity"; to: 1 }
                }

                Rectangle {
                    id: surface
                    x: 4 + grid.spread(tile); y: 4
                    width: parent.width - 8
                    height: parent.height - 8
                    radius: Theme.r(12)
                    color: tile.picked ? Theme.accent : "transparent"
                    scale: area.pressed ? 0.96 : 1
                    Behavior on color { ColorAnim {} }
                    Behavior on scale { Anim { duration: Theme.durationFast; easing.bezierCurve: Theme.curveSpring } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: Theme.space4
                        AppIcon {
                            Layout.alignment: Qt.AlignHCenter
                            implicitSize: 40
                            source: Quickshell.iconPath(tile.modelData.icon, true) || Quickshell.iconPath("application-x-executable", true)
                        }
                        Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeLabel
                            color: tile.picked ? Theme.textOnAccent : Theme.subtext1
                            text: tile.modelData.name
                        }
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: {
                        const at = mapToItem(root, mouseX, mouseY);
                        if (root.pointer && (at.x !== root.pointer.x || at.y !== root.pointer.y)) { root.moved = true; grid.currentIndex = tile.index; }
                        root.pointer = at;
                    }
                    onClicked: root.start(tile.modelData)
                }
            }

            Label {
                anchors.centerIn: parent
                visible: grid.count === 0
                color: Theme.overlay1
                text: Tr.t("No apps found")
            }
        }
    }
    property var pointer: null
}
