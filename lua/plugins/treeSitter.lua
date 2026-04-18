return {
  "nvim-treesitter/nvim-treesitter",
  lazy = true,
  auto_install = true,
  config = function()
    pcall(function()
      dofile(vim.g.base46_cache .. "syntax")
      dofile(vim.g.base46_cache .. "treesitter")
    end)
  end,
}
