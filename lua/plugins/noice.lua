return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    lsp = {
      -- none-ls (cspell) re-announces every diagnostics run as LSP progress (begin/report/end),
      -- which noice's mini view renders as a "diagnostics null-ls" popup on every edit/save.
      -- With this off, Nvim's default handler keeps the raw progress and noice stops drawing it.
      progress = { enabled = false },
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
    },
    presets = {
      bottom_search = true,
      command_palette = true,
      long_message_to_split = true,
    },
    -- search tip cards (configs/searchTips.lua) get a popup instead of a mini badge
    routes = {
      {
        filter = { find = "Search tip" },
        view = "popup",
        opts = {
          enter = false, -- never steal focus from the / prompt
          timeout = 8000,
          format = { "{message}" }, -- skip the "{level}" prefix (icon + "Info")
          size = { width = "auto", height = "auto", max_width = 52, max_height = 6 },
          position = { row = 2, col = "50%" },
          border = { style = "rounded", padding = { 0, 1 } },
        },
      },
    },
    views = {
      mini = { timeout = 10000 },
    },
  },
}
