.pragma library

// The motion styles beyond Vyntaris's own three (bouncy, smooth, snappy), one table for both sides: Hyprland reads it
// (config/hypr/lib/motion.lua) for windows, workspaces and layers, and Theme.qml for the shell's panels and island.
// Their names and what they're like are in Settings (AppearancePage.qml), to be translated.
// Curves are cubic beziers [x1, y1, x2, y2]: main (fades, the shell), open, close, move (windows dragged or tiled),
// workspace. speed scales Vyntaris's own durations (more is quicker). windows and workspaces are how windows open
// and workspaces switch with it. Keep each preset on one line: the Lua side reads them with patterns, not JSON.
var presets = {
    classic:  { main: [0.05, 0.9, 0.1, 1.05],  open: [0.05, 0.9, 0.1, 1.05], close: [0.3, 0, 0.8, 0.15],  move: [0.05, 0.9, 0.1, 1.05],  workspace: [0.05, 0.9, 0.1, 1.05], speed: 0.9,  windows: "popin",     workspaces: "slide" },
    glide:    { main: [0.05, 0.9, 0.1, 1.05],  open: [0.1, 1.1, 0.1, 1.1],   close: [0.3, -0.3, 0, 1],    move: [0.05, 0.9, 0.1, 1.05],  workspace: [0.05, 0.9, 0.1, 1.05], speed: 0.9,  windows: "slide",     workspaces: "slide" },
    brisk:    { main: [0.05, 0.7, 0.1, 1],     open: [0.05, 0.7, 0.1, 1],    close: [0.3, 0, 0.8, 0.15],  move: [0.05, 0.7, 0.1, 1],     workspace: [0.16, 1, 0.3, 1],      speed: 1.35, windows: "popin",     workspaces: "slide" },
    material: { main: [0.05, 0.7, 0.1, 1], open: [0.05, 0.7, 0.1, 1],    close: [0.3, 0, 0.8, 0.15],  move: [0.2, 0, 0, 1],          workspace: [0.1, 1, 0, 1],         speed: 1.2,  windows: "popin",     workspaces: "slide" },
    drift:    { main: [0.05, 0.9, 0.1, 1.05], open: [0.5, 0, 0.99, 0.99], close: [0.5, 0, 0.99, 0.99], move: [0.5, -0.5, 0.68, 1.5], workspace: [0.25, 0.1, 0.25, 1],  speed: 1,    windows: "slide",     workspaces: "slide" },
    spring:   { main: [0.05, 0.9, 0.1, 1.05],  open: [0.13, 0.99, 0.29, 1.08], close: [0.13, 0.99, 0.29, 1.08], move: [0.13, 0.99, 0.29, 1.08], workspace: [0.13, 0.99, 0.29, 1.08], speed: 0.85, windows: "popin", workspaces: "slide" },
    lift:     { main: [0, 0.2, 0.4, 1],        open: [0.37, 0, 0.63, 1],     close: [0.33, 1, 0.68, 1],   move: [0.37, 0, 0.63, 1],      workspace: [0, 0.2, 0.4, 1],       speed: 1.4,  windows: "popin",     workspaces: "slidevert" },
    calm:     { main: [0.25, 1, 0.5, 1],       open: [0.25, 1, 0.5, 1],      close: [0.25, 1, 0.5, 1],    move: [0.25, 1, 0.5, 1],       workspace: [0.25, 1, 0.5, 1],      speed: 1,    windows: "slide",     workspaces: "slide" },
    tight:    { main: [0.05, 0.8, 0.1, 0.97],  open: [0.07, 0.88, 0.04, 0.99], close: [0.2, -0.15, 0, 1], move: [0.05, 0.85, 0.03, 0.97], workspace: [0.05, 0.82, 0, 1],     speed: 1.15, windows: "slide",     workspaces: "slide" },
};
