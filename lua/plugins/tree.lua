return {
  "nvim-tree/nvim-tree.lua",
  cmd = { "NvimTreeToggle", "NvimTreeFocus" },
  opts = function()
    return require "nvchad.configs.nvimtree"
  end,
  config = function()
    require "nvim-tree".setup({
      filters = {
        dotfiles = false
      },
      view = {
        width = 40
      }
    })
  end
}
