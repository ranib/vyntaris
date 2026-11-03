hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0 } })

local settings = require("lib.settings").load()
local palettes = require("lib.palettes")

local function tell(title, body, value)
    local q = function (t) return "'" .. tostring(t):gsub("'", "'\\''") .. "'" end
    hl.exec_cmd("T() { /usr/lib/vyntaris/json tr \"$@\" 2>/dev/null || printf '%s' \"$1\"; }; "
        .. "for i in $(seq 30); do notify-send -a Vyntaris -i dialog-warning \"$(T " .. q(title) .. ")\" "
        .. "\"$(T " .. q(body) .. " " .. q(value or "") .. ")\" 2>/dev/null && break; sleep 1; done")
end

if os.getenv("VYNTARIS_RECOVERED") then
    hl.on("hyprland.start", function ()
        tell("The desktop restarted", "Something went wrong and it had to start again. Your files are as they were; open apps need opening again.")
    end)
end

local palette = palettes[settings.theme.flavor] or palettes.mocha
local accentName = settings.theme.flavor == "latte" and settings.theme.accentLight or settings.theme.accent
local accent  = require("lib.colors").accent(palette, accentName)

local animSpeed = tonumber(settings.theme.animationSpeed) or 1

local function rgba(hex)
    return "rgba(" .. hex .. "ff)"
end
-- Only solid colours: `b` at strength `t` over `a`, as one colour (both rrggbb).
local function mix(a, b, t)
    local out = ""
    for i = 1, 5, 2 do
        local x, y = tonumber(a:sub(i, i + 1), 16), tonumber(b:sub(i, i + 1), 16)
        out = out .. string.format("%02x", math.floor(x + (y - x) * t + 0.5))
    end
    return out
end

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = settings.display.scale,
})

for _, m in ipairs(settings.display.monitors or {}) do
    if m.name and m.name ~= "" then
        hl.monitor({
            output   = m.name,
            mode     = m.mode or "preferred",
            position = m.position or "auto",
            scale    = m.scale or settings.display.scale,
        })
    end
end

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})

local exported = { "WAYLAND_DISPLAY", "DISPLAY", "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "HYPRLAND_INSTANCE_SIGNATURE" }
function env(name, value)
    hl.env(name, value)
    exported[#exported + 1] = name
end

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd " .. table.concat(exported, " ")
        .. " && systemctl --user start vyntaris-session.target")
end)
hl.on("hyprland.shutdown", function ()
    hl.exec_cmd("systemctl --user stop vyntaris-session.target")
end)

local igpuOnly = require("lib.gpu").igpuOnly()
if igpuOnly then
    env("AQ_DRM_DEVICES", igpuOnly)
    env("__EGL_VENDOR_LIBRARY_FILENAMES", "/usr/share/glvnd/egl_vendor.d/50_mesa.json")
    env("GSK_RENDERER", "gl")
end

env("XCURSOR_THEME", settings.theme.cursorTheme)
env("XCURSOR_SIZE", tostring(settings.theme.cursorSize))
env("HYPRCURSOR_SIZE", tostring(settings.theme.cursorSize))
env("MOZ_ENABLE_WAYLAND", "1")
env("QT_QPA_PLATFORM", "wayland;xcb")
env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
env("QT_QPA_PLATFORMTHEME", "qt6ct")
env("SAL_USE_VCLPLUGIN", "gtk3")

hl.config({
    general = {
        gaps_in  = settings.windows.gapsIn,
        gaps_out = settings.bar.windowGap,

        border_size = settings.windows.border,

        col = {
            active_border   = { colors = { rgba(accent), rgba(mix(palette.base, accent, 0.25)) }, angle = 135 },
            inactive_border = rgba(mix(palette.base, palette.surface0, 0.8)),
        },

        resize_on_border        = true,
        extend_border_grab_area = 12,
        hover_icon_on_border    = true,

        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = (settings.bar.corners == "square" or settings.bar.inside == "sharp") and 0
                         or settings.bar.inside == "soft" and math.floor(settings.windows.rounding / 2)
                         or settings.windows.rounding,
        rounding_power = 2,

        shadow = {
            enabled = false,
        },

        blur = {
            enabled = false,
        },
    },

    animations = {
        enabled = animSpeed > 0,
    },
})

