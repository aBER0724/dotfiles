-- Snacks explorer: keep a single explorer instance.
-- LazyVim's snacks_explorer extra defines four entries:
--   <leader>e / <leader>fe -> Explorer (root dir)
--   <leader>E / <leader>fE -> Explorer (cwd)
-- The cwd variants open a SEPARATE picker instance, so you can end up with
-- two file trees side by side and <leader>e only toggles one of them.
-- Remove the cwd variants: <leader>e / <leader>fe are the only toggle.
return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>E", false },
      { "<leader>fE", false },
    },
  },
}