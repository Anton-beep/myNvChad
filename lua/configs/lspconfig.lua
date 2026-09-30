local servers = require "configs.lspServers"
local map = vim.keymap.set

-- diagnostic display (inlined from the previous diagnostic config)
local x = vim.diagnostic.severity

vim.diagnostic.config {
  virtual_text = { prefix = "" },
  signs = {
    text = {
      [x.ERROR] = "",
      [x.WARN] = "",
      [x.INFO] = "",
      [x.HINT] = "",
    },
  },
  underline = true,
  float = { border = "single" },
}

local on_attach = function(_, bufnr)
  local function opts(desc)
    return { buf = bufnr, desc = "LSP " .. desc }
  end

  map("n", "gD", vim.lsp.buf.declaration, opts "Go to declaration")
  map("n", "gd", vim.lsp.buf.definition, opts "Go to definition")
  map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, opts "Add workspace folder")
  map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts "Remove workspace folder")

  map("n", "<leader>wl", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, opts "List workspace folders")

  map("n", "<leader>D", vim.lsp.buf.type_definition, opts "Go to type definition")
  map("n", "<leader>ra", vim.lsp.buf.rename, opts "Rename")
end

local capabilities = vim.lsp.protocol.make_client_capabilities()

capabilities.textDocument.completion.completionItem = {
  documentationFormat = { "markdown", "plaintext" },
  snippetSupport = true,
  preselectSupport = true,
  insertReplaceSupport = true,
  labelDetailsSupport = true,
  deprecatedSupport = true,
  commitCharactersSupport = true,
  tagSupport = { valueSet = { 1 } },
  resolveSupport = {
    properties = {
      "documentation",
      "detail",
      "additionalTextEdits",
    },
  },
}

-- Semantic tokens: keep the capability from make_client_capabilities() above, which carries the
-- token type and modifier lists a server needs. (vim.lsp.protocol.SemanticTokenTypes and
-- .SemanticTokenModifiers no longer exist in 0.12 -- assigning them left both fields nil and
-- replaced the complete capability with an incomplete one.)
capabilities.textDocument.semanticTokens.dynamicRegistration = false

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    on_attach(nil, args.buf)
  end,
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = {
        library = {
          vim.fn.expand "$VIMRUNTIME/lua",
          vim.fn.stdpath "data" .. "/lazy/lazy.nvim/lua/lazy",
          "${3rd}/luv/library",
        },
      },
    },
  },
})

-- lsps with default config
for _, server_list in pairs(servers) do
  for _, lsp in ipairs(server_list) do
    vim.lsp.config(lsp, {
      capabilities = capabilities,
    })

    vim.lsp.enable(lsp)
  end
end
