pragma Singleton
import Quickshell
import QtQuick
import "Palettes.js" as Palettes

Singleton {
    id: root

    readonly property var basePalette: Palettes.palettes[Config.theme.flavor] ?? Palettes.palettes.mocha
    readonly property var palette: basePalette
    readonly property bool isDark: Config.theme.flavor !== "latte"
    readonly property var bootPalette: isDark ? basePalette : Palettes.palettes.mocha

    readonly property color rosewater: palette.rosewater
    readonly property color flamingo:  palette.flamingo
    readonly property color pink:      palette.pink
    readonly property color mauve:     palette.mauve
    readonly property color red:       palette.red
    readonly property color maroon:    palette.maroon
    readonly property color peach:     palette.peach
    readonly property color yellow:    palette.yellow
    readonly property color green:     palette.green
    readonly property color teal:      palette.teal
    readonly property color sky:       palette.sky
    readonly property color sapphire:  palette.sapphire
    readonly property color blue:      palette.blue
    readonly property color lavender:  palette.lavender
    readonly property color text:      highContrast ? ink(palette.text) : palette.text
    readonly property bool highContrast: Config.accessibility.highContrast
    // The hardest background text meets: a tile on the panel it sits on.
    readonly property string worstSurface: Palettes.mix(isDark ? palette.base : palette.crust, palette.text, 0.06)
    readonly property string strongest: isDark ? "#ffffff" : "#000000"
    readonly property real textRatio: highContrast ? 7 : 4.5
    function ink(c) {
        if (!isDark) return Palettes.deepen(String(c), worstSurface, textRatio);
        return Palettes.ensure(String(c), worstSurface, textRatio, highContrast ? strongest : palette.text);
    }
    readonly property color subtext1:  highContrast ? ink(palette.text) : ink(palette.subtext1)
    readonly property color subtext0:  highContrast ? ink(palette.text) : ink(palette.subtext0)
    readonly property color overlay2:  ink(highContrast ? palette.subtext1 : palette.overlay2)
    readonly property color overlay1:  ink(highContrast ? palette.subtext0 : palette.overlay1)
    readonly property color overlay0:  ink(highContrast ? palette.subtext0 : palette.overlay0)
    // What a control's own edge is drawn in, where the edge is how it's seen.
    readonly property color controlEdge: Palettes.ensure(palette.overlay0, worstSurface, highContrast ? 4.5 : 3, highContrast ? strongest : palette.text)
    readonly property color surface2:  palette.surface2
    readonly property color surface1:  palette.surface1
    readonly property color surface0:  palette.surface0
    readonly property color base:      palette.base
    readonly property color mantle:    palette.mantle
    readonly property color crust:     palette.crust

    readonly property string accentName: isDark ? Config.theme.accent : Config.theme.accentLight
    readonly property color accent:   Palettes.settled(Palettes.accent(palette, accentName))
    readonly property string accentNearest: Palettes.nearest(palette, accentName)
    function accentIn(pal) { return Palettes.accent(pal, accentName); }
    function colorOf(name) { return Palettes.accent(palette, name); }
    function accentLabel(name) {
        const names = { pink: Tr.t("Pink"), mauve: Tr.t("Mauve"), red: Tr.t("Red"), peach: Tr.t("Peach"),
                        yellow: Tr.t("Yellow"), green: Tr.t("Green"), sky: Tr.t("Sky"), blue: Tr.t("Blue") };
        return names[name] ?? Tr.t("Custom");
    }
    readonly property color accentInk: ink(accent)
    // The empty part of a slider: on white it stays quieter than the filled part, whose end shows the value.
    readonly property color trackOff: isDark || highContrast ? controlEdge : palette.surface1
    readonly property color trackOffHover: isDark || highContrast ? overlay1 : palette.surface2
    // Text right on a picture isn't on the theme's surfaces, so it doesn't follow them.
    readonly property color onWallpaper: "#ffffff"
    readonly property color wallpaperVeil: isDark ? alpha(base, 0.32) : alpha("#000000", 0.22)
    function on(fill) { return Palettes.readableOn(String(fill), palette.base, Palettes.palettes.mocha.crust); }
    readonly property color textOnAccent: on(accent)
    readonly property color accentBright: isDark ? Qt.lighter(accent, 1.18) : accentInk
    readonly property color success:  ink(palette.green)
    readonly property color error:    ink(palette.red)
    readonly property color warning:  ink(palette.peach)

    // Dark panels sink below the windows; light ones lift above them.
    readonly property color glassTint:  isDark ? crust : base
    readonly property color glass:      glassTint
    readonly property color glassTop:   glassTint
    // Only solid colours: a tint is worked out over what's under it instead of drawn see-through.
    // These are over the panels' glass; rimOn(), hairlineOn(), hoverOn() and edgeOn() are over whatever is under an item.
    readonly property real rimAmount: highContrast ? 0.45 : isDark ? 0.14 : 0.16
    readonly property real hairlineAmount: highContrast ? 0.3 : isDark ? 0.08 : 0.12
    readonly property real hoverAmount: isDark ? 0.06 : 0.08
    readonly property color glassRim:   tint(null, text, rimAmount)
    readonly property color glassEdge:  isDark ? tint(null, "#ffffff", 0.24) : tint(null, text, 0.14)
    readonly property color hairline: tint(null, text, hairlineAmount)
    readonly property color hover:    tint(null, text, hoverAmount)

    // What's under an item: the nearest one (itself or above it) that paints solid, by its `ground` (surfaces whose
    // fill is drawn elsewhere, like slanted ones) or its colour as a Rectangle; else its window's colour; else the glass.
    function groundOf(item) {
        for (let p = item; p; p = p.parent) {
            const g = p.ground !== undefined ? p.ground : p.radius !== undefined && p.visible ? p.color : undefined;
            if (g !== undefined && g !== null && g.a === 1) return g;
        }
        const c = item?.Window?.window?.color;
        return c && c.a === 1 ? c : glassTint;
    }
    function hex6(c) {
        const s = String(c);
        return s.length === 9 ? "#" + s.slice(3) : s;
    }
    // `c` at strength `a` over what's under `item`, as one solid colour.
    function tint(item, c, a) {
        return Palettes.mix(hex6(groundOf(item)), hex6(c), Math.max(0, Math.min(1, a)));
    }
    function rimOn(item) { return tint(item, text, rimAmount); }
    function hairlineOn(item) { return tint(item, text, hairlineAmount); }
    function hoverOn(item) { return tint(item, text, hoverAmount); }
    function edgeOn(item) { return isDark ? tint(item, "#ffffff", 0.24) : tint(item, text, 0.14); }

    // See-through, for what has to show what's behind it: shadows, and veils over a picture or the screen.
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    readonly property string fontFamily: Config.theme.fontFamily || Qt.application.font.family
    readonly property string monoFamily: Config.theme.monoFamily || "monospace"
    readonly property int fontSize: Config.theme.fontSize
    readonly property int fontSizeSmall: Math.max(11, fontSize - 2)
    readonly property int fontSizeLabel: Math.max(12, fontSize - 1)
    readonly property int fontSizeMedium: fontSize + 1
    readonly property int fontSizeLarge: fontSize + 3
    readonly property int fontSizeTitle: fontSize + 5
    readonly property int fontSizeHeading: fontSize + 7
    readonly property int fontSizeDisplay: fontSize + 13
    readonly property int fontSizeHero: fontSize + 21

    readonly property int radius: 10

    readonly property int space2: 2
    readonly property int space4: 4
    readonly property int space6: 6
    readonly property int space8: 8
    readonly property int space10: 10
    readonly property int space12: 12
    readonly property int space14: 14
    readonly property int space16: 16
    readonly property int space20: 20
    readonly property int space24: 24
    readonly property int space32: 32
    readonly property int space36: 36

    readonly property real disabledOpacity: 0.5

    // Every side menu in the system, the Store's too (rust/ui/src/style.css): the part you click is this big.
    readonly property int navItemWidth: 208
    readonly property int navItemHeight: controlHeight
    readonly property int navItemGap: space4
    readonly property int navInset: space12
    readonly property int navWidth: navItemWidth + 2 * navInset
    readonly property int navRadius: r(12)

    readonly property int barHeight: Config.bar.height
    // Buttons, fields and choices stand side by side, so all of them are this tall.
    readonly property int controlHeight: 36
    readonly property int panelTop: barHeight + 6
    readonly property int panelInset: 20
    readonly property bool squareBar: Config.bar.corners === "square"
    readonly property bool slanted: Config.bar.notchStyle === "slant"
    readonly property real islandCurves: Config.bar.inside === "sharp" ? 0 : Config.bar.inside === "soft" ? 0.5 : 1
    readonly property int shoulder: squareBar ? 0 : Math.round(16 * islandCurves)

    readonly property int notchWidth: 186
    readonly property int notchDepth: Config.bar.flatIsland ? 0 : 11
    readonly property int screenCorner: squareBar || Config.bar.endCorners === false ? 0 : Math.max(0, Config.bar.endCurve)
    readonly property int notchCorner: squareBar ? 0 : 4
    readonly property real shapeRoundness: squareBar ? 0 : Config.bar.endCurve >= 16 ? 1 : Config.bar.endCurve >= 10 ? 0.7 : 0.3
    readonly property int drawerRadius: squareBar ? 0 : Math.round(24 * shapeRoundness * islandCurves)
    readonly property real roundness: Config.bar.inside === "sharp" ? 0 : Config.bar.inside === "soft" ? Math.min(shapeRoundness, 0.5) : shapeRoundness
    function r(n) {
        return Math.round(n * roundness);
    }

    readonly property string animStyle: Config.theme.animationStyle
    readonly property bool calm: animStyle === "smooth" || animStyle === "snappy"
    readonly property real speed: Config.theme.animationSpeed * (animStyle === "snappy" ? 1.45 : 1)
    function duration(ms) {
        return speed > 0 ? Math.round(ms / speed) : 0;
    }
    // A shake or a flash has its own pace: not rushed by the speed, gone with the animations off.
    function paced(ms) { return speed > 0 ? ms : 0; }
    readonly property int durationFast:   duration(140)
    readonly property int durationNormal: duration(260)
    readonly property int durationSlow:   duration(420)

    readonly property var curveStandard:   [0.2, 0, 0, 1, 1, 1]
    readonly property var curveDecelerate: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var curveSpring: animStyle === "snappy" ? [0.2, 1, 0.3, 1, 1, 1]
        : calm ? [0.25, 0.8, 0.25, 1, 1, 1] : [0.34, 1.32, 0.64, 1, 1, 1]

    readonly property int durationPanelIn: calm ? duration(340) : duration(500)
    readonly property int durationPanelOut: duration(260)
    readonly property int durationContentDelay: duration(90)
    readonly property int durationContentOut: duration(80)
    readonly property var curvePanelIn: animStyle === "snappy" ? [0.2, 1, 0.3, 1, 1, 1]
        : calm ? [0.25, 0.8, 0.25, 1, 1, 1]
        : [0.0417, 0, 0.0833, 0.1433, 0.125, 0.2843, 0.1667, 0.4254, 0.2083, 0.5694, 0.25, 0.6788, 0.2917, 0.7882, 0.3333, 0.8664, 0.375, 0.9183, 0.4167, 0.9702, 0.4583, 0.9971, 0.5, 1.0118, 0.5417, 1.0264, 0.5833, 1.029, 0.625, 1.0283, 0.6667, 1.0275, 0.7083, 1.0232, 0.75, 1.0192, 0.7917, 1.0151, 0.8333, 1.0112, 0.875, 1.0083, 0.9167, 1.0053, 0.9583, 1.0013, 1, 1]
    readonly property var curvePanelOut: [0.3, 0, 0.2, 1, 1, 1]
}
