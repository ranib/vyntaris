.pragma library

const names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];

function style(params, s) {
    const p = params === "" ? [0] : params.split(";").map(n => parseInt(n) || 0);
    for (let i = 0; i < p.length; i++) {
        const n = p[i];
        if (n === 0) s = { fg: "", bold: false };
        else if (n === 1) s = { fg: s.fg, bold: true };
        else if (n === 22) s = { fg: s.fg, bold: false };
        else if (n === 39) s = { fg: "", bold: s.bold };
        else if (n >= 30 && n <= 37) s = { fg: names[n - 30], bold: s.bold };
        else if (n >= 90 && n <= 97) s = { fg: names[n - 90], bold: s.bold };
        else if (n === 38 && p[i + 1] === 5) { s = { fg: p[i + 2] >= 232 ? "dim" : "", bold: s.bold }; i += 2; }
    }
    return s;
}

function screen(raw, rows) {
    const lines = [[]];
    let row = 0, col = 0, s = { fg: "", bold: false };
    const blank = { c: " ", s: { fg: "", bold: false } };
    const go = r => { row = Math.max(0, r); while (lines.length <= row) lines.push([]); };
    for (let i = 0; i < raw.length; i++) {
        const ch = raw[i];
        if (ch === "\x1b") {
            const m = /^\x1b\[([0-9;?]*)([A-Za-z])/.exec(raw.substr(i, 24));
            if (!m) { i += /^\x1b\[?[0-9;?]*/.exec(raw.substr(i, 24))[0].length - 1; continue; }
            i += m[0].length - 1;
            const n = parseInt(m[1]) || 1;
            switch (m[2]) {
            case "m": s = style(m[1], s); break;
            case "A": go(row - n); break;
            case "B": go(row + n); break;
            case "F": go(row - n); col = 0; break;
            case "E": go(row + n); col = 0; break;
            case "G": col = n - 1; break;
            case "K": lines[row].length = Math.min(lines[row].length, col); break;
            }
        } else if (ch === "\r") col = 0;
        else if (ch === "\n") { go(row + 1); col = 0; }
        else if (ch === "\b") col = Math.max(0, col - 1);
        else if (ch >= " ") {
            const l = lines[row];
            while (l.length < col) l.push(blank);
            l[col] = { c: ch, s };
            col++;
        }
    }
    const runs = lines.map(l => {
        let end = l.length;
        while (end > 0 && l[end - 1].c === " ") end--;
        const out = [];
        for (let i = 0; i < end; i++) {
            const last = out[out.length - 1];
            if (last && last.fg === l[i].s.fg && last.bold === l[i].s.bold) last.text += l[i].c;
            else out.push({ text: l[i].c, fg: l[i].s.fg, bold: l[i].s.bold });
        }
        return out;
    });
    while (runs.length > 0 && runs[runs.length - 1].length === 0) runs.pop();
    return runs.slice(-rows);
}

function text(rows) {
    return rows.map(r => r.map(run => run.text).join("")).join("\n");
}

function html(row, colours) {
    return row.map(run => {
        const t = run.text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;");
        const c = colours[run.fg];
        const coloured = c ? `<font color="${c}">${t}</font>` : t;
        return run.bold ? `<b>${coloured}</b>` : coloured;
    }).join("");
}

function slice(row, from, to) {
    const out = [];
    let at = 0;
    for (const run of row) {
        const a = Math.max(from, at), b = Math.min(to, at + run.text.length);
        if (a < b) out.push({ text: run.text.slice(a - at, b - at), fg: run.fg, bold: run.bold });
        at += run.text.length;
    }
    return out;
}

function split(row) {
    const plain = row.map(run => run.text).join("");
    const m = /\s+(\[[^\]]*\]\s+\d+%)$/.exec(plain);
    if (!m) return { left: row, right: [] };
    return { left: slice(row, 0, m.index), right: slice(row, plain.length - m[1].length, plain.length) };
}

function candy(right, cells) {
    const plain = right.map(run => run.text).join("");
    const m = /^\[([^\]]*)\]\s+(\d+)%$/.exec(plain);
    if (!m) return right;
    const percent = Math.min(100, parseInt(m[2]));
    const mouth = m[1].includes("c") ? "c" : "C";
    const label = " " + (percent + "%").padStart(4, " ");
    const width = Math.max(4, cells - 2 - label.length);
    const eaten = Math.floor(width * percent / 100);
    const runs = [{ text: "[" + "-".repeat(eaten), fg: "", bold: false }];
    if (eaten < width) {
        runs.push({ text: mouth, fg: "yellow", bold: true });
        let dots = "";
        for (let i = eaten + 1; i < width; i++) dots += i % 3 === 0 ? "o" : " ";
        runs.push({ text: dots, fg: "white", bold: false });
    }
    runs.push({ text: "]" + label, fg: "", bold: false });
    return runs;
}