local animStyle = settings.theme.animationStyle or "snappy"
-- Beyond Vyntaris's own three, a style is one of Motion.js's presets: its own curves and pace, for the shell too.
local preset = require("lib.motion")[animStyle]
local calm = animStyle == "smooth" or animStyle == "snappy" or preset ~= nil

if preset then
    hl.curve("default",      { type = "bezier", points = preset.main })
    hl.curve("opening",      { type = "bezier", points = preset.open })
    hl.curve("overshot",     { type = "bezier", points = preset.workspace })
    hl.curve("bounce",       { type = "bezier", points = preset.move })
    hl.curve("snappyReturn", { type = "bezier", points = preset.main })
elseif calm then
    local ease = animStyle == "snappy" and { {0.2, 1}, {0.3, 1} } or { {0.25, 0.8}, {0.25, 1} }
    hl.curve("default",      { type = "bezier", points = ease })
    hl.curve("overshot",     { type = "bezier", points = ease })
    hl.curve("bounce",       { type = "bezier", points = ease })
    hl.curve("snappyReturn", { type = "bezier", points = ease })
else
    hl.curve("default",      { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.05} } })
    hl.curve("overshot",     { type = "bezier", points = { {0.13, 0.99}, {0.29, 1.08} } })
    hl.curve("bounce",       { type = "bezier", points = { {0.4, 0.9},   {0.6, 1.0} } })
    hl.curve("snappyReturn", { type = "bezier", points = { {0.4, 0.9},   {0.6, 1.0} } })
end
hl.curve("liner",        { type = "bezier", points = { {1, 1},       {1, 1} } })
hl.curve("accelerate",   { type = "bezier", points = preset and preset.close or { {0.3, 0}, {0.8, 0.15} } })

local animK = math.max(animSpeed, 0.1) * (animStyle == "snappy" and 1.45 or preset and preset.speed or 1)
hl.curve("bouncy", { type = "spring", mass = 1, stiffness = 240 * animK * animK, dampening = 19 * animK })

local function animation(a)
    if a.speed then a.speed = a.speed / animK end
    hl.animation(a)
end

-- How windows open and workspaces switch is part of the motion style: a preset's own, or rising for Vyntaris's three.
local winStyle = ({ slidevert = "slidevert", slide = "slide", popin = "popin 85%" })[preset and preset.windows or ""] or "slidevert"
local wsStyle = ({ slidevert = "slidevert", slide = "slide", fade = "fade" })[preset and preset.workspaces or ""] or "slidevert"

animation({ leaf = "global",           enabled = true, speed = 6,   bezier = "default" })
animation({ leaf = "windows",          enabled = true, speed = 2.2, bezier = "snappyReturn", style = winStyle })
if preset then
    animation({ leaf = "windowsIn",    enabled = true, speed = 2.2, bezier = "opening",      style = winStyle })
elseif calm then
    animation({ leaf = "windowsIn",    enabled = true, speed = 2.2, bezier = "default",      style = winStyle })
else
    animation({ leaf = "windowsIn",    enabled = true, speed = 2.2, spring = "bouncy",       style = winStyle })
