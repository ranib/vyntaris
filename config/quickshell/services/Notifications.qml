pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import QtQuick
import qs.config

Singleton {
    id: root

    property var queue: []
    readonly property var current: queue[0] ?? null
    readonly property int waiting: Math.max(0, queue.length - 1)

    property var history: []
    // A notification's app, brought forward: on Wayland an app can't raise its own window when told it was clicked,
    // so the shell does. Its window by the desktop entry or name the notification gives, or the app started.
    function focusApp(desktopEntry, appName) {
        const want = [desktopEntry, appName].filter(x => x).map(x => String(x).toLowerCase().replace(/\.desktop$/, ""));
        if (want.length === 0) return;
        const short = w => w.split(".").pop();
        const t = Hyprland.toplevels.values.find(t => {
            const c = String(t.lastIpcObject?.class ?? t.wayland?.appId ?? "").toLowerCase();
            return c && want.some(w => c === w || c === short(w) || short(c) === short(w));
        });
        if (t) {
            const address = String(t.address).startsWith("0x") ? t.address : "0x" + t.address;
            Compositor.dispatch(`hl.dsp.focus({ window = "address:${address}" })`);
        } else {
            const e = want.map(w => DesktopEntries.byId(w) ?? DesktopEntries.heuristicLookup(w)).find(e => e);
            e?.execute();
        }
    }
    readonly property int maxHistory: 50
    property int unread: 0
    property bool dnd: false

    function remove(n) {
        queue = queue.filter(x => x !== n);
    }

    function clearHistory() {
        history = [];
        unread = 0;
    }

    FileView {
        id: store
        path: Quickshell.statePath("notifications.json")
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                root.history = (saved.history ?? []).map(e => Object.assign({}, e, { time: new Date(e.time) }));
                root.dnd = saved.dnd ?? false;
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
    property bool loaded: false
    onHistoryChanged: if (loaded) saveTimer.restart()
    onDndChanged: if (loaded) saveTimer.restart()
    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: store.setText(JSON.stringify({ dnd: root.dnd, history: root.history }))
    }

    function removeAt(index) {
        history = history.filter((e, i) => i !== index);
    }

    function removeIndexes(list) {
        history = history.filter((e, i) => !list.includes(i));
    }

    function markRead() {
        unread = 0;
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        persistenceSupported: true

        onNotification: n => {
            if (Activities.pacmanBusy && /timeshift/i.test((n.desktopEntry ?? "") + " " + n.appName + " " + n.summary)) {
                n.dismiss();
                return;
            }
            if (n.hints?.value !== undefined) {
                n.tracked = true;
                Activities.trackProgress(n);
                return;
            }
            const entry = {
                id: n.id, appName: n.appName, appIcon: n.appIcon, summary: n.summary, body: n.body,
                image: n.image, time: new Date(), urgency: n.urgency, desktopEntry: n.desktopEntry ?? "",
            };
            const seen = root.history.some(e => e.id === n.id && e.appName === n.appName && e.summary === n.summary);
            if (!seen) {
                root.history = [entry].concat(root.history).slice(0, root.maxHistory);
                root.unread++;
            }

            const critical = n.urgency === NotificationUrgency.Critical;
            if (root.dnd && !critical) {
                n.dismiss();
                return;
            }
            n.tracked = true;
            n.closed.connect(() => root.remove(n));
            if (Config.theme.sounds)
                Quickshell.execDetached(["pw-play", critical ? Quickshell.shellPath("assets/sounds/notification-urgent.wav") : Config.notificationSoundPath(Config.theme.notificationSound)]);
            root.queue = [n].concat(root.queue);
        }
    }
}
