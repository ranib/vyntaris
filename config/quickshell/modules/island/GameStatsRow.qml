import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

RowLayout {
    id: row
    spacing: Theme.space10

    function hot(t) { return t >= 90 ? Theme.error : t >= 80 ? Theme.warning : Theme.text; }

    Icon { name: "gamepad"; size: 15; color: Theme.accentInk }
    RowLayout {
        visible: Games.fps >= 0
        spacing: Theme.space4
        Label { mono: true; font.weight: Font.Bold; font.features: { "tnum": 1 }; text: Games.fps }
        Caption { text: Tr.t("FPS") }
    }
    Rectangle { visible: Games.fps >= 0 && (Games.cpuTemp >= 0 || Games.gpuTemp >= 0); implicitWidth: 1; implicitHeight: 12; color: Theme.hairlineOn(parent) }
    RowLayout {
        visible: Games.cpuTemp >= 0
        spacing: Theme.space4
        Caption { text: Tr.t("CPU") }
        Label { mono: true; font.features: { "tnum": 1 }; color: row.hot(Games.cpuTemp); text: Games.cpuTemp + "°" }
    }
    RowLayout {
        visible: Games.gpuTemp >= 0
        spacing: Theme.space4
        Caption { text: Tr.t("GPU") }
        Label { mono: true; font.features: { "tnum": 1 }; color: row.hot(Games.gpuTemp); text: Games.gpuTemp + "°" }
    }
    Label {
        visible: Games.gpuLoad >= 0
        mono: true
        font.features: { "tnum": 1 }
        color: Theme.overlay1
        text: Games.gpuLoad + "%"
    }
}