end
animation({ leaf = "windowsOut",       enabled = true, speed = 2.2, bezier = "accelerate",   style = winStyle })
animation({ leaf = "windowsMove",      enabled = true, speed = 2.2, bezier = "bounce",       style = "slide" })
animation({ leaf = "fade",             enabled = true, speed = 2.2, bezier = "default" })
animation({ leaf = "fadeIn",           enabled = true, speed = 2.2, bezier = "default" })
animation({ leaf = "fadeOut",          enabled = true, speed = 2.2, bezier = "default" })
animation({ leaf = "fadeSwitch",       enabled = true, speed = 2.2, bezier = "default" })
animation({ leaf = "fadeDim",          enabled = true, speed = 2.2, bezier = "default" })
animation({ leaf = "workspaces",       enabled = true, speed = 7,   bezier = "overshot",     style = wsStyle })
animation({ leaf = "specialWorkspace", enabled = true, speed = 6,   bezier = "overshot",     style = "slidefadevert 20%" })
animation({ leaf = "layers",           enabled = true, speed = 4,   bezier = "bounce",       style = "slide top" })
animation({ leaf = "layersOut",        enabled = true, speed = 5,   bezier = "bounce",       style = "slide bottom" })
animation({ leaf = "border",           enabled = true, speed = 1,   bezier = "liner" })
animation({ leaf = "borderangle",      enabled = false })
animation({ leaf = "zoomFactor",       enabled = true, speed = 6,   bezier = "default" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

hl.config({
    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        allow_session_lock_restore = true,
        background_color         = tonumber("ff" .. palette.base, 16),
        disable_autoreload       = true,
        enable_anr_dialog        = false,
        disable_hyprland_guiutils_check = true,
        disable_watchdog_warning = true,
        lockdead_screen_delay    = 5000,
    },
    debug = {
        suppress_errors = true,
    },
    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})

hl.config({
    input = {
        kb_layout  = settings.input.kbLayout,
        kb_variant = settings.input.kbVariant,
        kb_options = settings.input.kbOptions,
        kb_model   = "",
        kb_rules   = "",

        follow_mouse = 1,
        numlock_by_default = true,
        force_no_accel = not settings.input.mouseAccel,
        sensitivity = settings.input.sensitivity,

        touchpad = {
            natural_scroll = settings.input.naturalScroll,
            tap_to_click   = settings.input.tapToClick,
            disable_while_typing = true,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "vertical",   action = "workspace" })

local mainMod = "SUPER"
local qs = function(args) return hl.dsp.exec_cmd("qs -c vyntaris ipc call " .. args) end
local shell = function(name) return hl.dsp.global("quickshell:" .. name) end
local app = function(args) return hl.dsp.exec_cmd("vyntaris-app " .. args) end
local run = function(cmd)
    return hl.dsp.exec_cmd("systemd-run --user --scope --quiet --collect --slice=app.slice -- sh -c '"
        .. tostring(cmd):gsub("'", "'\\''") .. "'")
end

hl.bind(mainMod .. " + Return",    run(settings.apps.terminal), { description = "Terminal" })
hl.bind(mainMod .. " + E",         run(settings.apps.fileManager), { description = "Files" })
hl.bind(mainMod .. " + B",         run(settings.apps.browser), { description = "Browser" })
hl.bind(mainMod .. " + C",         run(settings.apps.editor), { description = "Code editor" })
hl.bind("CTRL + SHIFT + Escape",   run("vyntaris-monitor"), { description = "Task manager" })
hl.bind(mainMod .. " + H",         run("vyntaris-monitor"), { description = "Task manager" })
hl.bind(mainMod .. " + SHIFT + H", qs("wiki toggle"), { description = "Arch Wiki" })
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Pick a color from the screen" })

hl.bind("SUPER + Super_L",          shell("control"), { release = true, description = "Start: control center, type to search apps (tap SUPER)" })
hl.bind(mainMod .. " + R",          shell("run"), { description = "Run a command" })
hl.bind(mainMod .. " + SHIFT + E",  shell("files"), { description = "Search files" })
hl.bind(mainMod .. " + period",     shell("emoji"), { description = "Emoji" })
hl.bind(mainMod .. " + V",          shell("clipboard"), { description = "Clipboard history" })
hl.bind(mainMod .. " + I",          app("settings toggle"), { description = "Settings" })
hl.bind(mainMod .. " + Escape",     shell("power"), { description = "Power menu" })
hl.bind(mainMod .. " + L",          hl.dsp.exec_cmd("loginctl lock-session"), { description = "Lock" })
hl.bind(mainMod .. " + Delete",     hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"), { description = "Log out" })
hl.bind(mainMod .. " + W",          shell("wallpaper"), { description = "Wallpapers" })
hl.bind(mainMod .. " + SHIFT + W",  qs("wallpaper random"), { description = "Random wallpaper" })
hl.bind(mainMod .. " + K",          qs("keyboard open"), { description = "Keyboard layouts (again: next)" })
hl.bind(mainMod .. " + space",      qs("keyboard switchLayout"), { description = "Next keyboard layout" })
hl.bind(mainMod .. " + T",          shell("timer"), { description = "Timer and stopwatch" })
hl.bind(mainMod .. " + A",          shell("apps"), { description = "All apps" })
hl.bind(mainMod .. " + SHIFT + A",  shell("sound"), { description = "Sound: outputs and inputs" })
hl.bind("ALT + Tab",                qs("switcher next"), { description = "Switch windows" })
hl.bind("ALT + SHIFT + Tab",        qs("switcher previous"), { description = "Switch windows, backwards" })
hl.bind("ALT + Alt_L",              qs("switcher commit"), { release = true, description = "Switch to the window picked" })
hl.bind("ALT + SHIFT + Alt_L",      qs("switcher commit"), { release = true, description = "Switch to the window picked" })
hl.bind("switch:on:Lid Switch", qs("session lid"), { locked = true, description = "Lid closed" })

hl.bind(mainMod .. " + SHIFT + S",  qs("screenshot region"), { description = "Screenshot of a region" })
hl.bind("Print",                    qs("screenshot region"), { description = "Screenshot of a region" })
hl.bind("XF86SelectiveScreenshot",  qs("screenshot region"), { description = "Screenshot of a region" })
hl.bind("SHIFT + Print",            qs("screenshot screen"), { description = "Screenshot of the screen" })
hl.bind(mainMod .. " + SHIFT + R",  qs("record toggle"), { description = "Record a region (again: stop)" })
hl.bind(mainMod .. " + CTRL + R",   qs("record screen"), { description = "Record the screen" })

hl.bind(mainMod .. " + Q",             hl.dsp.window.close(), { description = "Close window" })
hl.bind("ALT + F4",                    hl.dsp.window.close(), { description = "Close window" })
hl.bind(mainMod .. " + SHIFT + Q",     hl.dsp.window.kill(), { description = "Force quit a frozen window" })
hl.bind(mainMod .. " + F",             hl.dsp.window.fullscreen({ action = "toggle" }), { description = "Fullscreen" })
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }), { description = "Float / tile window" })
hl.bind(mainMod .. " + P",             hl.dsp.window.pin({ action = "toggle" }), { description = "Pin window on all workspaces" })
hl.bind(mainMod .. " + S",             hl.dsp.layout("togglesplit"), { description = "Switch split direction" })
hl.bind(mainMod .. " + G",             hl.dsp.group.toggle(), { description = "Group windows (tabs)" })
hl.bind(mainMod .. " + bracketleft",   hl.dsp.group.prev(), { description = "Previous tab in group" })
hl.bind(mainMod .. " + bracketright",  hl.dsp.group.next(), { description = "Next tab in group" })

local function zoom(step)
    return function()
        local z = hl.get_config("cursor.zoom_factor") or 1
        hl.config({ cursor = { zoom_factor = math.max(1, z + step) } })
    end
end
hl.bind(mainMod .. " + equal", zoom(0.5), { description = "Zoom in" })
hl.bind(mainMod .. " + minus", zoom(-0.5), { description = "Zoom out" })

for _, d in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mainMod .. " + " .. d,         hl.dsp.focus({ direction = d }), { description = "Focus " .. d })
    hl.bind(mainMod .. " + SHIFT + " .. d, hl.dsp.window.move({ direction = d }), { description = "Move window " .. d })
    local dx = (d == "right" and 30) or (d == "left" and -30) or 0
    local dy = (d == "down" and 30) or (d == "up" and -30) or 0
    hl.bind(mainMod .. " + CTRL + " .. d,  hl.dsp.window.resize({ x = dx, y = dy, relative = true }), { repeating = true, description = "Resize window " .. d })
