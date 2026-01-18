local registry = require("mason-registry")
local filetype_tools = require("configs.lspServers")

local function resolve_mason_name(tool_name)
  -- Try to load mason-lspconfig to get the mapping
  local lspsToPackages = require("mason-lspconfig").get_mappings()

  local mapped_name = lspsToPackages.lspconfig_to_package[tool_name]

  if mapped_name then
    return mapped_name
  end

  return tool_name
end

local function ensure_installed(original_name)
  local mason_name = resolve_mason_name(original_name)

  -- Safety check: Ensure the package exists in the registry
  if not registry.has_package(mason_name) then
    vim.notify(
      string.format("[Lazy Install LSP] Package '%s' not found.", mason_name),
      vim.log.levels.ERROR
    )

    return
  end

  local pkg = registry.get_package(mason_name)


  if pkg:is_installed() or pkg:is_installing() then
    return
  end

  vim.notify(string.format("[Lazy Install LSP] Installing '%s'...", mason_name), vim.log.levels.INFO)

  pkg:install():once("closed", function()
    if pkg:is_installed() then
      vim.schedule(function()
        vim.notify(string.format("[Lazy Install LSP] '%s' installed. Reloading...", mason_name), vim.log.levels.INFO)
        vim.cmd("edit")
      end)
    end
  end)
end

local ignored_filtypes = {
  lazy = true,
  mason = true,
  NvimTree = true,
}

vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    if ignored_filtypes[vim.bo.filetype] then
      return
    end

    local tools = filetype_tools[vim.bo.filetype]

    if not tools then
      vim.notify(
        string.format("[Lazy Install LSP] No tools configured for filetype '%s'", vim.bo.filetype),
        vim.log.levels.INFO
      )
      return
    end

    if tools then
      for _, tool in ipairs(tools) do
        ensure_installed(tool)
      end
    end
  end,
})
