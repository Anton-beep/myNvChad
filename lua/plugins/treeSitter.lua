return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  branch = "main",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup {}

    -- base parser set; more via :TSInstall
    require("nvim-treesitter").install { "lua", "luadoc", "printf", "vim", "vimdoc" }

    -- enable highlighting when a parser is available
    -- (replaces the FileType hook the old config provided)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "*",
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