end

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }), { description = "Go to workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "Move window to workspace " .. i })
    hl.bind(mainMod .. " + ALT + " .. key,   hl.dsp.window.move({ workspace = i, follow = false }), { description = "Send window to workspace " .. i })
end
hl.bind(mainMod .. " + ALT + right",         hl.dsp.focus({ workspace = "r+1" }), { description = "Next workspace" })
hl.bind(mainMod .. " + ALT + left",          hl.dsp.focus({ workspace = "r-1" }), { description = "Previous workspace" })
hl.bind(mainMod .. " + ALT + down",          hl.dsp.focus({ workspace = "empty" }), { description = "Empty workspace" })
hl.bind(mainMod .. " + SHIFT + ALT + right", hl.dsp.window.move({ workspace = "r+1" }), { description = "Move window to the next workspace" })
hl.bind(mainMod .. " + SHIFT + ALT + left",  hl.dsp.window.move({ workspace = "r-1" }), { description = "Move window to the previous workspace" })

hl.bind(mainMod .. " + grave",         hl.dsp.workspace.toggle_special("magic"), { description = "Scratchpad" })
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:magic", follow = false }), { description = "Send window to the scratchpad" })

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace (scroll)" })
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace (scroll)" })

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window (drag)" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window (drag)" })
hl.bind(mainMod .. " + SHIFT + mouse:272", hl.dsp.window.resize(), { mouse = true, description = "Resize window (drag, touchpad)" })

