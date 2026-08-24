return {
  "mrjones2014/smart-splits.nvim",
  lazy = false, -- 建议直接加载以接管窗口逻辑
  opts = {
    -- 这里可以添加自定义配置，默认通常就够用了
  },
  keys = {
    -- 1. 连续调整窗口大小 (Alt + h/j/k/l)
    {
      "<A-h>",
      function()
        require("smart-splits").resize_left()
      end,
      desc = "向左调宽",
    },
    {
      "<A-j>",
      function()
        require("smart-splits").resize_down()
      end,
      desc = "向下调高",
    },
    {
      "<A-k>",
      function()
        require("smart-splits").resize_up()
      end,
      desc = "向上调高",
    },
    {
      "<A-l>",
      function()
        require("smart-splits").resize_right()
      end,
      desc = "向右调宽",
    },

    -- 2. 在窗口间跳转 (Ctrl + h/j/k/l)
    -- 注意：LazyVim 默认已经有 Ctrl+hjkl 跳转，如果你想用 smart-splits 接管（它更智能），可以取消注释
    -- { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "跳到左侧窗口" },
    -- { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "跳到下方窗口" },
    -- { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "跳到上方窗口" },
    -- { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "跳到右侧窗口" },
  },
}
