.pragma library
.import "MaterialIcons.js" as Material

var material = {
    "wifi": ["network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"],
    "wifi-off": "wifi_off",
    "ethernet": "lan",
    "volume": ["volume_mute", "volume_down", "volume_up"],
    "volume-x": "volume_off",
    "mic": "mic",
    "mic-off": "mic_off",
    "sun": "light_mode",
    "moon": "dark_mode",
    "cloud": "cloud",
    "cloud-off": "cloud_off",
    "partly-cloudy": "partly_cloudy_day",
    "partly-cloudy-night": "partly_cloudy_night",
    "rain": "rainy",
    "snow": "weather_snowy",
    "storm": "thunderstorm",
    "fog": "foggy",
    "sunset": "wb_twilight",
    "power": "power_settings_new",
    "restart": "restart_alt",
    "logout": "logout",
    "lock": "lock",
    "vpn": "vpn_key",
    "search": "search",
    "eye": "visibility",
    "eye-off": "visibility_off",
    "play": "play_arrow",
    "pause": "pause",
    "stop": "stop",
    "next": "skip_next",
    "previous": "skip_previous",
    "record": "radio_button_checked",
    "music": "music_note",
    "headphones": "headphones",
    "bolt": "bolt",
    "battery": ["battery_android_0", "battery_android_1", "battery_android_2", "battery_android_3", "battery_android_4",
                "battery_android_5", "battery_android_6", "battery_android_full"],
    "close": "close",
    "check": "check",
    "plus": "add",
    "minus": "remove",
    "info": "info",
    "alert": "warning",
    "bell": "notifications",
    "bell-off": "notifications_off",
    "chevron-left": "chevron_left",
    "chevron-right": "chevron_right",
    "arrow-down": "arrow_downward",
    "arrow-up": "arrow_upward",
    "external": "open_in_new",
    "refresh": "refresh",
    "history": "history",
    "cpu": "memory",
    "memory": "memory_alt",
    "thermometer": "thermostat",
    "disk": "hard_drive",
    "health": "monitor_heart",
    "settings": "settings",
    "sliders": "tune",
    "control": "toggle_on",
    "bluetooth": "bluetooth",
    "airplane": "flight",
    "airplane-off": "airplanemode_inactive",
    "camera": "photo_camera",
    "camera-off": "no_photography",
    "touchpad": "touch_app",
    "touchpad-off": "do_not_touch",
    "keyboard": "keyboard",
    "monitor": "monitor",
    "printer": "print",
    "globe": "language",
    "earth": "public",
    "translate": "translate",
    "calendar": "calendar_month",
    "gamepad": "sports_esports",
    "timer": "timer",
    "users": "group",
    "clock": "schedule",
    "cup": "coffee",
    "coffee": "coffee",
    "coffee-moon": "bedtime",
    "package": "package_2",
    "package-update": "deployed_code_update",
    "pacman": "deployed_code_update",
    "download": "download",
    "copy": "content_copy",
    "folder": "folder",
    "trash": "delete",
    "clipboard": "content_paste",
    "smartphone": "mobile",
    "tablet": "tablet_android",
    "laptop": "computer",
    "phone-ring": "mobile_sound",
    "send": "mobile_share",
    "image": "image",
    "windows": "select_window",
    "terminal": "terminal",
    "palette": "palette",
    "bar": "toolbar",
    "apps": "grid_view",
    "rocket": "rocket_launch",
    "accessibility": "accessibility_new",
};

