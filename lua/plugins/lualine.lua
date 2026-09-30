return {
  "nvim-lualine/lualine.nvim",
  -- statusline plugin: must be loaded at startup (defaults.lazy = true would
  -- otherwise keep it unloaded, since it has no lazy-load trigger)
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = {
      theme = "auto",
      -- options.lua sets laststatus=3 (single global statusline)
      globalstatus = true,
    },
  },
}
