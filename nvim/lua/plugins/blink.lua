-- blink.cmp (LazyVim v16 default completion) comfort tweaks
-- Fix: typing no longer auto-inserts the highlighted candidate into your text.
-- Default `auto_insert = true` made the popup "complete" words for you and
-- forced ESC to get out of it. With this off, the menu only *shows* options;
-- you accept explicitly with <Tab>, <CR>, or <C-y> (nvim-cmp-style behavior).
return {
  {
    "saghen/blink.cmp",
    opts = {
      completion = {
        list = {
          selection = {
            auto_insert = false,
          },
        },
      },
    },
  },
}