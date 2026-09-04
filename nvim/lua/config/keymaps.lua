-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Save: Ctrl-S (all modes) and <leader>w
map({ "n", "i", "v", "s" }, "<C-s>", "<cmd>write<cr><esc>", { desc = "Save file" })
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })

-- Yank to end of line instead of whole line (consistent with D and C)
-- macOS copy: Kitty encodes Cmd-C as CSI 99;9u
map("x", "<D-c>", '"+y', { desc = "Copy Selection to System Clipboard" })

map("n", "Y", "y$", { desc = "Yank to End of Line" })

-- Redo with capital U (mirrors undo)
map("n", "U", "<cmd>redo<cr>", { desc = "Redo" })

-- Leave terminal mode with double-Esc (keeps single Esc for shell apps like fzf)
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Enter Normal Mode" })

-- Center the screen when jumping
map({ "n", "x" }, "<C-d>", "<C-d>zz", { desc = "Half Page Down (center)" })
map({ "n", "x" }, "<C-u>", "<C-u>zz", { desc = "Half Page Up (center)" })
map("n", "n", "nzzzv", { desc = "Next Search Result (center)" })
map("n", "N", "Nzzzv", { desc = "Prev Search Result (center)" })

-- Resize windows evenly and toggle maximize
map("n", "<leader>w=", "<C-w>=", { desc = "Equalize Windows" })
map("n", "<leader>wm", function()
  local win = vim.api.nvim_get_current_win()
  if vim.b[win .. "_maximized"] then
    vim.api.nvim_win_call(win, function()
      vim.cmd("resize 0")
    end)
    vim.api.nvim_win_call(win, function()
      vim.cmd("vertical resize 0")
    end)
    vim.b[win .. "_maximized"] = false
  else
    vim.b[win .. "_maximized"] = true
    vim.api.nvim_win_call(win, function()
      vim.cmd("resize 999")
    end)
    vim.api.nvim_win_call(win, function()
      vim.cmd("vertical resize 999")
    end)
  end
end, { desc = "Toggle Maximize Window" })

-- Quickfix navigation aliases
map("n", "[x", vim.cmd.cprev, { desc = "Prev Quickfix" })
map("n", "]x", vim.cmd.cnext, { desc = "Next Quickfix" })

-- Select all
map("n", "<leader>sa", "ggVG", { desc = "Select All" })