return {
   "mason-org/mason-lspconfig.nvim",
  opts = {
     ensure_installed = require("configs.alwaysInstalledLspServers"),
  },
  dependencies = {
    { "mason-org/mason.nvim", opts = {} },
    "neovim/nvim-lspconfig",
  },
   lazy = false,
 }
