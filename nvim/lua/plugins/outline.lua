return {
  {
    "hedyhli/outline.nvim",
    cmd = { "Outline", "OutlineOpen" },
    keys = {
      { "<leader>co", "<cmd>Outline<cr>", desc = "Toggle Code Outline" },
    },
    opts = {
      -- Prefer Outline's built-in Markdown parser so every heading is included,
      -- even when a Markdown LSP returns only a partial symbol list.
      providers = {
        priority = { "markdown", "lsp", "coc", "norg", "man" },
      },
      symbols = {
        -- Outline reports every Markdown heading as String. Read the source line
        -- so headings can still use the matching H1-H6 Nerd Font icon.
        icon_fetcher = function(kind, bufnr, symbol)
          if kind == "String" and vim.bo[bufnr].filetype == "markdown" and symbol then
            local range = symbol.selectionRange or symbol.range
            local line_nr = range and range.start and range.start.line
            if line_nr then
              local line = vim.api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, false)[1] or ""
              local hashes = line:match("^%s*(#+)%s+")
              if hashes then
                local heading_icons = { "󰉫", "󰉬", "󰉭", "󰉮", "󰉯", "󰉰" }
                return heading_icons[math.min(#hashes, #heading_icons)]
              end
            end
          end
          return false
        end,
        icons = {
          String = { icon = "󰙅", hl = "Identifier" },
        },
      },
      -- Start with the complete TOC expanded and do not immediately reopen a
      -- node just because the cursor moved onto it.
      symbol_folding = {
        autofold_depth = false,
        auto_unfold = {
          hovered = false,
          only = false,
        },
      },
      keymaps = {
        -- Use o as the intuitive open/close action; p retains the old peek action.
        fold_toggle = "o",
        peek_location = "p",
      },
    },
  },
}
