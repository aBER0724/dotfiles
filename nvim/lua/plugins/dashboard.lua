return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = io.open(vim.fn.stdpath("config") .. "/kuuga.txt"):read("*a"),
        },
      },
    },
  },
}
