-- LazyVim now uses Snacks Explorer by default. Keep Neo-tree disabled so directory
-- startup and restored sessions cannot create a second, independently toggled tree.
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    enabled = false,
  },
}
