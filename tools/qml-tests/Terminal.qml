import QtQuick
import "../../config/quickshell/services/Terminal.js" as Terminal

QtObject {
    property int fails: 0
    function is(what, raw, rows, want) {
        const got = Terminal.text(Terminal.screen(raw, rows));
        const ok = got === want;
        console.log((ok ? "   ok    " : "   FAIL  ") + what + (ok ? "" : ` → ${JSON.stringify(got)}, wanted ${JSON.stringify(want)}`));
        if (!ok) fails++;
    }

    Component.onCompleted: {
        is("plain lines", "one\r\ntwo\r\n", 8, "one\ntwo");
        is("keeps only the last rows", "a\nb\nc\nd\n", 2, "c\nd");
        is("a carriage return draws over the line", "10%\r55%\r", 8, "55%");
        is("a shorter redraw keeps the rest", "upgrading\rdone", 8, "doneading");
        is("erase to the end of the line", "upgrading\r\x1b[Kdone", 8, "done");
        is("colours are dropped", "\x1b[1;31merror:\x1b[0m nope\r\n", 8, "error: nope");
        is("the cursor is hidden and shown", "\x1b[?25lbar\x1b[?25h", 8, "bar");
        is("parallel bars redraw in place", "a 10%\nb 20%\n\x1b[2Fa 90%\x1b[Kx\n\x1b[1Eb 99%", 8, "a 90%x\nb 20%\nb 99%");
        is("up past the top stays on the first line", "x\x1b[5Fy", 8, "y");
        is("a sequence cut off at the end leaves nothing", "[---C\x1b[0;3", 8, "[---C");
        is("candy bar", "(1/2) upgrading foo  [-----c o o]  50%\r(1/2) upgrading foo  [---------C-]  99%\r\n", 8,
            "(1/2) upgrading foo  [---------C-]  99%");
        const coloured = Terminal.screen("\x1b[1;34m::\x1b[0;1m Retrieving\x1b[0m [\x1b[1;33mC\x1b[m\x1b[0;37m o\x1b[m]", 8)[0];
        const runs = coloured.map(r => `${r.fg}${r.bold ? "+" : ""}:${r.text}`).join("|");
        const want = "blue+:::|+: Retrieving|: [|yellow+:C|white: o|:]";
        if (runs !== want) { fails++; console.log(`   FAIL  colour runs → ${runs}, wanted ${want}`); }
        else console.log("   ok    colour runs");
        const shown = Terminal.html(coloured, { blue: "#0000ff", yellow: "#ffff00", white: "#cccccc" });
        const html = '<b><font color="#0000ff">::</font></b><b>&nbsp;Retrieving</b>&nbsp;[<b><font color="#ffff00">C</font></b><font color="#cccccc">&nbsp;o</font>]';
        if (shown !== html) { fails++; console.log(`   FAIL  html → ${shown}`); } else console.log("   ok    html keeps spaces and colours");
        const parts = Terminal.split(Terminal.screen("( 1/12) upgrading firefox      [\x1b[1;33mc\x1b[m o]  20%", 8)[0]);
        const lr = Terminal.text([parts.left]) + "|" + Terminal.text([parts.right]);
        if (lr !== "( 1/12) upgrading firefox|[c o]  20%") { fails++; console.log(`   FAIL  split → ${lr}`); }
        else console.log("   ok    the bar splits off to the right");
        const none = Terminal.split(Terminal.screen(":: Running hooks...", 8)[0]);
        if (none.right.length !== 0 || Terminal.text([none.left]) !== ":: Running hooks...") { fails++; console.log("   FAIL  a line without a bar stays whole"); }
        else console.log("   ok    a line without a bar stays whole");
        const long = Terminal.text([Terminal.candy(parts.right, 20)]);
        if (long !== "[--co  o  o  o]  20%") { fails++; console.log(`   FAIL  candy → ${JSON.stringify(long)}`); }
        else console.log("   ok    the bar is drawn again as wide as there's room");
        const full = Terminal.text([Terminal.candy(Terminal.screen("[-----] 100%", 8)[0], 14)]);
        if (full !== "[-------] 100%") { fails++; console.log(`   FAIL  full candy → ${JSON.stringify(full)}`); }
        else console.log("   ok    a full bar has no Pac-Man left");
        console.log(fails === 0 ? "terminal: all pass" : `terminal: ${fails} failed`);
        Qt.exit(fails === 0 ? 0 : 1);
    }
}
