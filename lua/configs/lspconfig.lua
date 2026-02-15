local servers = require "configs.lspServers"
local nvlsp = require "nvchad.configs.lspconfig"

local my_attach = function(client, bufnr)
  nvlsp.on_attach(client, bufnr)
end


dofile(vim.g.base46_cache .. "lsp")
require("nvchad.lsp").diagnostic_config()

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    my_attach(_, args.buf)
  end,

})

local my_capabilities = nvlsp.capabilities

my_capabilities.textDocument.semanticTokens = {
  dynamicRegistration = false,
  tokenTypes = vim.lsp.protocol.SemanticTokenTypes,
  tokenModifiers = vim.lsp.protocol.SemanticTokenModifiers,
}

-- lsps with default config
for _, lspServers in ipairs(servers) do
  for _, lsp in ipairs(lspServers) do
    local opts = {
      on_attach = my_attach,
      capabilities = my_capabilities,
    }

    vim.lsp.config(lsp, opts)
    vim.lsp.enable(lsp)
  end
end
