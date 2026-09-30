return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  branch = "main",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup {}

    -- base parser set; more via :TSInstall
    -- markdown/markdown_inline for render-markdown.nvim, regex/bash for noice.nvim
    require("nvim-treesitter").install {
      "lua",
      "luadoc",
      "printf",
      "vim",
      "vimdoc",
      "markdown",
      "markdown_inline",
      "regex",
      "bash",
    }

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
