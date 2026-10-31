import functools
import json
import math
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
HEX = re.compile(r"#[0-9a-fA-F]{6}")

def shell_dir():
    for d in (os.environ.get("VYNTARIS_SHELL"), os.path.join(HERE, "..", "..", "config", "quickshell"),
              "/etc/xdg/quickshell/vyntaris"):
        if d and os.path.isfile(os.path.join(d, "config", "Palettes.js")):
            return os.path.normpath(d)
    raise FileNotFoundError("the shell's config/Palettes.js")

@functools.cache
def palettes():
    src = open(os.path.join(shell_dir(), "config", "Palettes.js")).read()
    out = {}
    for flavour, body in re.findall(r"\b(\w+):\s*\{(.*?)\}", src, re.S):
        colours = dict(re.findall(r'(\w+):\s*"(#[0-9a-fA-F]{6})"', body))
        if "base" in colours:
            out[flavour] = colours
    return out

def palette(flavour):
    return palettes().get(flavour) or palettes()["mocha"]

@functools.cache
def shape():
    src = open(os.path.join(shell_dir(), "components", "LogoShape.js")).read()
    return json.loads(src[src.index("{"):src.rindex("}") + 1])

def rgb(colour):
    if isinstance(colour, tuple):
        return colour
    return tuple(int(colour[i:i + 2], 16) / 255 for i in (1, 3, 5))

def hexcode(colour):
    return "#" + "".join(f"{round(v * 255):02x}" for v in rgb(colour))

def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(rgb(a), rgb(b)))

def hsl(colour):
    r, g, b = rgb(colour)
    hi, lo = max(r, g, b), min(r, g, b)
    l, d = (hi + lo) / 2, hi - lo
    h = s = 0.0
    if d > 0:
        s = d / (1 - abs(2 * l - 1))
        if hi == r:
            h = 60 * math.fmod((g - b) / d, 6)
        elif hi == g:
            h = 60 * ((b - r) / d + 2)
        else:
            h = 60 * ((r - g) / d + 4)
    return math.fmod(h + 360, 360), s, l

def from_hsl(h, s, l):
    h = math.fmod(math.fmod(h, 360) + 360, 360)
    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs(math.fmod(h / 60, 2) - 1))
    m = l - c / 2
    r, g, b = ((c, x, 0) if h < 60 else (x, c, 0) if h < 120 else (0, c, x) if h < 180
               else (0, x, c) if h < 240 else (x, 0, c) if h < 300 else (c, 0, x))
    return "#" + "".join(f"{math.floor((v + m) * 255 + 0.5):02x}" for v in (r, g, b))

def is_dark(pal):
    return hsl(pal["base"])[2] < 0.5

def fit(colour, dark):
    h, s, _ = hsl(colour)
    if dark:
        return from_hsl(h, min(0.92, max(0.6, s)), 0.77)
    return from_hsl(h, min(0.92, max(0.6, s)), 0.77)

def partner_of(colour):
    h, s, l = hsl(colour)
    return from_hsl(h - 45, s, l)

def accent(pal, name):
    if HEX.fullmatch(name or ""):
        a = fit(name, is_dark(pal))
        return a, partner_of(a)
    if name not in pal:
        name = "blue"
    return pal[name], pal[shape()["partners"].get(name, "blue")]
