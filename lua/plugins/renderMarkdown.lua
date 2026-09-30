return {
  "MeanderingProgrammer/render-markdown.nvim",
  -- renders markdown in place (headings, code blocks, tables, callouts, checkboxes);
  -- defaults.lazy = true would keep it unloaded, so trigger it on the filetype it renders
  ft = { "markdown" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {},
}
