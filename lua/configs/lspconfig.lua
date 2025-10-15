-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local servers = require "configs.lspServers"
local nvlsp = require "nvchad.configs.lspconfig"

-- lsps with default config
for _, lsp in ipairs(servers) do
  vim.lsp.config(lsp, {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  })
  vim.lsp.enable(lsp)
end

-- configuring single server, example: typescript
