local fk_markdown_schema_tolerances = {
  "plant_uml",
  "preview",
  "quote%.style",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "markdown", "markdown_inline", "latex" } },
  },
  {
    "the-mayankjha/fk_markdown.nvim",
    ft = { "markdown", "Avante" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-mini/mini.icons",
    },
    build = function(plugin)
      local patch = vim.fn.stdpath("config") .. "/patches/fk-markdown-inline-latex.patch"
      if vim.fn.filereadable(patch) == 0 then
        return
      end
      local check = vim.system({ "git", "apply", "--check", patch }, { cwd = plugin.dir }):wait()
      if check.code == 0 then
        local applied = vim.system({ "git", "apply", patch }, { cwd = plugin.dir }):wait()
        assert(applied.code == 0, applied.stderr)
        return
      end
      local reverse = vim.system({ "git", "apply", "--reverse", "--check", patch }, { cwd = plugin.dir }):wait()
      assert(reverse.code == 0, check.stderr)
    end,
    config = function(_, opts)
      require("fk_markdown").setup(opts)
      local state = require("fk_markdown.state")
      local original_validate = state.validate
      state.validate = function()
        local errors = original_validate()
        local filtered = {}
        for _, error in ipairs(errors) do
          local allow = false
          for _, pattern in ipairs(fk_markdown_schema_tolerances) do
            if error:match("^" .. pattern) then
              allow = true
              break
            end
          end
          if not allow then
            table.insert(filtered, error)
          end
        end
        return filtered
      end
    end,
    opts = {
      heading = {
        enabled = true,
        icon = true,
        icons = { "󰉫 ", "󰉬 ", "󰉭 ", "󰉮 ", "󰉯 ", "󰉰 " },
      },
      latex = {
        enabled = true,
        render_method = "image",
        backend = "auto",
        cache_dir = vim.fn.stdpath("cache") .. "/fk_markdown/latex",
        anticonceal = false,
        hide_on_insert = false,
        dynamic_scale = 1.0,
        image_background = "transparent",
        update_interval = 400,
        converter = { "utftex", "latex2text" },
        inline = true,
        block = true,
        highlight = "RenderMarkdownMath",
        position = "center",
        top_pad = 0,
        bottom_pad = 0,
      },
      image = {
        enabled = false,
      },
      plant_uml = {
        enabled = true,
        render_modes = true,
        server = "https://www.plantuml.com/plantuml",
        format = "png",
        render_method = "image",
        theme = "default",
        hide_on_insert = true,
        styling = {
          background = "transparent",
          border = true,
          font = nil,
          dpi = 150,
          scale = 1.0,
        },
        cache_dir = vim.fn.stdpath("cache") .. "/fk_markdown/plantuml",
        local_cmd = "plantuml",
      },
      preview = {
        enabled = false,
        auto_start = false,
        auto_close = true,
        auto_scroll = true,
        browser = "",
        browser_func = nil,
        port = nil,
        open_ip = "127.0.0.1",
        theme = "dark",
        syntax_highlight = {
          enabled = true,
          theme = "github-dark",
          colors = {},
        },
        latex = {
          enabled = true,
          code_blocks = true,
        },
        plant_uml = {
          enabled = true,
          server = "https://www.plantuml.com/plantuml",
          format = "svg",
          theme = "default",
          styling = {
            background = "transparent",
            border = true,
            scale = 1.0,
          },
        },
        keymap = {
          start = false,
          stop = false,
          toggle = false,
        },
      },
    },
    keys = {
      { "<leader>um", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle Markdown Render" },
    },
  },
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    ft = "markdown",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      legacy_commands = false,
      workspaces = {
        {
          name = "OB",
          path = vim.fn.expand("~/Documents/Obsidian/Openlist/OB"),
        },
      },
      picker = {
        name = "snacks.picker",
      },
      ui = {
        enable = false,
      },
    },
    keys = {
      { "<leader>on", "<cmd>Obsidian new<cr>", desc = "New Obsidian Note" },
      { "<leader>oo", "<cmd>Obsidian quick_switch<cr>", desc = "Open Obsidian Note" },
      { "<leader>os", "<cmd>Obsidian search<cr>", desc = "Search Obsidian Vault" },
      { "<leader>ob", "<cmd>Obsidian backlinks<cr>", desc = "Obsidian Backlinks" },
    },
  },
}
