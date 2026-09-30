-- Semantic highlighting for LSP semantic tokens (clangd, lua_ls, ts_ls, ...).
--
-- Servers already send semantic tokens to Nvim. What makes every variable kind
-- look identical out of the box is the default fallback, where @lsp.type.variable,
-- @lsp.type.parameter and @lsp.type.property all resolve to `Identifier` - and in
-- some colourschemes (habamax) `Identifier` and `Function` are the same colour.
--
-- Ten symbol kinds get their own colour here; everything else is left alone, so
-- functions, methods, types, classes, enums, macros, operators, strings, numbers,
-- comments and keywords keep the colourscheme's colours:
--   local            local variables                parameter        parameters
--   local_const      const/readonly locals          parameter_const  const/readonly parameters
--   member           data members (obj.f)           member_const     const data members
--   static           static storage                 global           external-linkage globals
--   enum_member      enumerators                    type_param       template/type parameters
--
-- The palette is derived, not hardcoded: on startup and on every ColorScheme event the
-- ten colours are rebuilt from the active colourscheme, so a theme switch re-tunes them
-- instead of leaving stale values behind. How it derives:
--   1. read the theme's own colours (Function, Type, Constant, String, Keyword, PreProc,
--      Special, Comment, Normal fg/bg, diagnostics, ...)
--   2. inherit the theme's variable "register": lightness and chroma come from its
--      Identifier colour, clamped for dark/light backgrounds and for the lightness the
--      background can carry at the contrast we want
--   3. place ten hues 36 degrees apart, rotated to the position farthest from the hues
--      the theme already uses, then scan each slot (hue offsets plus a few lightness and
--      chroma steps) for the colour with the most room: ANCHOR_TARGET away from
--      text/syntax colours, SOFT_TARGET away from structural/diagnostic ones,
--      MUTUAL_TARGET between the ten
--   4. keep WCAG contrast >= 4.5:1 against Normal bg, dropping chroma only as far as sRGB
--      makes necessary
-- Themes that use many hues can leave single kinds slightly below the target; the numbers
-- are always available from M.state() (palette plus a report with per-kind distance,
-- nearest theme colour, contrast and hue shift) and listed in report.warnings.
-- A kind can be pinned by hand through OVERRIDES (hex string per kind).
--
-- A token is a type plus modifiers; clangd additionally reports scope modifiers
-- (globalScope, fileScope, classScope, functionScope). RULES is ordered, first match
-- wins. Resolution happens here instead of through @lsp.typemod.* groups because all
-- typemod groups share one priority, so combinations such as `static const` would
-- resolve arbitrarily.
-- Application uses vim.lsp.semantic_tokens.highlight_token(), the hook Nvim documents
-- for custom token colours (`:h lsp-semantic-highlighting`).

local M = {}

--------------------------------------------------------------------------------
-- colour maths lives in lua/utils/color.lua (sRGB <-> OKLab/OKLCH, contrast,
-- hex/xterm conversions); clamp comes from lua/utils/math.lua
--------------------------------------------------------------------------------

local color = require "utils.color"
local clamp = require("utils.math").clamp

local relative_luminance = color.relative_luminance
local rgb_to_oklab = color.rgb_to_oklab
local lab_to_lch = color.lab_to_lch
local lab_dist = color.lab_dist
local lch_to_rgb = color.lch_to_rgb
local contrast_ratio = color.contrast_ratio
local hex = color.hex
local rgb_from_hex = color.rgb_from_hex
local number_to_rgb = color.number_to_rgb
local xterm256 = color.xterm256

--------------------------------------------------------------------------------
-- reading the active colourscheme
--------------------------------------------------------------------------------

--- fg/bg of a highlight group, following links; nil when the theme defines none
local function group_attr(name, key)
  local seen = {}
  while name and not seen[name] do
    seen[name] = true
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    if type(hl[key]) == "number" then
      return number_to_rgb(hl[key])
    end
    if type(hl["cterm" .. key]) == "number" then
      return xterm256(hl["cterm" .. key])
    end
    name = vim.api.nvim_get_hl(0, { name = name, link = true }).link
  end
end

--- text/syntax colours the derived palette has to stay clear of
local STRICT_GROUPS = {
  "Normal",
  "Directory",
  "Title",
  "Identifier",
  "Function",
  "Type",
  "Constant",
  "String",
  "Statement",
  "Keyword",
  "PreProc",
  "Special",
  "Comment",
  "Number",
  "Boolean",
  "Conditional",
  "Structure",
  "Todo",
  "Error",
  "ErrorMsg",
  "WarningMsg",
  "Search",
  "MatchParen",
}

