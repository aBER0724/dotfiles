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
