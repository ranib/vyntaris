local M = {}

local function hsl(hex)
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local l, d = (max + min) / 2, max - min
    local h, s = 0, 0
    if d > 0 then
        s = d / (1 - math.abs(2 * l - 1))
        if max == r then h = 60 * (((g - b) / d) % 6)
        elseif max == g then h = 60 * ((b - r) / d + 2)
        else h = 60 * ((r - g) / d + 4) end
    end
    return (h + 360) % 360, s, l
end

local function from_hsl(h, s, l)
    h = h % 360
    local c = (1 - math.abs(2 * l - 1)) * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = l - c / 2
    local r, g, b
    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    local function byte(v) return math.floor((v + m) * 255 + 0.5) end
    return string.format("%02x%02x%02x", byte(r), byte(g), byte(b))
end

function M.accent(palette, name)
    if type(name) == "string" and name:match("^#%x%x%x%x%x%x$") then
        local _, _, base_l = hsl(palette.base)
        local h, s = hsl(name:sub(2))
        if base_l < 0.5 then return from_hsl(h, math.min(0.92, math.max(0.6, s)), 0.77) end
        return from_hsl(h, math.min(0.92, math.max(0.6, s)), 0.77)
    end
    return palette[name] or palette.blue
end

return M