--- structural/diagnostic colours: avoided with a smaller margin, since they show up
--- in gutters and underlines rather than as identifier text
local SOFT_GROUPS = {
  "NonText",
  "SpecialKey",
  "DiagnosticError",
  "DiagnosticWarn",
  "DiagnosticInfo",
  "DiagnosticHint",
}

local REF_GROUPS = { "Identifier", "@variable", "Function", "@function", "Normal" }
local DEFAULT_BG = { 28, 28, 28 }
local DEFAULT_FG = { 199, 199, 199 }

local function theme_state()
  local anchors, ref = {}, nil
  for _, group_set in ipairs { { STRICT_GROUPS, false }, { SOFT_GROUPS, true } } do
    for _, name in ipairs(group_set[1]) do
      local rgb = group_attr(name, "fg")
      if rgb then
        anchors[#anchors + 1] = { name = name, lab = rgb_to_oklab(rgb), soft = group_set[2] }
      end
    end
  end
  for _, name in ipairs(REF_GROUPS) do
    ref = ref or group_attr(name, "fg")
  end
  return {
    anchors = anchors,
    bg = group_attr("Normal", "bg") or (vim.o.background == "light" and { 255, 255, 255 } or DEFAULT_BG),
    ref = ref or DEFAULT_FG,
  }
end

--------------------------------------------------------------------------------
-- the ten kinds and how tokens map onto them
--------------------------------------------------------------------------------

--- order defines hue assignment (spread out with a stride, see derive())
local KINDS = {
  { kind = "local", group = "SemanticVarLocal" }, -- local variables
  { kind = "local_const", group = "SemanticConstLocal" }, -- const/readonly locals
  { kind = "parameter", group = "SemanticVarParameter" }, -- parameters
  { kind = "parameter_const", group = "SemanticConstParameter" }, -- const/readonly parameters
  { kind = "member", group = "SemanticVarMember" }, -- data members (obj.field, this->field)
  { kind = "member_const", group = "SemanticConstMember" }, -- const data members
  { kind = "static", group = "SemanticVarStatic" }, -- static storage (members, file statics, static locals)
  { kind = "global", group = "SemanticVarGlobal" }, -- globals with external linkage
  { kind = "enum_member", group = "SemanticVarEnum" }, -- enumerators
  { kind = "type_param", group = "SemanticVarTypeParam" }, -- template/type parameters
}

--- types = LSP semantic token types, mods = modifiers that must all be present
--- (absent = any). First matching row wins, so narrower rows come first.
local RULES = {
  { kind = "parameter_const", types = { "parameter" }, mods = { "readonly" } },
  { kind = "parameter", types = { "parameter" } },
  { kind = "enum_member", types = { "enumMember" } },
  { kind = "type_param", types = { "typeParameter" } },
  { kind = "local_const", types = { "variable" }, mods = { "readonly" } },
  { kind = "static", types = { "variable" }, mods = { "static" } },
  { kind = "static", types = { "variable" }, mods = { "fileScope" } },
  { kind = "member_const", types = { "property" }, mods = { "readonly" } },
  { kind = "member", types = { "property" } },
  { kind = "member", types = { "variable" }, mods = { "classScope" } },
  { kind = "global", types = { "variable" }, mods = { "globalScope" } },
  { kind = "local", types = { "variable" } },
}

--- pin a kind to a fixed colour, e.g. { global = "#ff0000" }; everything else
--- is derived and then keeps clear of the pinned colours as well
local OVERRIDES = {}

local GROUP_OF = {}
for _, kind in ipairs(KINDS) do
  GROUP_OF[kind.kind] = kind.group
end

--------------------------------------------------------------------------------
-- palette derivation
--------------------------------------------------------------------------------

local HUE_STRIDE = 3 -- co-prime stride: related kinds do not end up next to each other
local ANCHOR_TARGET = 0.075 -- OKLab distance aimed for against text/syntax colours
local SOFT_TARGET = 0.050 -- ... and against structural/diagnostic colours
local SOFT_SLACK = ANCHOR_TARGET - SOFT_TARGET
local MUTUAL_TARGET = 0.060 -- ... and between the derived colours themselves
local MIN_CONTRAST = 4.5
local SCAN_STEP = 5 -- hue degrees between candidates while searching for room
local CHROMA_STEPS = { 1.0, 0.7 } -- chroma fallbacks tried per candidate hue
local CHROMA_FLOOR = 0.105 -- palette colours stay recognisably colourful, not pastel
local LIFTS = { 0.00, 0.06, -0.06, 0.03, -0.03, 0.05, -0.05, 0.02, -0.02, 0.04 }

local function angle_delta(a, b)
  local d = math.abs((a - b) % 360)
  return math.min(d, 360 - d)
end

--- rotation of the even hue wheel that sits farthest from the theme's own hues
local function choose_base(used_hues, count)
  local step = 360 / count
  local best_base, best_score = 0, -1
  for base = 0, 359 do
    local score = math.huge
    for i = 0, count - 1 do
      local hue = (base + i * step) % 360
      for _, used in ipairs(used_hues) do
        score = math.min(score, angle_delta(hue, used))
      end
    end
    if score > best_score then
      best_base, best_score = base, score
    end
  end
  return best_base
end

--- nearest strict and soft anchor distances for a candidate colour
local function anchor_distances(lab, anchors)
  local strict, strict_name, soft, soft_name = math.huge, nil, math.huge, nil
  for _, anchor in ipairs(anchors) do
    local d = lab_dist(lab, anchor.lab)
    if anchor.soft then
      if d < soft then
        soft, soft_name = d, anchor.name
      end
    elseif d < strict then
      strict, strict_name = d, anchor.name
    end
  end
  return strict, strict_name, soft, soft_name
end

local function min_mutual_distance(lab, taken)
  local best = math.huge
  for _, other in ipairs(taken) do
    best = math.min(best, lab_dist(lab, other.lab))
  end
  return best
end

--- how much room a candidate colour has: distance to the nearest theme colour
--- (soft colours count as if they were SOFT_SLACK farther away) and to the colours
--- already assigned
local function room(lab, anchors, taken)
  local strict, strict_name, soft, soft_name = anchor_distances(lab, anchors)
  local mutual = min_mutual_distance(lab, taken)
  local score = math.min(strict, soft + SOFT_SLACK, mutual)
  return score, strict, strict_name, soft, soft_name, mutual
end

--- derives the ten colours for the active colourscheme
--- @return table<string,string> palette, table report
local function derive()
  local theme = theme_state()
  local bg_lum = relative_luminance(theme.bg)
  local dark = bg_lum < 0.5
  local l_lo, l_hi = dark and 0.64 or 0.24, dark and 0.90 or 0.58
  -- keep the band inside what MIN_CONTRAST allows against this background:
  -- for greys OKLab L is very close to luminance^(1/3), so the contrast limit
  -- can be turned into an L limit
  if dark then
    l_lo = math.max(l_lo, (MIN_CONTRAST * (bg_lum + 0.05) - 0.05) ^ (1 / 3) + 0.02)
  else
    l_hi = math.min(l_hi, math.max(0.18, ((bg_lum + 0.05) / MIN_CONTRAST - 0.05) ^ (1 / 3) - 0.02))
  end
  if l_hi - l_lo < 0.05 then
    l_lo, l_hi = (l_lo + l_hi) / 2 - 0.025, (l_lo + l_hi) / 2 + 0.025
  end

  local used_hues = {}
  for _, anchor in ipairs(theme.anchors) do
    local _, chroma, hue = lab_to_lch(anchor.lab)
    if chroma > 0.025 then
      used_hues[#used_hues + 1] = hue
    end
  end

  local ref_l, ref_c = lab_to_lch(rgb_to_oklab(theme.ref))
  local l_base = clamp(ref_l, l_lo, l_hi)
  local c_base = clamp(math.max(ref_c * 1.7, CHROMA_FLOOR), 0.06, 0.17)
  local base = choose_base(used_hues, #KINDS)
  local step = 360 / #KINDS

  local palette, report = {}, {}
  local taken = {}
  for i, kind in ipairs(KINDS) do
    local pinned = OVERRIDES[kind.kind] and rgb_from_hex(OVERRIDES[kind.kind])
    if pinned then
      palette[kind.kind] = hex(pinned)
      taken[#taken + 1] = { name = kind.kind, lab = rgb_to_oklab(pinned) }
      report[kind.kind] = { hex = hex(pinned), pinned = true }
    else
      -- ideal slot: even wheel position (strided so related kinds are far apart)
      local ideal = (base + ((i - 1) * HUE_STRIDE % #KINDS) * step) % 360
      local lift = LIFTS[(i - 1) % #LIFTS + 1]
      -- scan the wheel (and a few lightness offsets) for the slot with the most
      -- room; among equal scores the hue closest to the ideal slot wins
      local l_variants = dark and { 0, 0.05, 0.10 } or { 0, -0.05, -0.10 }
      local best
      for l_step, l_offset in ipairs(l_variants) do
        local l = clamp(l_base + lift + l_offset, l_lo, l_hi)
        for hue_step = 0, 360 / SCAN_STEP - 1 do
          local hue = (ideal + hue_step * SCAN_STEP) % 360
          for chroma_step, multiplier in ipairs(CHROMA_STEPS) do
            local rgb = lch_to_rgb(l, c_base * multiplier, hue)
            local contrast = contrast_ratio(rgb, theme.bg)
            if contrast >= MIN_CONTRAST then
              local lab = rgb_to_oklab(rgb)
              local score, anchor_dist, nearest, soft_dist, soft_nearest, mutual_dist =
                room(lab, theme.anchors, taken)
              score = score - hue_step * 0.00005 - (chroma_step - 1) * 0.0005 - (l_step - 1) * 0.001
              if not best or score > best.score then
                best = {
                  rgb = rgb,
                  lab = lab,
                  anchor_dist = anchor_dist,
                  nearest = nearest,
                  soft_dist = soft_dist,
                  soft_nearest = soft_nearest,
                  mutual_dist = mutual_dist,
                  contrast = contrast,
                  hue_step = hue_step,
                  chroma = c_base * multiplier,
                  l = l,
                  score = score,
                }
              end
            end
          end
        end
      end
      if not best then -- crowded theme: fall back to the ideal slot, best effort
        local l = clamp(l_base + lift, l_lo, l_hi)
        local rgb = lch_to_rgb(l, c_base, ideal)
        local lab = rgb_to_oklab(rgb)
        local anchor_dist, nearest, soft_dist, soft_nearest = anchor_distances(lab, theme.anchors)
        best = {
          rgb = rgb,
          lab = lab,
          anchor_dist = anchor_dist,
          nearest = nearest,
          soft_dist = soft_dist,
          soft_nearest = soft_nearest,
          mutual_dist = min_mutual_distance(lab, taken),
          contrast = contrast_ratio(rgb, theme.bg),
          hue_step = 0,
          chroma = c_base,
          l = l,
        }
      end
      palette[kind.kind] = hex(best.rgb)
      taken[#taken + 1] = { name = kind.kind, lab = best.lab }
      report[kind.kind] = {
        hex = palette[kind.kind],
        anchor_dist = best.anchor_dist,
        nearest = best.nearest,
        soft_dist = best.soft_dist,
        soft_nearest = best.soft_nearest,
        mutual_dist = best.mutual_dist,
        contrast = best.contrast,
        hue_shift = best.hue_step * SCAN_STEP,
        chroma = best.chroma,
        lightness = best.l,
      }
    end
  end

  local warnings = {}
  for _, kind in ipairs(KINDS) do
    local entry = report[kind.kind]
    if entry.anchor_dist and entry.anchor_dist < ANCHOR_TARGET then
      warnings[#warnings + 1] =
        string.format("%s %.3f from %s", kind.kind, entry.anchor_dist, entry.nearest or "?")
    end
    if entry.soft_dist and entry.soft_dist < SOFT_TARGET then
      warnings[#warnings + 1] =
        string.format("%s %.3f from %s (soft)", kind.kind, entry.soft_dist, entry.soft_nearest or "?")
    end
  end
  report.warnings = warnings

  report.bg = hex(theme.bg)
  report.reference = hex(theme.ref)
  report.background = dark and "dark" or "light"
  return palette, report
end

--------------------------------------------------------------------------------
-- token -> kind, and applying the colours
--------------------------------------------------------------------------------

local function resolve(token)
  for _, rule in ipairs(RULES) do
    if vim.tbl_contains(rule.types, token.type) then
      local matched = true
      for _, mod in ipairs(rule.mods or {}) do
        if not (token.modifiers or {})[mod] then
          matched = false
          break
        end
      end
      if matched then
        return rule.kind
      end
    end
  end
end

local last_palette, last_report = {}, {}

local function apply()
  last_palette, last_report = derive()
  for _, kind in ipairs(KINDS) do
    vim.api.nvim_set_hl(0, kind.group, { fg = last_palette[kind.kind] })
  end
end

local augroup = vim.api.nvim_create_augroup("SemanticTokenColors", { clear = true })

vim.api.nvim_create_autocmd("LspTokenUpdate", {
  group = augroup,
  callback = function(ev)
    local kind = resolve(ev.data.token)
    if kind then
      vim.lsp.semantic_tokens.highlight_token(ev.data.token, ev.buf, ev.data.client_id, GROUP_OF[kind])
    end
  end,
})

-- a colourscheme switch resets every highlight group *and* changes the palette.
-- VimEnter as well: a theme applied from inside another autocommand (e.g. themery restoring the
-- saved colourscheme while lazy.nvim's VimEnter handler loads it) fires no ColorScheme event --
-- nested autocommands are suppressed -- so the palette would stay derived from the scheme that
-- was active when this module loaded.
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, { group = augroup, callback = apply })

apply()

M.apply = apply
M.derive = derive
M.resolve = resolve
M.kinds = KINDS
M.rules = RULES
M.overrides = OVERRIDES
M.state = function()
  return last_palette, last_report
end

return M
