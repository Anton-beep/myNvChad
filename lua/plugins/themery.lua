return {
  "zaldih/themery.nvim",
  event = "VimEnter",
  cmd = { "Themery" },
  config = function()
    vim.schedule(function()
      require("themery").setup {
        themes = vim.fn.getcompletion("", "color"),
        livePreview = true,
      }
    end)
  end,
}