local vol = function(cmd) return hl.dsp.exec_cmd("wpctl " .. cmd) end
hl.bind("XF86AudioRaiseVolume", vol("set-volume -l " .. (settings.audio.boost and "1.5" or "1") .. " @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", vol("set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute",        vol("set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, description = "Mute" })
hl.bind("XF86AudioMicMute",     vol("set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, description = "Mute the microphone" })

hl.bind("XF86MonBrightnessUp",   qs("brightness up"), { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", qs("brightness down"), { locked = true, repeating = true, description = "Brightness down" })
hl.bind("XF86AudioNext",  qs("media next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPause", qs("media toggle"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioPlay",  qs("media toggle"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioPrev",  qs("media previous"), { locked = true, description = "Previous track" })
hl.bind("XF86Calculator", qs("launcher query ''"), { description = "Calculator" })
hl.bind("XF86RFKill",            qs("hardware airplaneKey"), { locked = true, description = "Airplane mode" })
hl.bind("XF86TouchpadToggle",    qs("hardware touchpad"), { locked = true, description = "Touchpad on / off" })
hl.bind("XF86TouchpadOn",        qs("hardware touchpadOn"), { locked = true, description = "Touchpad on" })
hl.bind("XF86TouchpadOff",       qs("hardware touchpadOff"), { locked = true, description = "Touchpad off" })
hl.bind("XF86WebCam",            qs("hardware camera"), { locked = true, description = "Camera" })
hl.bind("XF86RefreshRateToggle", qs("hardware vrr"), { description = "Adaptive sync" })
hl.bind("XF86Display",           app("settings page displays"), { description = "Display settings" })
hl.bind("XF86Launch1",           shell("control"), { description = "Control center" })
hl.bind("XF86Launch2",           qs("hardware powerMode"), { description = "Power mode" })
hl.bind("XF86Launch3",           qs("system toggle"), { description = "System panel" })
hl.bind("XF86Launch4",           qs("hardware powerMode"), { description = "Power mode" })
hl.bind("XF86Favorites",         qs("launcher toggle"), { description = "App launcher" })
hl.bind("Help",                  app("help toggle"), { description = "Help: all shortcuts" })
hl.bind(mainMod .. " + F1",        app("help toggle"), { description = "Help: all shortcuts" })

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

hl.layer_rule({
    name    = "quickshell-no-anim",
    match   = { namespace = "^quickshell-(bar|power|game)$" },
    no_anim = true,
})

hl.layer_rule({
    name    = "pickers-no-anim",
    match   = { namespace = "^(hyprpicker|selection|quickshell-auth|quickshell-edge)$" },
    no_anim = true,
})

hl.window_rule({
    name     = "electron-dialogs",
    match    = { class = "^(electron)$" },
    float    = true,
    center   = true,
    max_size = "960 540",
})

hl.window_rule({
    name   = "share-picker",
    -- Vyntaris's apps (Settings, Shortcuts, Store, Backup, Dr. Help, the system monitor) tile like any other;
    -- only the prompt asking what to share floats.
    match  = { class = "^org\\.vyntaris\\.SharePicker$" },
    float  = true,
    center = true,
})

for _, r in ipairs({
    { "pip",          { class = "^(firefox)$", title = "^(Picture-in-Picture)$" } },
    { "ff-library",   { class = "^(firefox)$", title = "^(Library)$" } },
    { "ff-about",     { title = "^(About Mozilla Firefox)$" } },
    { "top",          { class = "^(kitty)$", title = "^(top|btop|htop)$" } },
    { "pavucontrol",  { class = "^(org.pulseaudio.pavucontrol)$" } },
    { "blueman",      { class = "^(blueman-manager)$" } },
    { "nm-editor",    { class = "^(nm-connection-editor)$" } },
    { "spotify",      { class = "^([Ss]potify)$" } },
    { "calculator",   { class = "^(galculator|org.gnome.Calculator)$" } },
    { "portal",       { class = "^(xdg-desktop-portal-gtk)$" } },
    { "dlg-open",     { title = "^(Open|Open File|Choose Files|Save As|Confirm to replace files|File Operation Progress)$" } },
}) do
    hl.window_rule({ name = "float-" .. r[1], match = r[2], float = true })
end

local browserWindows = {}
local popupProbeWidth, popupProbeStep, popupProbeWait = 480, 30, 450
local signInWords = {
    "sign in", "sign-in", "signin", "log in", "log-in", "login", "authorize", "authorise", "oauth", "accounts",
    "prijav", "nalog", "anmeld", "connexion", "iniciar", "accedi", "zaloguj", "entrar",
}

local function looksLikeSignIn(title)
    local lower = title:lower()
    for _, word in ipairs(signInWords) do
        if lower:find(word, 1, true) then return true end
    end
    return false
end

local function floatAsPopup(w)
    local target = "address:" .. w.address
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = target }))
    hl.dispatch(hl.dsp.window.resize({ x = 520, y = 720, window = target }))
    hl.dispatch(hl.dsp.window.center({ window = target }))
end

local function sortBrowserWindow(w)
    local target = "address:" .. w.address
    local function animate(on) hl.dispatch(hl.dsp.window.set_prop({ prop = "no_anim", value = on and "0" or "1", window = target })) end
    animate(false)
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = target }))
    hl.dispatch(hl.dsp.window.resize({ x = popupProbeWidth, y = 720, window = target }))
    hl.dispatch(hl.dsp.window.center({ window = target }))
    local waited, check = 0, nil
    check = hl.timer(function()
        waited = waited + popupProbeStep
        if not browserWindows[w.address] then
            check:set_enabled(false)
        elseif w.size.x > popupProbeWidth then
            check:set_enabled(false)
            hl.dispatch(hl.dsp.window.float({ action = "disable", window = target }))
            animate(true)
        elseif waited >= popupProbeWait then
            check:set_enabled(false)
            browserWindows[w.address] = nil
            floatAsPopup(w)
            animate(true)
        end
    end, { timeout = popupProbeStep, type = "repeat" })
end

hl.on("window.open", function(w)
    if w.class ~= "firefox" or w.floating then return end
    for _, other in ipairs(hl.get_windows()) do
        if other.class == "firefox" and other.address ~= w.address then
            browserWindows[w.address] = os.time() + 5
            sortBrowserWindow(w)
            return
        end
    end
end)

hl.on("window.close", function(w)
    browserWindows[w.address] = nil
end)

hl.on("window.title", function(w)
    local deadline = browserWindows[w.address]
    if not deadline then return end
    if os.time() > deadline then browserWindows[w.address] = nil; return end
    if w.floating or not looksLikeSignIn(w.title) then return end
    browserWindows[w.address] = nil
    floatAsPopup(w)
end)

do
    local mine = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/user.lua"
    local f = io.open(mine)
    if f then
        f:close()
        local ok, err = pcall(dofile, mine)
        if not ok then tell("A mistake in ~/.config/hypr/user.lua", "The rest of it is left out: {0}", tostring(err)) end
    end
end
