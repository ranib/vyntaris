hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        enable_anr_dialog        = false,
        disable_hyprland_guiutils_check = true,
        disable_watchdog_warning = true,
    },
    debug = { suppress_errors = true },
    ecosystem = { no_update_news = true, no_donation_nag = true },
    animations = { enabled = false },
    general = {
        border_size = 2,
        col = { active_border = "rgba(cba6f7ff)", inactive_border = "rgba(2d2e40ff)" },
    },
    decoration = { rounding = 14 },
})

hl.window_rule({
    name   = "installer-terminal",
    match  = { class = "^(kitty)$" },
    float  = true,
    size   = "960 600",
    center = true,
})
hl.window_rule({
    name   = "installer-text",
    match  = { class = "^(installer-text)$" },
    float  = true,
    size   = "1100 720",
    center = true,
})
local terminal = hl.dsp.exec_cmd("kitty installer-shell")
hl.bind("SUPER + Return", terminal, { description = "Terminal" })
hl.bind("CTRL + ALT + T", terminal, { description = "Terminal" })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close the terminal" })
hl.bind("ALT + F4", hl.dsp.window.close(), { description = "Close the terminal" })

hl.on("hyprland.start", function ()
    hl.exec_cmd("qs -p /usr/share/desktop-installer; hyprctl dispatch 'hl.dsp.exit()'")
end)
