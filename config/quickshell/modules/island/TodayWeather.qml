import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 0
    property real titleY: 0
    property real datesBaseline: 0
    Layout.alignment: Qt.AlignTop
    Layout.fillHeight: false
    Layout.preferredHeight: Math.max(implicitHeight, datesBaseline + city.height - city.baselineOffset)

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Tr.dates
    function week(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
    }
    readonly property var w: Weather.known ? Weather.describe(Weather.now.code, Weather.now.day) : null

    Label {
        Layout.topMargin: root.titleY
        overline: true
        color: Theme.accentInk
        font.pixelSize: Theme.fontSizeSmall
        text: root.en.toString(clock.date, "dddd")
    }
    Label {
        font.pixelSize: Math.round(Theme.fontSize * 2.9)
        font.weight: Font.Light
        mono: true
        text: clock.date.getDate()
    }
    Caption { text: Tr.f("{0} · Week {1}", root.en.toString(clock.date, "MMMM"), root.week(clock.date)) }

    readonly property date born: /^\d{4}-\d{2}-\d{2}$/.test(Config.life.birthday) ? new Date(Config.life.birthday + "T00:00:00") : new Date(NaN)
    readonly property bool mori: !isNaN(born.getTime())
    readonly property date end: mori ? new Date(born.getFullYear() + Config.life.years, born.getMonth(), born.getDate()) : new Date(NaN)
    readonly property int weeksLeft: mori ? Math.max(0, Math.floor((end - clock.date) / 604800000)) : 0
    readonly property real lived: mori ? Math.max(0, Math.min(1, (clock.date - born) / (end - born))) : 0
    ColumnLayout {
        visible: root.mori
        Layout.topMargin: Theme.space4
        Layout.fillWidth: true
        spacing: Theme.space4
        Meter {
            Layout.fillWidth: true
            Layout.rightMargin: Theme.space8
            implicitHeight: Math.round(Theme.fontSizeSmall / 2)
            count: 16
            value: root.lived
        }
        Label { mono: true; color: Theme.subtext0; font.pixelSize: Theme.fontSizeSmall; text: root.weeksLeft.toLocaleString(Qt.locale("en_US"), "f", 0) + Tr.t(" weeks left") }
    }

    Item { Layout.fillHeight: true }

    RowLayout {
        visible: Weather.loading
        Layout.fillWidth: true
        spacing: Theme.space8
        Spinner { size: 14 }
        Caption { Layout.fillWidth: true; wrapMode: Text.Wrap; text: Tr.t("Getting the weather…") }
    }
    // Laid out like the weather itself, so the corner keeps its shape when there's none.
    readonly property bool unavailable: Weather.enabled && Weather.failed && root.w === null
    RowLayout {
        visible: root.unavailable
        spacing: Theme.space8
        Icon { name: "cloud-off"; size: Theme.fontSizeHeading; stroke: 1.6; color: Theme.accentInk }
        Label { font.pixelSize: Theme.fontSizeTitle; font.weight: Font.Light; mono: true; text: "--°" }
    }
    Label {
        visible: root.unavailable
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font.weight: Font.DemiBold
        font.pixelSize: Theme.fontSizeLabel
        text: Tr.t("Weather isn't available")
    }
    // Offline there's no looked-up city yet, so it's the one it asked for (the one typed in, or the time zone's).
    readonly property string tried: Weather.city || Weather.place
    Caption {
        visible: root.unavailable && root.tried !== ""
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: root.tried
        PressArea { label: root.tried; anchors.fill: parent; onClicked: { Panels.controlOpen = false; Panels.settingsRow("time", "Weather for"); } }
    }
    RowLayout {
        visible: root.w !== null
        spacing: Theme.space8
        Icon { name: root.w?.icon ?? "sun"; size: Theme.fontSizeHeading; stroke: 1.6; color: Theme.accentInk }
        Label { font.pixelSize: Theme.fontSizeTitle; font.weight: Font.Light; mono: true; text: (Weather.now?.temp ?? "") + "°" }
    }
    Label {
        visible: root.w !== null
        Layout.fillWidth: true
        elide: Text.ElideRight
        font.weight: Font.DemiBold
        font.pixelSize: Theme.fontSizeLabel
        text: root.w?.text ?? ""
    }
    Caption {
        visible: root.w !== null
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: "↑" + (Weather.now?.max ?? "") + "°  ↓" + (Weather.now?.min ?? "") + "°"
    }
    Caption {
        id: city
        visible: root.w !== null
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: Weather.city
        PressArea { label: Weather.city; anchors.fill: parent; onClicked: { Panels.controlOpen = false; Panels.settingsRow("time", "Weather for"); } }
    }
}
