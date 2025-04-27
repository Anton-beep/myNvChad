return {
  "nvim-treesitter/nvim-treesitter",
  auto_install = true,
  config = function()
    pcall(function()
      dofile(vim.g.base46_cache .. "syntax")
      dofile(vim.g.base46_cache .. "treesitter")
    end)

    require("nvim-treesitter.configs").setup {
      ensure_installed = { "lua", "luadoc", "printf", "vim", "vimdoc" },
      auto_install = true,
      highlight = {
        enable = true,
        use_languagetree = true,
      },
      indent = { enable = true },
    }
  end,
}