var icons = {
    "power-saver": [{ d: "M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20ZM5.2 8.83L12.32 9.92A2.1 2.1 0 1 1 10.62 13.58Z", e: true }],
    "power-balanced": [{ d: "M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20ZM12 4.5L14.02 11.41A2.1 2.1 0 1 1 9.98 11.41Z", e: true }],
    "power-performance": [{ d: "M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20ZM18.8 8.83L13.38 13.58A2.1 2.1 0 1 1 11.68 9.92Z", e: true }],
    "vyntaris": [
        { fill: true, e: true, d: "M12.79 11.4L13.97 10.96L14.92 10.55L15.79 10.12L16.57 9.68L16.88 9.05L16.82 8.75L16.79 8.45L16.78 8.15L16.81 7.85L16.85 7.55L16.92 7.26L17.02 6.97L17.14 6.7L17.28 6.44L17.45 6.19L17.66 5.93L17.86 5.71L18.09 5.51L18.33 5.34L18.59 5.18L18.86 5.04L20.16 2.43L16.16 2.43zM6.69 12.72L8.05 12.57L9.18 12.38L10.35 12.12L11.45 11.83L7.26 2.43L1.08 2.43zM22.55 8.18L22.5 7.74L22.36 7.32L22.14 6.93L21.85 6.6L21.5 6.32L21.1 6.12L20.67 6L20.22 5.97L19.78 6.02L19.36 6.16L18.97 6.38L18.64 6.67L18.36 7.03L18.16 7.42L18.04 7.85L18.01 8.3L18.06 8.74L18.2 9.16L18.42 9.55L18.71 9.88L19.07 10.16L19.46 10.36L19.89 10.48L20.34 10.51L20.78 10.46L21.2 10.32L21.59 10.1L21.92 9.81L22.2 9.45L22.4 9.06L22.52 8.63zM3.06 13.46L3.08 13.5L0.65 14.24L0.75 14.52L0.89 14.78L1.1 15.07L1.3 15.28L1.56 15.51L1.85 15.7L2.15 15.86L2.52 16.01L2.92 16.14L3.34 16.24L3.77 16.32L4.23 16.37L4.78 16.41L5.88 16.41L7.15 16.31L7.92 16.21L8.7 16.08L9.49 15.92L10.4 15.7L11.22 15.49L12.13 15.21L12.93 14.95L13.82 14.62L14.69 14.27L15.44 13.94L16.25 13.55L16.93 13.19L17.66 12.77L18.25 12.39L18.81 12L19.32 11.6L18.83 11.42L18.37 11.17L17.96 10.85L17.59 10.48L16.86 10.93L15.99 11.39L15.03 11.84L13.99 12.27L12.9 12.66L11.87 12.98L10.83 13.27L9.7 13.53L8.59 13.73L7.52 13.88L6.52 13.96L5.6 13.98L4.79 13.94L4.06 13.84L3.48 13.69L3.23 13.58zM13.4 16.08L11.97 16.54L11.02 16.81L10.07 17.05L9.15 17.24L11.07 20.77z" },
    ],
};

function volumeLevel(v) {
    return v > 0.6 ? 2 : v > 0.25 ? 1 : 0;
}

function signal(s) {
    return s > 1 ? s / 100 : s;
}
function wifiLevel(s) {
    s = signal(s);
    return s > 0.75 ? 3 : s > 0.5 ? 2 : s > 0.2 ? 1 : 0;
}

var outlineOnly = { "battery_android_0": true };

function svg(name, color, dimColor, stroke, level, px, filled) {
    var m = material[name];
    if (m) {
        var list = m.levels || m;
        var pick = typeof list === "string" ? list : list[level < 0 || level >= list.length ? list.length - 1 : level];
        var shape = function (n) {
            return (filled && !outlineOnly[n] && Material.paths[n + "-fill"]) || Material.paths[n] || Material.paths["close"];
        };
        var inner = m.base && level >= 0 && pick !== m.base
            ? '<g fill="' + dimColor + '">' + shape(m.base) + '</g>' + shape(pick)
            : shape(pick);
        return "data:image/svg+xml;charset=utf-8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="' + px
            + '" height="' + px + '" viewBox="0 -960 960 960" fill="' + color + '">' + inner + '</svg>');
    }
    var parts = icons[name] || [];
    var body = parts.map(function (q) {
        return '<path d="' + q.d + '" fill="' + color + '"' + (q.e ? ' fill-rule="evenodd"' : '') + '/>';
    }).join("");
    return "data:image/svg+xml;charset=utf-8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="' + px
        + '" height="' + px + '" viewBox="0 0 24 24">' + body + '</svg>');
}
