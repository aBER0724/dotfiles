-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/aura/packages/neovim")

vim.opt.scrolloff = 8 -- more context above/below cursor
vim.opt.sidescrolloff = 12
vim.opt.pumheight = 15 -- taller completion menu
vim.opt.swapfile = false -- undo history is enough; avoids swap prompts
vim.opt.hlsearch = false -- don't keep the last search highlighted
vim.opt.signcolumn = "yes"
vim.opt.cursorlineopt = "line"
vim.opt.smoothscroll = true
vim.opt.showtabline = 0 -- bufferline handles tabs
vim.opt.diffopt:append("vertical")

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    -- Clear background for specific highlight groups
    local groups = { "Normal", "NormalNC", "NormalFloat", "SignColumn", "StatusLine", "StatusLineNC", "CursorLine", "CursorLineNr" }
    for _, g in ipairs(groups) do
      vim.api.nvim_set_hl(0, g, { bg = "NONE", ctermbg = "NONE" })
    end
    -- Remove bg from ALL other highlight groups to enforce full transparency
    local hl = vim.api.nvim_get_hl(0, {})
    for name, _ in pairs(hl) do
      local opts = vim.api.nvim_get_hl(0, { name = name, link = false })
      if opts.bg then
        vim.api.nvim_set_hl(0, name, { bg = "NONE" })
      end
    end
  end,
})
