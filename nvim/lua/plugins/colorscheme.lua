-- Use the dynamic nbshell colorscheme when its palette exists (Arch/niri box),
-- otherwise fall back to tokyonight so nvim still starts cleanly on macOS.
local palette_path = vim.fn.expand("~/.config/nbshell/palette.sh")
local colorscheme = vim.uv.fs_stat(palette_path) and "nbshell" or "tokyonight"

return {
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = colorscheme },
  },
}