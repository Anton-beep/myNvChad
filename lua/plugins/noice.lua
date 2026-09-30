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
    views = {
      mini = { timeout = 10000 },
    },
  },
}
