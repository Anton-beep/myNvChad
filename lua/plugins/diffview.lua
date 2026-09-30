return {
  "sindrets/diffview.nvim",
  -- command-driven diff / merge / file-history UI: nothing loads until one of its commands is
  -- used (its commands are created in plugin/diffview.lua once the plugin is on the runtimepath)
  cmd = {
    "DiffviewOpen",
    "DiffviewFileHistory",
    "DiffviewClose",
    "DiffviewFocusFiles",
    "DiffviewToggleFiles",
    "DiffviewRefresh",
    "DiffviewLog",
  },
  -- optional; the file panel uses icons (use_icons defaults to true)
  dependencies = { "nvim-tree/nvim-web-devicons" },
  -- upstream defaults: diff2_horizontal layout, enhanced_diff_hl off, index watching on
  opts = {},
}
