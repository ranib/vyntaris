import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import qs.config
import qs.components
import qs.services

Scope {
    id: root

    readonly property string user: Quickshell.env("USER") || ""
    property string status: ""
    property string pending: ""
    property string previewStatus: ""

    function tryUnlock(pw) {
        if (status === "checking" || !pw) return;
        pending = pw;
        status = "checking";
        pam.start();
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellPath("assets/pam.d")
        config: "password"
        user: root.user
        onPamMessage: {
            if (responseRequired) { respond(root.pending); root.pending = ""; }
            else if (messageIsError) root.status = message;
        }
        onCompleted: result => {
            root.pending = "";
            if (result === PamResult.Success) { root.status = ""; LockState.unlocked(); }
            else root.status = "wrong";
        }
        onError: error => { root.pending = ""; root.status = PamError.toString(error); }
    }

    component Face: LockFace {
        anchors.fill: parent
        user: root.user
        fullName: Accounts.self.full
        face: Accounts.hasFace ? Accounts.face : ""
        faceVersion: Accounts.faceVersion
        wallpaper: Config.wallpaperFile()
        title: Tr.t("Locked")
        layoutCode: Keyboard.multiple ? Keyboard.code : ""
        battery: Battery.available ? Battery.percent : -1
        charging: Battery.charging && !Battery.full
        onLayoutClicked: Keyboard.next()
    }
    component Widgets: LockWidgets {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.space36 }
    }

    Variants {
        model: LockState.preview ? [Monitors.focused ?? Quickshell.screens[0]] : []
        PanelWindow {
            required property var modelData
            screen: Quickshell.screens.find(s => s.name === modelData?.name) ?? Quickshell.screens[0]
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            Face {
                status: root.previewStatus
                onSubmit: pw => { root.previewStatus = "checking"; previewCheck.restart(); }
                Keys.onEscapePressed: LockState.preview = false
            }
            Widgets {}
        }
    }
    Timer { id: previewCheck; interval: 900; onTriggered: root.previewStatus = "wrong" }

    WlSessionLock {
        locked: LockState.locked

        WlSessionLockSurface {
            id: surface
            readonly property bool primary: screen?.name === (Monitors.focused?.name ?? Quickshell.screens[0]?.name)
            color: Theme.crust

            // The compositor drops the keyboard and mouse over a sleep and hands the keyboard back to
            // what's under the pointer only when the pointer moves, so it's moved onto where it is.
            Timer {
                id: regain
                property int tries: 0
                interval: 400
                repeat: true
                onTriggered: {
                    if (!LockState.locked || !surface.primary || (tries > 1 && face.windowActive) || tries >= 8) { stop(); return; }
                    tries++;
                    face.takeFocus();
                    Quickshell.execDetached(["sh", "-c", 'set -- $(hyprctl cursorpos | tr -d ,); hyprctl dispatch "hl.dsp.cursor.move({ x = $1, y = $2 })"']);
                }
            }
            Connections {
                target: LockState
                function onWoke() { regain.tries = 0; regain.restart(); }
            }

            Face {
                id: face
                visible: surface.primary
                active: surface.primary
                status: root.status
                onSubmit: pw => root.tryUnlock(pw)
            }
            Item {
                anchors.fill: parent
                visible: surface.primary
                Widgets {}
            }
        }
    }
}
