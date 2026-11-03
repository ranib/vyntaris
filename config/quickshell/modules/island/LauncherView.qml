import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Networking
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import "../../components/Slant.js" as Slant
import qs.services
import "Search.js" as Search
import "Emoji.js" as Emoji
import "../settings/SettingsIndex.js" as SettingsIndex

Item {
    id: root
    readonly property int gap: 16
    function out(y) { return Theme.slanted ? Slant.out(height, Theme.barHeight, y) : 0; }
    readonly property real fullWidth: 660
    readonly property real hang: gap + field.height + gap + chips.height + gap + listHeight + gap
    readonly property bool active: Panels.launcherOpen

    readonly property int rowHeight: 50
    readonly property int listHeight: list.count === 0 ? 56
        : Math.min(list.count, Config.launcher.maxVisible) * (rowHeight + list.spacing)

    width: fullWidth
    height: Theme.barHeight + hang

    FileView {
        id: stats
        path: Quickshell.statePath("launcher.json")
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: statsData
            property var launches: ({})
        }
    }

    function countLaunch(id) {
        const next = Object.assign({}, statsData.launches);
        next[id] = (next[id] ?? 0) + 1;
        statsData.launches = next;
        stats.writeAdapter();
    }

    readonly property var allApps: DesktopEntries.applications.values.filter(a => Search.listed(a))

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

    function cycleCategory(step) {
        categoryIndex = (categoryIndex + step + categories.length) % categories.length;
        list.currentIndex = 0;
    }

    function settingsResults(raw) {
        const q = raw.toLowerCase();
        if (q.length < 2) return [];
        const words = q.split(/\s+/).filter(w => w);
        const holds = text => {
            const t = text.toLowerCase(), at = t.indexOf(q);
            return at >= 0 && (q.length >= 4 || at === 0 || /[\s\-_.&]/.test(t[at - 1]));
        };
        const out = [];
        for (const p of SettingsIndex.pages) {
            const label = Tr.t(p.label);
            const m = holds(label) ? Search.fuzzy(raw, label) : null;
            const kw = (label + " " + p.label + " " + p.keywords).toLowerCase().split(/\s+/);
            const known = q.length >= 3 && words.every(w => kw.some(k => k.startsWith(w)));
            if (m)
                out.push({ kind: "setting", page: p, title: label, row: false, positions: m.positions, score: m.score });
            else if (known)
                out.push({ kind: "setting", page: p, title: label, row: false, positions: [], score: 60 });
        }
        for (const r of SettingsIndex.rows) {
            const p = SettingsIndex.page(r.page);
            const title = Tr.t(r.title);
            const m = holds(title) ? Search.fuzzy(raw, title) : holds(r.title) ? Search.fuzzy(raw, r.title) : null;
            if (!p || !m || r.title === p.label) continue;
            out.push({ kind: "setting", page: p, title: title, row: true, positions: holds(title) ? m.positions : [], score: m.score - 5 });
        }
        out.sort((a, b) => b.score - a.score);
        return out.slice(0, 4);
    }

    readonly property var results: {
        const raw = search.text.trim();

        if (raw.startsWith(">")) {
            const cmd = raw.slice(1).trim();
            return cmd ? [{ kind: "run", command: cmd }] : [];
        }

        if (raw.startsWith(";")) {
            const words = raw.slice(1).trim().toLowerCase().split(/\s+/).filter(w => w);
            return Emoji.list
                .filter(e => words.every(w => e[1].includes(w)))
                .slice(0, 80)
                .map(e => ({ kind: "emoji", char: e[0], name: e[1] }));
        }

        if (raw.startsWith("?"))
            return ArchWiki.results.slice(0, 8).map(p => ({ kind: "wiki", page: p }));
        if (raw.startsWith("/")) {
            return root.fileResults.map(f => ({ kind: "file", path: f.path, dir: f.dir, inside: f.inside, query: raw.slice(1).trim() }));
        }

        if (raw.startsWith(":")) {
            const q = raw.slice(1).trim().toLowerCase();
            return Clipboard.entries
                .filter(e => !q || e.text.toLowerCase().includes(q))
                .map(e => ({ kind: "clip", entry: e }));
        }

        const out = [];
        const command = Search.command(raw, SettingsIndex.pages, Tr.t, Tr.lang);
        if (command) out.push(Object.assign({ kind: "command" }, command));
        const money = Search.money(raw, Rates.rates);
        if (money) out.push({ kind: "calc", value: money.value, label: money.label, date: money.date });
        const calc = Search.calculate(raw);
        if (calc !== null) out.push({ kind: "calc", value: calc });
        const conv = Search.convert(raw);
        if (conv !== null) out.push({ kind: "calc", value: conv.value, label: conv.label });

        const timerMatch = raw.match(/^(timer|alarm)\s+(.+)$/i);
        if (timerMatch) {
            const secs = Chrono.parseDuration(timerMatch[2]);
            if (secs > 0) out.push({ kind: "timer", seconds: secs });
        }
        if (/^stopwatch$/i.test(raw)) out.push({ kind: "stopwatch" });

        if (raw && category === "All") {
            const wins = [];
            for (const t of Hyprland.toplevels.values) {
                const appId = t.wayland?.appId ?? "";
                const m = Search.fuzzy(raw, t.title ?? "") ?? Search.fuzzy(raw, appId);
                if (!m || m.score < 20) continue;
                wins.push({ kind: "window", toplevel: t, appId, score: m.score });
            }
            wins.sort((a, b) => b.score - a.score);
            for (const w of wins.slice(0, 4)) out.push(w);
        }

        const launches = statsData.launches;
        const freq = a => launches[a.id] ?? 0;
        let apps = allApps;
        if (category !== "All") apps = apps.filter(a => Search.category(a) === category);

        if (!raw) {
            return out.concat(apps.slice()
                .sort((a, b) => freq(b) - freq(a) || a.name.localeCompare(b.name))
                .map(a => ({ kind: "app", app: a, positions: [], frequent: freq(a) > 0 })));
        }

        const q = raw.toLowerCase();
        const matched = [];
        for (const a of apps) {
            const m = Search.fuzzy(raw, a.name);
            let score = m ? m.score : -1;
            if (!m) {
                const extra = [a.genericName, a.comment, ...(a.keywords ?? [])].join(" ").toLowerCase();
                if (extra.includes(q)) score = 5;
            }
            if (score < 0) continue;
            matched.push({ kind: "app", app: a, positions: m ? m.positions : [],
                           score: score + Math.log2(freq(a) + 1) * 6, frequent: freq(a) > 0 });
        }
        const appCount = matched.length;
        if (category === "All" || category === "System")
            for (const s of settingsResults(raw)) matched.push(s);
        const nameOf = r => r.kind === "app" ? r.app.name : r.title;
        matched.sort((x, y) => y.score - x.score || nameOf(x).localeCompare(nameOf(y)));

        const withActions = [];
        matched.forEach((r, i) => {
            withActions.push(r);
            if (r.kind === "app" && i < 3 && r.score >= 100)
                for (const act of (r.app.actions ?? []).slice(0, 4))
                    withActions.push({ kind: "action", app: r.app, action: act });
        });
        if (category === "All")
            for (const f of root.docResults.slice(0, 4))
                withActions.push({ kind: "file", path: f.path, dir: f.dir, inside: f.inside, query: raw });
        if (appCount < 3 && q.length >= 2 && ArchWiki.installed) withActions.push({ kind: "wiki-search", query: raw });
        if (appCount < 3 && q.length >= 2 && out.length === 0) withActions.push({ kind: "store", query: raw });
        return out.concat(withActions);
    }

    function activate(i) {
        const r = results[i];
        if (!r) return;
        if (r.kind === "app") {
            if (r.app.runInTerminal) Config.runInTerminal(r.app.command.join(" "));
            else if (!Games.launch(r.app)) Config.openEntry(r.app);
            countLaunch(r.app.id);
        } else if (r.kind === "action") {
            Config.openEntry(r.action);
            countLaunch(r.app.id);
        } else if (r.kind === "emoji") {
            Quickshell.clipboardText = r.char;
        } else if (r.kind === "file") {
            Config.launch(["xdg-open", r.path]);
        } else if (r.kind === "calc") {
            Quickshell.clipboardText = String(r.value);
        } else if (r.kind === "run") {
            Config.launch(["sh", "-c", r.command]);
        } else if (r.kind === "clip") {
            Clipboard.copy(r.entry);
        } else if (r.kind === "window") {
            const a = String(r.toplevel.address);
            Compositor.dispatch(`hl.dsp.focus({ window = "address:${a.startsWith("0x") ? a : "0x" + a}" })`);
        } else if (r.kind === "timer") {
            Chrono.startTimer(r.seconds);
        } else if (r.kind === "stopwatch") {
            if (!Chrono.swRunning) Chrono.toggleStopwatch();
        } else if (r.kind === "wiki") {
            ArchWiki.open(r.page);
            Panels.launcherOpen = false;
        } else if (r.kind === "wiki-search") {
            Panels.wiki(r.query);
        } else if (r.kind === "store") {
            Panels.store(r.query);
        } else if (r.kind === "setting") {
            if (r.row) Panels.settingsRow(r.page.id, r.title);
            else Panels.settings(r.page.id);
        } else if (r.kind === "command") {
            Panels.launcherOpen = false;
            runCommand(r);
            return;
        }
        Panels.launcherOpen = false;
    }

    property var fileResults: []
    property var docResults: []
    function parseFiles(text) {
        const seen = new Set();
        return text.split("\n").filter(l => l.length > 2).map(l => ({ dir: l[0] === "d", inside: l[0] === "c", path: l.slice(2) }))
            .filter(f => !seen.has(f.path) && seen.add(f.path));
    }
    Timer {
        id: fileDebounce
        interval: 220
        onTriggered: {
            const q = search.text.slice(1).trim();
            if (q.length < 2) { root.fileResults = []; return; }
            fileSearch.running = false;
            fileSearch.command = [Quickshell.shellPath("scripts/find-files.sh"), q, "both", "40"];
            fileSearch.running = true;
        }
    }
    Process {
        id: fileSearch
        stdout: StdioCollector { onStreamFinished: root.fileResults = root.parseFiles(text) }
    }
    Timer {
        id: docDebounce
        interval: 350
        onTriggered: {
            const q = search.text.trim();
            if (q.length < 3 || /^[>;:\/]/.test(q) || Search.command(q, SettingsIndex.pages, Tr.t, Tr.lang)
                || Search.calculate(q) !== null || Search.convert(q) !== null || Search.moneyQuery(q)) {
                root.docResults = [];
                return;
            }
            docSearch.running = false;
            docSearch.command = [Quickshell.shellPath("scripts/find-files.sh"), q, "both", "4"];
            docSearch.running = true;
        }
    }
    Process {
        id: docSearch
        stdout: StdioCollector { onStreamFinished: root.docResults = root.parseFiles(text) }
    }

    function runCommand(c) {
        const v = c.value;
        const sink = Pipewire.defaultAudioSink?.audio, mic = Pipewire.defaultAudioSource?.audio;
        switch (c.action) {
        case "bluetooth": BluetoothCtl.setEnabled(v === null ? !BluetoothCtl.enabled : v); break;
        case "wifi": Networking.wifiEnabled = v === null ? !Networking.wifiEnabled : v; break;
        case "dnd": Notifications.dnd = v === null ? !Notifications.dnd : v; break;
        case "nightlight": if (v === null || v !== NightLight.active) NightLight.toggle(); break;
        case "gamemode": if (v === null || v !== GameMode.active) GameMode.toggle(); break;
        case "awake": if (v === null || v !== KeepAwake.active) KeepAwake.toggle(); break;
        case "mic": if (mic) mic.muted = v === null ? !mic.muted : !v; break;
        case "mute": if (sink) sink.muted = v; break;
        case "volume": if (sink) { sink.muted = false; sink.volume = Math.min(v, Config.maxVolume); } break;
        case "brightness": Brightness.set(v); break;
        case "dark": {
            const dark = v === null ? Config.theme.flavor === "latte" : v;
            Config.theme.autoFlavor = false;
            Config.theme.flavor = dark ? (Config.theme.darkFlavor || "mocha") : "latte";
            Config.saveSoon();
            break;
        }
        case "lock": Quickshell.execDetached(["loginctl", "lock-session"]); break;
        case "suspend": Quickshell.execDetached(["sh", "-c", Config.power.suspend]); break;
        case "reboot": Leaving.run("reboot", Config.power.reboot); break;
        case "shutdown": Leaving.run("shutdown", Config.power.shutdown); break;
        case "logout": Leaving.run("logout", Config.power.logout); break;
        case "screenshot": Screenshot.capture("screen"); break;
        case "screenshot-region": Screenshot.capture("region"); break;
        case "record": Recorder.toggle("screen"); break;
        case "updates": Panels.updatesOpen = true; break;
        case "health": Panels.openApp("doctor"); break;
        case "drivers": Panels.settings("drivers"); break;
        case "sound": Panels.soundOpen = true; break;
        case "games-setup": Games.setUp(); break;
        case "undo-update": Panels.settings("backups"); break;
        case "phone-ring": if (Phone.phone) Phone.ring(Phone.phone.id); else Panels.phoneOpen = true; break;
        case "phone-clipboard": if (Phone.phone) Phone.clipboard(Phone.phone.id); else Panels.phoneOpen = true; break;
        case "phone": Panels.phoneOpen = true; break;
        case "trash": Quickshell.execDetached(["gio", "trash", "--empty"]); break;
        case "settings": Panels.settings(v); break;
        }
    }

    property bool entering: false
    Timer { id: enterTimer; interval: Theme.durationSlow + 300; onTriggered: root.entering = false }

    property bool applying: false
    function applyQuery() {
        applying = true;
        search.text = Panels.launcherQuery;
        Panels.launcherQuery = "";
        search.cursorPosition = search.text.length;
        applying = false;
    }
    function backToStart() { Panels.controlOpen = true; }
    function typeIn(text) {
        search.insert(search.cursorPosition, text);
        search.forceActiveFocus();
    }

    // The wiki's answer comes a moment after the typing: Enter means its first row.
    Connections {
        target: ArchWiki
        function onResultsChanged() { if (search.text.startsWith("?")) list.currentIndex = 0; }
    }
    Component.onCompleted: if (active) activeChanged()
    onActiveChanged: {
        if (!active) return;
        categoryIndex = 0;
        applyQuery();
        list.currentIndex = 0;
        list.positionViewAtBeginning();
        entering = true;
        enterTimer.restart();
        search.forceActiveFocus();
        focusTimer.restart();
    }
    Connections {
        target: Panels
        function onLauncherQueryChanged() { if (root.active && Panels.launcherQuery !== "") root.applyQuery(); }
    }
    Timer { id: focusTimer; interval: 30; onTriggered: search.forceActiveFocus() }
    Connections {
        target: root.Window.window
        function onActiveChanged() { if (root.active && root.Window.window.active) search.forceActiveFocus(); }
    }

    PanelHeader {
        inset: root.gap
        icon: "search"
        title: search.text.startsWith(">") ? Tr.t("Run") : search.text.startsWith(":") ? Tr.t("Clipboard")
            : search.text.startsWith("/") ? Tr.t("Files") : search.text.startsWith(";") ? Tr.t("Emoji") : search.text.startsWith("?") ? Tr.t("Arch Wiki") : Tr.t("Search")
    }

    PanelSurface {
        id: field
        x: root.gap - root.out(y + height)
        y: Theme.barHeight + root.gap
        width: parent.width - 2 * root.gap + 2 * root.out(y + height)
        height: Theme.controlHeight
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
        }
        Icon {
            id: prompt
            anchors.centerIn: disc
            name: search.text.startsWith(">") ? "next" : search.text.startsWith(":") ? "clipboard"
                : search.text.startsWith("/") ? "folder" : "search"
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
                text: list.count
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

            onTextChanged: {
                if (text === "" && !root.applying && root.active) { root.backToStart(); return; }
                if (text.startsWith("?")) ArchWiki.setQuery(text.slice(1));
                list.currentIndex = 0;
                if (text === ":") Clipboard.refresh();
                if (text.startsWith("/")) fileDebounce.restart(); else root.fileResults = [];
                docDebounce.restart();
                if (Search.moneyQuery(text)) Rates.want();
            }
            Keys.onEscapePressed: Panels.launcherOpen = false
            Keys.onPressed: event => { if (event.key === Qt.Key_Backspace && text === "") { root.backToStart(); event.accepted = true; } }
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onTabPressed: root.cycleCategory(1)
            Keys.onBacktabPressed: root.cycleCategory(-1)
            Keys.onReturnPressed: root.activate(list.currentIndex)
            Keys.onEnterPressed: root.activate(list.currentIndex)

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: !search.text
                text: Tr.t("Search apps, settings, windows, files…")
                color: Theme.overlay0
                font: search.font
            }
        }

    }

    Item {
        id: chips
        anchors { top: field.bottom; topMargin: root.gap; left: parent.left; leftMargin: root.gap + 5 - root.out(y + height) }
        width: parent.width - 2 * (root.gap + 5) + 2 * root.out(y + height)
        height: 28

        Rectangle {
            readonly property Item target: chipRow.children[root.categoryIndex] ?? null
            x: target?.x ?? 0
            width: target?.width ?? 0
            height: parent.height
            radius: Theme.r(height / 2)
            color: Theme.accent
            Behavior on x { Anim { duration: Theme.durationNormal; easing.bezierCurve: Theme.curveSpring } }
            Behavior on width { Anim { duration: Theme.durationNormal } }
        }
        Row {
            id: chipRow
            height: parent.height
            width: parent.width
            spacing: {
                let words = 0, n = 0;
                for (const c of children) if (c.isChip) { words += c.width; n++; }
                return n > 1 ? Math.max(0, (width - words) / (n - 1)) : 0;
            }
            Repeater {
                model: root.categories
                Item {
                    required property string modelData
                    required property int index
                    readonly property bool current: root.categoryIndex === index
                    readonly property bool isChip: true
                    width: chipText.implicitWidth + 24
                    height: chipRow.height
                    Label {
                        id: chipText
                        anchors.centerIn: parent
                        font.weight: current ? Font.DemiBold : Font.Normal
                        text: root.categoryName(modelData)
                        color: current ? Theme.textOnAccent : chipArea.containsMouse ? Theme.subtext0 : Theme.overlay1
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.categoryIndex = index; list.currentIndex = 0; }
                    }
                }
            }
        }
    }

    ListView {
        id: list
        anchors { top: chips.bottom; topMargin: root.gap; left: parent.left; right: parent.right
                  leftMargin: root.gap - widest; rightMargin: root.gap - widest }
        readonly property real widest: root.out(y)
        function lane(row) { return row ? widest - root.out(y + row.y - contentY + row.height) : 0; }
        height: root.listHeight
        clip: true
        spacing: Theme.space2
        model: root.results
        keyNavigationWraps: true
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: Theme.durationFast
        highlightResizeDuration: 0
        highlightFollowsCurrentItem: false
        highlight: PanelSurface {
            readonly property Item at: list.currentItem
            readonly property real lane: list.lane(at)
            x: lane
            y: at?.y ?? 0
            width: list.width - 2 * lane
            height: at?.height ?? 0
            radius: Theme.r(12)
            fill: Theme.accent
            Behavior on y { Anim { duration: Theme.durationFast } }
        }

        delegate: Item {
            id: entry
            required property var modelData
            required property int index
            readonly property bool selected: ListView.isCurrentItem
            readonly property string kind: modelData.kind
            width: list.width
            height: root.rowHeight

            Component.onCompleted: {
                if (root.entering && index < Config.launcher.maxVisible) {
                    opacity = 0;
                    row.x = 24;
                    intro.start();
                }
            }
            SequentialAnimation {
                id: intro
                PauseAnimation { duration: Theme.duration(140 + entry.index * 28) }
                ParallelAnimation {
                    Anim { target: entry; property: "opacity"; to: 1 }
                    Anim { target: row; property: "x"; to: 0; easing.bezierCurve: Theme.curveDecelerate }
                }
            }

            Item {
                id: laneBox
                x: list.lane(entry)
                width: parent.width - 2 * x
                height: parent.height
                RowLayout {
                    id: row
                    width: parent.width
                    height: parent.height
                    spacing: Theme.space14

                    Item { implicitWidth: 4 }

                    Rectangle {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 18
                        color: "transparent"

                        AppIcon {
                            id: appIcon
                            anchors.centerIn: parent
                            visible: entry.kind === "app" || entry.kind === "action" || entry.kind === "window"
                            implicitSize: entry.kind === "action" ? 18 : 28
                            tint: entry.selected ? Theme.accentBright : Theme.accent
                            source: entry.kind === "window"
                                ? Quickshell.iconPath(DesktopEntries.heuristicLookup(entry.modelData.appId)?.icon ?? entry.modelData.appId, true)
                                  || Quickshell.iconPath("application-x-executable", true)
                                : entry.kind !== "app" && entry.kind !== "action" ? ""
                                : Quickshell.iconPath(entry.modelData.action?.icon || entry.modelData.app.icon, true)
                                  || Quickshell.iconPath("application-x-executable", true)
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: entry.kind === "emoji"
                            font.pixelSize: Theme.fontSizeTitle
                            text: entry.modelData.char ?? ""
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: entry.kind === "timer" || entry.kind === "stopwatch"
                            name: "timer"
                            size: 17
                            color: entry.selected ? Theme.textOnAccent : Theme.accentInk
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: entry.kind === "command"
                            name: entry.modelData.icon ?? "settings"
                            size: 16
                            color: entry.selected ? Theme.textOnAccent : Theme.accentInk
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: entry.kind === "setting"
                            name: entry.modelData.page?.icon ?? "settings"
                            size: 16
                            color: entry.selected ? Theme.textOnAccent : Theme.accentInk
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: entry.kind === "file" || entry.kind === "store" || entry.kind === "wiki" || entry.kind === "wiki-search"
                            name: entry.kind === "store" ? "package" : entry.kind === "wiki" || entry.kind === "wiki-search" ? "info" : entry.modelData.dir ? "folder" : entry.modelData.inside ? "search" : "external"
                            size: 16
                            color: entry.selected ? Theme.textOnAccent : Theme.subtext0
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: (entry.kind === "app" && appIcon.source == "") || entry.kind === "calc" || entry.kind === "run" || entry.kind === "clip"
                            mono: true
                            font.weight: Font.Bold
                            color: entry.selected ? Theme.textOnAccent : entry.kind !== "app" ? Theme.accentInk : Theme.subtext0
                            text: entry.kind === "calc" ? "="
                                : entry.kind === "run" ? ">_"
                                : entry.kind === "clip" ? (entry.modelData.entry.isImage ? "▣" : "¶")
                                : (entry.modelData.app?.name ?? "").charAt(0).toUpperCase()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space2

                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            textFormat: entry.kind === "app" || entry.kind === "setting" ? Text.StyledText : Text.PlainText
                            mono: entry.kind === "calc" || entry.kind === "run" || entry.kind === "clip"
                            font.pixelSize: entry.kind === "calc" ? Theme.fontSizeTitle : Theme.fontSize
                            font.weight: entry.kind === "calc" ? Font.DemiBold : Font.Normal
                            color: entry.selected ? Theme.textOnAccent : Theme.subtext1
                            text: entry.kind === "calc" ? (entry.modelData.label ?? "") + String(entry.modelData.value)
                                : entry.kind === "window" ? entry.modelData.toplevel.title
                                : entry.kind === "timer" ? Tr.t("Timer") + " · " + Chrono.format(entry.modelData.seconds * 1000)
                                : entry.kind === "stopwatch" ? Tr.t("Stopwatch")
                                : entry.kind === "command" ? entry.modelData.title
                                : entry.kind === "wiki" ? entry.modelData.page.title + (entry.modelData.page.section ? "  \u203a  " + entry.modelData.page.section : "")
                                : entry.kind === "wiki-search" ? Tr.f("Search the Arch Wiki for \u201c{0}\u201d", entry.modelData.query)
                                : entry.kind === "store" ? Tr.f("Search the Store for \u201c{0}\u201d", entry.modelData.query)
                                : entry.kind === "run" ? entry.modelData.command
                                : entry.kind === "emoji" ? entry.modelData.name
                                : entry.kind === "file" ? entry.modelData.path.split("/").pop()
                                : entry.kind === "action" ? "↳  " + entry.modelData.action.name
                                : entry.kind === "clip" ? entry.modelData.entry.text.replace(/\s+/g, " ").slice(0, 200)
                                : entry.kind === "setting" ? Search.highlight(entry.modelData.title, entry.modelData.positions, (entry.selected ? Theme.textOnAccent : Theme.accent).toString())
                                : Search.highlight(entry.modelData.app.name, entry.modelData.positions, (entry.selected ? Theme.textOnAccent : Theme.accent).toString())
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            elide: Text.ElideRight
                            color: entry.selected ? Theme.tint(parent, Theme.textOnAccent, 0.75) : Theme.overlay1
                            font.pixelSize: Theme.fontSizeSmall
                            text: entry.kind === "calc" ? (entry.modelData.date ? Tr.f("Exchange rate of {0}", entry.modelData.date) : entry.modelData.label ? Tr.t("Conversion") : Tr.t("Result"))
                                : entry.kind === "command" ? Tr.t("Command")
                                : entry.kind === "window" ? Tr.t("Open window") + " · " + (entry.modelData.toplevel.workspace ? Tr.t("Workspace") + " " + entry.modelData.toplevel.workspace.id : entry.modelData.appId)
                                : entry.kind === "timer" ? Tr.t("Start a timer")
                                : entry.kind === "stopwatch" ? Tr.t("Start the stopwatch")
                                : entry.kind === "wiki" ? (ArchWiki.plain(entry.modelData.page.snippet) || Tr.t("Arch Wiki, also without internet"))
                                : entry.kind === "wiki-search" ? Tr.t("Arch Wiki, also without internet")
                                : entry.kind === "store" ? Tr.t("Apps from Arch and the AUR, installed with a click")
                                : entry.kind === "run" ? Tr.t("Shell command")
                                : entry.kind === "emoji" ? ""
                                : entry.kind === "file" ? (entry.modelData.inside ? Tr.f("Has \u201c{0}\u201d in it · ", entry.modelData.query) : "")
                                    + entry.modelData.path.replace(Quickshell.env("HOME"), "~")
                                : entry.kind === "action" ? entry.modelData.app.name
                                : entry.kind === "clip" ? (entry.modelData.entry.isImage ? Tr.t("Image") : Tr.t("Text"))
                                : entry.kind === "setting" ? (entry.modelData.row ? Tr.t("Settings · ") + entry.modelData.page.label : Tr.t("Settings page"))
                                : entry.modelData.app.comment || entry.modelData.app.genericName || ""
                        }
                    }

                    Rectangle {
                        visible: entry.kind === "app" && entry.modelData.frequent && !entry.selected
                        implicitWidth: 4
                        implicitHeight: 4
                        radius: 2
                        color: Theme.accent
                    }

                    Label {
                        overline: true
                        font.pixelSize: Theme.fontSizeSmall
                        color: entry.selected ? Theme.textOnAccent : Theme.overlay0
                        text: entry.selected
                            ? (entry.kind === "calc" || entry.kind === "clip" || entry.kind === "emoji" ? Tr.t("Copy ↵")
                                : entry.kind === "run" || entry.kind === "command" ? Tr.t("Run ↵")
                                : entry.kind === "window" ? Tr.t("Switch ↵")
                                : entry.kind === "timer" || entry.kind === "stopwatch" ? Tr.t("Start ↵") : Tr.t("Open ↵"))
                            : entry.kind === "app" ? root.categoryName(Search.category(entry.modelData.app))
                            : entry.kind === "setting" ? Tr.t("Settings") : ""
                    }

                    Item { implicitWidth: 2 }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: list.currentIndex = entry.index
                onClicked: root.activate(entry.index)
            }
        }

        Label {
            anchors.centerIn: parent
            visible: list.count === 0
            text: search.text.startsWith(">") ? Tr.t("Type a command")
                : search.text.startsWith(":") ? Tr.t("Clipboard is empty")
                : search.text.startsWith("/") ? (search.text.length < 3 ? Tr.t("Type a file name") : Tr.t("No files found"))
                : Tr.t("No matches")
            color: Theme.overlay1
        }
    }

}
