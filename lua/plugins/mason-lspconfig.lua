return {
  "mason-org/mason-lspconfig.nvim",
  config = function()
    require("mason-lspconfig").setup({
      ensure_installed = require("configs.lspServers"),
    })
  end,
}

