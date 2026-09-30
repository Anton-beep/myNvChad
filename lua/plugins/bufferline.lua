return {
  "akinsho/bufferline.nvim",
  -- the plugin suggests tracking a release tag (main can be unreleased); the lockfile
  -- still pins the exact commit
  version = "*",
  -- tabline chrome: load at startup, otherwise defaults.lazy = true keeps it unloaded
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = {
      mode = "buffers",
      -- show LSP diagnostics per buffer: errors and warnings only, so lua_ls hints and
      -- cspell spelling notes do not clutter the tabline
      diagnostics = "nvim_lsp",
      diagnostics_indicator = function(_, _, errors)
        local icons = { error = "\u{ea87}", warning = "\u{ea6c}" }
        local parts = {}
        for _, level in ipairs { "error", "warning" } do
          local count = errors and errors[level]
          if count and count > 0 then
            parts[#parts + 1] = string.format("%s %d", icons[level], count)
          end
        end
        return table.concat(parts, " ")
      end,
      -- keep the tabline out of the nvim-tree window
      offsets = {
        {
          filetype = "NvimTree",
          text = "File Explorer",
          text_align = "left",
          separator = true,
        },
      },
      show_buffer_icons = true,
      show_buffer_close_icons = true,
      show_close_icon = false,
      -- closing a tab (close icon, right click) must not close the window that showed the
      -- buffer; see lua/configs/bufferClose.lua
      close_command = function(bufnr) require("configs.bufferClose").close_tab(bufnr) end,
      right_mouse_command = function(bufnr) require("configs.bufferClose").close_tab(bufnr) end,
    },
  },
}
