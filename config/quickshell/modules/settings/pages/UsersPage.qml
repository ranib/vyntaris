import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

SettingsPage {
    id: page
    pageId: "users"

    onVisibleChanged: if (visible) Accounts.refresh()

    Label {
        visible: Accounts.failure !== ""
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.error
        text: Accounts.failure
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space14
        Avatar { size: 56; name: Accounts.self.full; source: Accounts.hasFace ? Accounts.face : ""; version: Accounts.faceVersion }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space2
            Label { font.pixelSize: Theme.fontSizeLarge; font.weight: Font.DemiBold; text: Accounts.self.full }
            Caption { text: Accounts.self.name + (Accounts.self.admin ? Tr.t(" · administrator") : "") }
        }
    }

    SettingsRow {
        title: Tr.t("Name")
        Field {
            implicitWidth: 240
            text: Accounts.self.full
            onCommitted: t => { if (t.trim() && t.trim() !== Accounts.self.full) Accounts.setName(Accounts.self.name, t.trim()); }
        }
    }
    SettingsRow {
        title: Tr.t("Picture")
        RowLayout {
            spacing: Theme.space8
            Button { text: picking.visible ? Tr.t("Done") : Tr.t("Choose"); onClicked: { picking.visible = !picking.visible; if (picking.visible) Accounts.findPictures(); } }
            Button { visible: Accounts.hasFace; text: Tr.t("Remove"); onClicked: Accounts.clearFace() }
        }
    }
    Flow {
        id: picking
        Layout.fillWidth: true
        visible: false
        spacing: Theme.space8
        Label { visible: Accounts.pictures.length === 0; color: Theme.overlay1; text: Tr.t("No pictures in Pictures yet") }
        Repeater {
            model: Accounts.pictures
            Avatar {
                id: choice
                required property string modelData
                size: 64
                source: modelData
                scale: pickArea.pressed ? 0.94 : pickArea.containsMouse ? 1.06 : 1
                Behavior on scale { Anim { duration: Theme.durationFast; easing.bezierCurve: Theme.curveSpring } }
                PressArea {
                    label: Tr.t("Use this picture")
                    id: pickArea
                    anchors.fill: parent
                    onClicked: { Accounts.setFace(choice.modelData); picking.visible = false; }
                }
            }
        }
    }
    SettingsRow {
        title: Tr.t("Password")
        Button { text: passwordBox.visible ? Tr.t("Cancel") : Tr.t("Change"); onClicked: { passwordBox.visible = !passwordBox.visible; currentPw.text = ""; newPw.text = ""; againPw.text = ""; } }
    }
    RowLayout {
        id: passwordBox
        Layout.fillWidth: true
        visible: false
        spacing: Theme.space8
        Field { id: currentPw; Layout.fillWidth: true; secret: true; canReveal: true; placeholder: Tr.t("Current password") }
        Field { id: newPw; Layout.fillWidth: true; secret: true; canReveal: true; placeholder: Tr.t("New password") }
        Field { id: againPw; Layout.fillWidth: true; secret: true; canReveal: true; placeholder: Tr.t("Once more") }
        Button {
            primary: true
            text: Tr.t("Save")
            active: currentPw.text !== "" && newPw.text.length >= 4 && newPw.text === againPw.text && !Accounts.busy
            onClicked: { Accounts.setOwnPassword(currentPw.text, newPw.text); passwordBox.visible = false; currentPw.text = ""; newPw.text = ""; againPw.text = ""; }
        }
    }
    Label {
        visible: passwordBox.visible && newPw.text !== "" && (newPw.text.length < 4 || (againPw.text !== "" && newPw.text !== againPw.text))
        color: Theme.warning
        text: newPw.text.length < 4 ? Tr.t("4 characters at least") : Tr.t("The two aren't the same")
    }

    SettingsSection { text: Accounts.others.length ? Tr.t("Other people") : Tr.t("Other people · none") }
    Repeater {
        model: Accounts.others
        RowLayout {
            id: other
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.space12
            Avatar { name: other.modelData.full }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space2
                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.DemiBold; text: other.modelData.full }
                Caption { text: other.modelData.name }
            }
            Caption { text: Tr.t("Administrator") }
            Switch { checked: other.modelData.admin; onToggled: on => Accounts.setAdmin(other.modelData.name, on) }
            Button {
                id: removeButton
                property bool asking: false
                danger: asking
                text: asking ? Tr.t("Remove (files stay)") : Tr.t("Remove")
                onClicked: {
                    if (!asking) { asking = true; stopAsking.restart(); return; }
                    asking = false;
                    Accounts.remove(other.modelData.name);
                }
                Timer { id: stopAsking; interval: 5000; onTriggered: removeButton.asking = false }
            }
        }
    }

    SettingsSection { text: Tr.t("Add someone") }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space8
        Field {
            id: newFull
            Layout.fillWidth: true
            placeholder: Tr.t("Full name")
            onTextChanged: if (!newName.edited) newName.text = Accounts.nameFor(text)
        }
        Field {
            id: newName
            property bool edited: false
            implicitWidth: 150
            mono: true
            placeholder: Tr.t("user name")
            input.onTextEdited: edited = true
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space8
        Field { id: newPass; Layout.fillWidth: true; secret: true; canReveal: true; placeholder: Tr.t("Password") }
        Caption { text: Tr.t("Administrator") }
        Switch { id: newAdmin }
        Button {
            primary: true
            icon: "plus"
            text: Tr.t("Add")
            active: newFull.text.trim() !== "" && /^[a-z_][a-z0-9_-]{0,31}$/.test(newName.text) && newPass.text.length >= 4 && !Accounts.busy
            onClicked: {
                Accounts.add(newName.text, newFull.text.trim(), newAdmin.checked, newPass.text);
                newFull.text = ""; newName.text = ""; newName.edited = false; newPass.text = ""; newAdmin.checked = false;
            }
        }
    }
}
