-- Pure colour maths: sRGB <-> linear <-> OKLab/OKLCH, luminance, contrast and
-- hex/xterm conversions. No vim.* dependencies, so any config that needs to
-- read or derive colours can require this (currently configs/semanticTokens.lua,
-- which derives its palette from the active colourscheme).

local M = {}

local function srgb_to_linear(c)
  c = c / 255
  return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end

local function linear_to_srgb(c)
  c = c <= 0.0031308 and c * 12.92 or 1.055 * c ^ (1 / 2.4) - 0.055
  return math.max(0, math.min(255, math.floor(c * 255 + 0.5)))
end

local function relative_luminance(rgb)
  local r, g, b = srgb_to_linear(rgb[1]), srgb_to_linear(rgb[2]), srgb_to_linear(rgb[3])
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

local function rgb_to_oklab(rgb)
  local r, g, b = srgb_to_linear(rgb[1]), srgb_to_linear(rgb[2]), srgb_to_linear(rgb[3])
  local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
  local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
  local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
  local l_, m_, s_ = l ^ (1 / 3), m ^ (1 / 3), s ^ (1 / 3)
  return {
    0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
    1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
    0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
  }
end

local function oklab_to_linear(lab)
  local L, a, b = lab[1], lab[2], lab[3]
  local l_ = L + 0.3963377774 * a + 0.2158037573 * b
  local m_ = L - 0.1055613458 * a - 0.0638541728 * b
  local s_ = L - 0.0894841775 * a - 1.2914855480 * b
  local l, m, s = l_ ^ 3, m_ ^ 3, s_ ^ 3
  return {
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  }
end

---Hue of an OKLab colour, in degrees. math.atan2, not math.atan(y, x): LuaJIT's atan takes a single
---argument and silently ignores the second, which produced hues without their quadrant.
local function lab_to_lch(lab)
  return lab[1], math.sqrt(lab[2] ^ 2 + lab[3] ^ 2), math.deg(math.atan2(lab[3], lab[2])) % 360
end

local function lab_dist(a, b)
  local dl, da, db = a[1] - b[1], a[2] - b[2], a[3] - b[3]
  return math.sqrt(dl * dl + da * da + db * db)
end

local function in_gamut(lab)
  local lin = oklab_to_linear(lab)
  return lin[1] >= -0.0005 and lin[1] <= 1.0005
    and lin[2] >= -0.0005
    and lin[2] <= 1.0005
    and lin[3] >= -0.0005
    and lin[3] <= 1.0005
end

--- OKLCH -> sRGB, giving up chroma until the colour fits into sRGB
local function lch_to_rgb(l, c, h)
  local rad = math.rad(h)
  for _ = 1, 32 do
    local lab = { l, c * math.cos(rad), c * math.sin(rad) }
    if in_gamut(lab) then
      local lin = oklab_to_linear(lab)
      return { linear_to_srgb(lin[1]), linear_to_srgb(lin[2]), linear_to_srgb(lin[3]) }
    end
    c = c * 0.93
    if c < 0.004 then
      break
    end
  end
  local lin = oklab_to_linear { l, 0, 0 }
  return { linear_to_srgb(lin[1]), linear_to_srgb(lin[2]), linear_to_srgb(lin[3]) }
end

local function contrast_ratio(a, b)
  local la, lb = relative_luminance(a), relative_luminance(b)
  local hi, lo = math.max(la, lb), math.min(la, lb)
  return (hi + 0.05) / (lo + 0.05)
end

local function hex(rgb)
  return string.format("#%02x%02x%02x", rgb[1], rgb[2], rgb[3])
end

local function rgb_from_hex(str)
  local r, g, b = str:match "^#?(%x%x)(%x%x)(%x%x)$"
  return r and { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) } or nil
end

--- highlight-group colour value (0xRRGGBB) -> { r, g, b } in 0..255
local function number_to_rgb(value)
  return { math.floor(value / 65536) % 256, math.floor(value / 256) % 256, value % 256 }
end

--- xterm 256 palette entry -> rgb (legacy colourschemes only define cterm colours)
local XTERM_BASE = {
  { 0, 0, 0 },
  { 128, 0, 0 },
  { 0, 128, 0 },
  { 128, 128, 0 },
  { 0, 0, 128 },
  { 128, 0, 128 },
  { 0, 128, 128 },
  { 192, 192, 192 },
  { 128, 128, 128 },
  { 255, 0, 0 },
  { 0, 255, 0 },
  { 255, 255, 0 },
  { 0, 0, 255 },
  { 255, 0, 255 },
  { 0, 255, 255 },
  { 255, 255, 255 },
}

local function xterm256(i)
  if i < 16 then
    return XTERM_BASE[i + 1]
  elseif i < 232 then
    local n, steps = i - 16, { 0, 95, 135, 175, 215, 255 }
    return { steps[math.floor(n / 36) + 1], steps[math.floor(n / 6) % 6 + 1], steps[n % 6 + 1] }
  end
  local v = 8 + (i - 232) * 10
  return { v, v, v }
end

M.srgb_to_linear = srgb_to_linear
M.linear_to_srgb = linear_to_srgb
M.relative_luminance = relative_luminance
M.rgb_to_oklab = rgb_to_oklab
M.oklab_to_linear = oklab_to_linear
M.lab_to_lch = lab_to_lch
M.lab_dist = lab_dist
M.in_gamut = in_gamut
M.lch_to_rgb = lch_to_rgb
M.contrast_ratio = contrast_ratio
M.hex = hex
M.rgb_from_hex = rgb_from_hex
M.number_to_rgb = number_to_rgb
M.xterm256 = xterm256

return M
