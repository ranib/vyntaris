import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: root
    readonly property int fontCell: Math.round(Theme.fontSizeSmall * 3.5)
    readonly property int cell: width > 0 ? Math.max(Theme.fontSizeSmall * 2, Math.min(fontCell, Math.floor(width / 7))) : fontCell
    readonly property int rowHeight: Math.round(cell * 0.9)
    readonly property int mark: rowHeight - 4
    readonly property int arrow: Theme.fontSizeSmall * 2
    implicitWidth: fontCell * 7
    Layout.minimumWidth: Theme.fontSizeSmall * 2 * 7
    implicitHeight: body.implicitHeight

    readonly property real titleY: body.y + header.y + title.y
    readonly property real datesBaseline: body.y + grid.y + grid.height - rowHeight + (rowHeight - dayProbe.implicitHeight) / 2 + dayProbe.baselineOffset
    Label { id: dayProbe; visible: false; mono: true; font.pixelSize: Theme.fontSizeSmall; text: "0" }

    SystemClock { id: clock; precision: SystemClock.Hours }
    readonly property date today: new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate())
    property int year: today.getFullYear()
    property int month: today.getMonth()
    property date picked: today
    function reset() { year = today.getFullYear(); month = today.getMonth(); picked = today; }
    function step(d) {
        const m = month + d;
        year += Math.floor(m / 12);
        month = (m % 12 + 12) % 12;
    }
    readonly property var en: Tr.dates
    function same(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }

    readonly property var days: {
        const first = new Date(year, month, 1);
        const start = new Date(year, month, 1 - (first.getDay() + 6) % 7);
        const out = [];
        for (let i = 0; i < 42; i++) out.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
        return out;
    }

    ColumnLayout {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cell * 7
        spacing: Theme.space4

        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: Theme.space4
            Label {
                id: title
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space10
                overline: true
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.accentInk
                text: root.en.toString(new Date(root.year, root.month, 1), "MMMM yyyy")
                PressArea { label: Tr.t("Back to this month"); anchors.fill: parent; onClicked: root.reset() }
            }
            component Arrow: Rectangle {
                id: ar
                property string icon
                signal clicked()
                implicitWidth: root.arrow
                implicitHeight: root.arrow
                radius: root.arrow / 2
                color: arArea.containsMouse ? Theme.hoverOn(parent) : "transparent"
                Icon { anchors.centerIn: parent; name: ar.icon; size: Math.round(root.arrow * 0.55); color: Theme.subtext1 }
                PressArea { label: ar.icon === "chevron-left" ? Tr.t("Previous month") : Tr.t("Next month"); id: arArea; anchors.fill: parent; onClicked: ar.clicked() }
            }
            Arrow { icon: "chevron-left"; onClicked: root.step(-1) }
            Arrow { icon: "chevron-right"; onClicked: root.step(1) }
        }

        GridLayout {
            id: grid
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 0
            columnSpacing: 0
            Repeater {
                model: [1, 2, 3, 4, 5, 6, 0].map(i => Tr.dates.dayName(i, Locale.ShortFormat).slice(0, 2))
                Label {
                    required property string modelData
                    Layout.preferredWidth: root.cell
                    horizontalAlignment: Text.AlignHCenter
                    overline: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.overlay0
                    text: modelData
                }
            }
            Repeater {
                model: root.days
                Item {
                    id: day
                    required property var modelData
                    readonly property bool isToday: root.same(modelData, root.today)
                    readonly property bool isPicked: root.same(modelData, root.picked)
                    readonly property bool inMonth: modelData.getMonth() === root.month
                    Layout.preferredWidth: root.cell
                    implicitHeight: root.rowHeight
                    Rectangle {
                        anchors.centerIn: parent
                        width: root.mark
                        height: root.mark
                        radius: root.mark / 2
                        color: day.isPicked ? Theme.accent : dayArea.containsMouse ? Theme.hoverOn(parent) : "transparent"
                        border { width: day.isToday && !day.isPicked ? 1.5 : 0; color: Theme.accent }
                    }
                    Label {
                        anchors.centerIn: parent
                        mono: true
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: day.isToday || day.isPicked ? Font.Bold : Font.Normal
                        color: day.isPicked ? Theme.textOnAccent : day.isToday ? Theme.accentInk : day.inMonth ? Theme.text : Theme.overlay0
                        text: day.modelData.getDate()
                    }
                    MouseArea {
                        id: dayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.picked = day.modelData;
                            if (!day.inMonth) { root.year = day.modelData.getFullYear(); root.month = day.modelData.getMonth(); }
                        }
                    }
                }
            }
        }

        Caption {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space2
            visible: !root.same(root.picked, root.today)
            horizontalAlignment: Text.AlignHCenter
            text: {
                const d = Math.round((root.picked - root.today) / 86400000);
                const rel = d === 0 ? Tr.t("Today") : d === 1 ? Tr.t("Tomorrow") : d === -1 ? Tr.t("Yesterday")
                    : d > 0 ? Tr.f("In {0} days", d) : Tr.f("{0} days ago", -d);
                return root.en.toString(root.picked, "dddd, d MMMM yyyy") + " · " + rel;
            }
        }
    }
}
