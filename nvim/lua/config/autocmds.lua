-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Reload the generated palette whenever nbshell switches themes.
local palette_path = vim.fn.expand("~/.config/nbshell/palette.sh")
local palette_mtime = 0
local function reload_nbshell_palette()
  local stat = vim.uv.fs_stat(palette_path)
  local mtime = stat and stat.mtime and stat.mtime.sec or 0
  if mtime ~= palette_mtime then
    palette_mtime = mtime
    if vim.g.colors_name == "nbshell" then
      vim.schedule(function()
        vim.cmd.colorscheme("nbshell")
        vim.cmd.redraw()
      end)
    end
  end
end

-- libuv directory watches can miss an atomic rename on some filesystems; the
-- timer is cheap and makes live updates deterministic for long-running Nvim.
local palette_timer = vim.uv.new_timer()
if palette_timer then
  palette_timer:start(500, 500, vim.schedule_wrap(reload_nbshell_palette))
  _G.nbshell_palette_timer = palette_timer
end
