-- The motion styles in config/quickshell/config/Motion.js (the shell reads the same table), for Hyprland's curves.
local here = (package.searchpath("lib.motion", package.path) or ""):match("^(.*)/lib/[^/]*$") or "."
local sources = { here .. "/../quickshell/config/Motion.js", "/etc/xdg/quickshell/vyntaris/config/Motion.js" }

local function curve(body, key)
    local list = body:match(key .. ":%s*%[([^%]]+)%]")
    if not list then return nil end
    local n = {}
    for v in list:gmatch("-?[%d.]+") do n[#n + 1] = tonumber(v) end
    if #n ~= 4 then return nil end
    return { { n[1], n[2] }, { n[3], n[4] } }
end

local presets = {}
for _, path in ipairs(sources) do
    local file = io.open(path, "r")
    if file then
        local src = file:read("a")
        file:close()
        local tableBody = src:match("var presets = (%b{})") or ""
        for name, body in tableBody:gmatch("([%w_]+):%s*(%b{})") do
            local p = {
                main = curve(body, "main"), open = curve(body, "open"), close = curve(body, "close"),
                move = curve(body, "move"), workspace = curve(body, "workspace"),
                speed = tonumber(body:match("speed:%s*(-?[%d.]+)")) or 1,
                windows = body:match('windows:%s*"([^"]+)"'), workspaces = body:match('workspaces:%s*"([^"]+)"'),
            }
            if p.main and p.open and p.close and p.move and p.workspace then presets[name] = p end
        end
        break
    end
end
return presets
