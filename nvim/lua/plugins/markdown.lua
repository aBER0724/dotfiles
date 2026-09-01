return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "markdown", "markdown_inline", "latex" } },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "Avante" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-mini/mini.icons",
    },
    opts = {
      latex = {
        enabled = true,
        converter = {
          "utftex",
          "latex2text",
          vim.fn.expand("~/Library/Python/3.13/bin/latex2text"),
        },
        inline = true,
        block = true,
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
  {
    "iamcco/markdown-preview.nvim",
    enabled = false,
  },
  {
    "OXY2DEV/markview.nvim",
    enabled = false,
  },
  {
    "jbyuki/nabla.nvim",
    enabled = false,
  },
}
