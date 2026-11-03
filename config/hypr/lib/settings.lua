local json = require("lib.json")

local M = {}

local defaults = {
    theme   = { flavor = "mocha", accent = "mauve", accentLight = "mauve", animationSpeed = 1.5,
                animationStyle = "snappy",
                cursorTheme = "Bibata-Modern-Ice", cursorSize = 24 },
    apps    = { terminal = "kitty", terminalRun = "kitty", fileManager = "thunar", browser = "firefox", editor = "code" },
    input   = { kbLayout = "us", kbVariant = "", kbOptions = "",
                naturalScroll = true, tapToClick = true, sensitivity = 0, mouseAccel = false },
    windows = { rounding = 10, gapsIn = 5, border = 2 },
    display = { scale = 1, monitors = {} },
    audio   = { boost = false },
    bar     = { windowGap = 8, corners = "round", inside = "rounded" },
}

local function merge(base, over)
    for k, v in pairs(over) do
        local want = type(base[k])
        if base[k] == nil then
            base[k] = v
        elseif want == "table" then
            if type(v) == "table" then merge(base[k], v) end
        elseif type(v) == want and (want ~= "number" or (v == v and v > -math.huge and v < math.huge)) then
            base[k] = v
        end
    end
    return base
end

local function clamp(x, lo, hi)
    return math.max(lo, math.min(hi, x))
end

local function tidy(s)
    local t, w, d = s.theme, s.windows, s.display
    t.animationSpeed = clamp(t.animationSpeed, 0.1, 4)
    t.cursorSize = math.floor(clamp(t.cursorSize, 8, 256))
    w.rounding = clamp(w.rounding, 0, 40)
    w.gapsIn = clamp(w.gapsIn, 0, 60)
    w.border = clamp(w.border, 0, 12)
    d.scale = clamp(d.scale, 0.5, 4)
    s.bar.windowGap = clamp(s.bar.windowGap, 0, 60)
    s.input.sensitivity = clamp(s.input.sensitivity, -1, 1)
    if s.input.kbLayout == "" then s.input.kbLayout = defaults.input.kbLayout end
    for k, v in pairs(defaults.apps) do
        if type(s.apps[k]) ~= "string" or s.apps[k]:match("^%s*$") then s.apps[k] = v end
    end
    local monitors = {}
    for _, m in ipairs(d.monitors) do
        if type(m) == "table" and type(m.name) == "string" and m.name ~= "" then
            monitors[#monitors + 1] = {
                name = m.name,
                mode = type(m.mode) == "string" and m.mode ~= "" and m.mode or nil,
                position = type(m.position) == "string" and m.position ~= "" and m.position or nil,
                scale = type(m.scale) == "number" and m.scale == m.scale and clamp(m.scale, 0.5, 4) or nil,
            }
        end
    end
    d.monitors = monitors
    return s
end

local function deep_copy(t)
    local out = {}
    for k, v in pairs(t) do
        out[k] = type(v) == "table" and deep_copy(v) or v
    end
    return out
end

function M.path()
    local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    return config_home .. "/quickshell/settings.json"
end

function M.load()
    local settings = deep_copy(defaults)
    local file = io.open(M.path(), "r")
    if not file then return tidy(settings) end

    local content = file:read("a")
    file:close()

    local ok, data = pcall(json.decode, content)
    if not ok then return tidy(settings), data end
    if type(data) == "table" then merge(settings, data) end
    return tidy(settings)
end

return M
