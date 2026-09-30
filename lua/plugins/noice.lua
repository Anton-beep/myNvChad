return {
  "folke/noice.nvim",
  -- replaces the UI for the cmdline, messages and the completion popup;
  -- VeryLazy keeps it off the startup path while still catching later output
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    lsp = {
      -- render markdown in hover docs, signature help and cmp documentation
      -- through treesitter instead of plain text
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
    },
    presets = {
      bottom_search = true, -- classic cmdline at the bottom for / and ?
      command_palette = true, -- cmdline and completion popup sit together
      long_message_to_split = true, -- long messages open in a split
    },
    views = {
      -- notifications are drawn by the mini view here (views.notify tries the snacks/nvim-notify
      -- backends first and both are absent), so this is the knob that decides how long they stay.
      -- 10 s instead of the 2 s default, which was gone before it could be read.
      mini = { timeout = 10000 },
    },
  },
}
