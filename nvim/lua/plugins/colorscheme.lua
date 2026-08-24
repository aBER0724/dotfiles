return {
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = { bold = true },
        variables = { italic = true },
        sidebars = "transparent",
        floats = "dark",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "solarized-osaka" },
  },
}

