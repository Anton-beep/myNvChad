return {
  "mason-org/mason-lspconfig.nvim",
  opts = {
    ensure_installed = require("configs.alwaysInstalledLspServers"),
  },
  dependencies = {
    {
      "mason-org/mason.nvim",
      opts = {
        PATH = "skip",
        ui = {
          icons = {
            package_pending = " ",
            package_installed = " ",
            package_uninstalled = " ",
          },
        },
        max_concurrent_installers = 10,
      },
    },
    "neovim/nvim-lspconfig",
  },
  lazy = false,
}
