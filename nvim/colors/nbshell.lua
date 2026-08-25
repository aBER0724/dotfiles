-- Dynamic Neovim colorscheme generated from ~/.config/nbshell/palette.sh.
-- The file is reread whenever :colorscheme nbshell runs.
local palette_path = vim.fn.expand("~/.config/nbshell/palette.sh")
local p = {}

for _, line in ipairs(vim.fn.readfile(palette_path)) do
  local key, value = line:match("^NB_([A-Z_]+)='([^']*)'$")
  if key then
    p[key] = value
  end
end

local function color(name, fallback)
  return p[name] or fallback
end

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.g.colors_name = "nbshell"
vim.o.background = p.MODE == "light" and "light" or "dark"

local bg = color("BG", "#000000")
local bg_dark = color("BG_DARK", bg)
local bg_light = color("BG_LIGHT", bg)
local fg = color("FG", "#ffffff")
local dim = color("FG_DIM", "#808080")
local bright = color("FG_BRIGHT", fg)
local accent = color("ACCENT", color("BLUE", "#5f87ff"))
local selection = color("SELECTION", bg_light)

local function hl(group, spec)
  vim.api.nvim_set_hl(0, group, spec)
end

hl("Normal", { fg = fg, bg = bg })
hl("NormalNC", { fg = fg, bg = bg })
hl("NormalFloat", { fg = fg, bg = bg_dark })
hl("FloatBorder", { fg = accent, bg = bg_dark })
hl("CursorLine", { bg = bg_light })
hl("CursorColumn", { bg = bg_light })
hl("ColorColumn", { bg = bg_light })
hl("Visual", { bg = selection })
hl("Search", { fg = bg, bg = color("YELLOW", "#ffff00") })
hl("IncSearch", { fg = bg, bg = accent })
hl("LineNr", { fg = dim })
hl("CursorLineNr", { fg = accent, bold = true })
hl("SignColumn", { bg = bg })
hl("Folded", { fg = dim, bg = bg_light })
hl("FoldColumn", { fg = dim, bg = bg })
hl("WinSeparator", { fg = color("MUTED", dim) })
hl("StatusLine", { fg = bright, bg = bg_light })
hl("StatusLineNC", { fg = dim, bg = bg_dark })
hl("Pmenu", { fg = fg, bg = bg_dark })
hl("PmenuSel", { fg = bg, bg = accent, bold = true })
hl("PmenuSbar", { bg = bg_light })
hl("PmenuThumb", { bg = dim })
hl("TabLine", { fg = dim, bg = bg_dark })
hl("TabLineSel", { fg = bright, bg = bg_light, bold = true })
hl("TabLineFill", { bg = bg_dark })
hl("Directory", { fg = accent, bold = true })
hl("Title", { fg = accent, bold = true })
hl("Comment", { fg = dim, italic = true })
hl("Constant", { fg = color("MAGENTA", "#d787ff") })
hl("String", { fg = color("GREEN", "#87d787") })
hl("Character", { fg = color("GREEN", "#87d787") })
hl("Number", { fg = color("MAGENTA", "#d787ff") })
hl("Boolean", { fg = color("MAGENTA", "#d787ff"), bold = true })
hl("Identifier", { fg = color("CYAN", "#5fd7d7") })
hl("Function", { fg = color("BLUE", accent), bold = true })
hl("Statement", { fg = color("RED", "#ff5f87"), bold = true })
hl("Keyword", { fg = color("RED", "#ff5f87"), italic = true })
hl("Operator", { fg = color("CYAN", "#5fd7d7") })
hl("PreProc", { fg = color("YELLOW", "#ffd75f") })
hl("Type", { fg = color("YELLOW", "#ffd75f") })
hl("Special", { fg = color("MAGENTA", "#d787ff") })
hl("Underlined", { fg = accent, underline = true })
hl("Error", { fg = color("RED", "#ff5f5f"), bold = true })
hl("Todo", { fg = bg, bg = color("YELLOW", "#ffff00"), bold = true })
hl("DiagnosticError", { fg = color("RED", "#ff5f5f") })
hl("DiagnosticWarn", { fg = color("YELLOW", "#ffd75f") })
hl("DiagnosticInfo", { fg = color("BLUE", accent) })
hl("DiagnosticHint", { fg = color("CYAN", "#5fd7d7") })
hl("GitSignsAdd", { fg = color("GREEN", "#87d787") })
hl("GitSignsChange", { fg = color("YELLOW", "#ffd75f") })
hl("GitSignsDelete", { fg = color("RED", "#ff5f5f") })
hl("BufferLineBufferSelected", { fg = bright, bg = bg, bold = true })
hl("BufferLineTabSelected", { fg = bright, bg = bg, bold = true })
