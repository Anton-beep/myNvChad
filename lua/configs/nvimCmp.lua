local config = require "nvchad.configs.cmp"
local cmp = require "cmp"

config.mapping["<CR>"] = cmp.mapping.confirm {
  behavior = cmp.ConfirmBehavior.Insert,
  select = false,
}

config.completion = {
  completeopt = "menu,menuone,noselect"
}

config.preselect = cmp.PreselectMode.None

config.mapping["<Tab>"] = cmp.mapping(function(fallback)
  if cmp.visible() then
    cmp.select_next_item()
  elseif require("luasnip").expand_or_jumpable() then
    -- require("luasnip").expand_or_jump() For some reason this things breaks normal tabs in insert mode
    fallback()
  else
    fallback()
  end
end, { "i", "s" })

return config
