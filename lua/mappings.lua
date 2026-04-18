require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

map("i", "<C-l>", function()
  vim.fn.feedkeys(vim.fn["copilot#Accept"](), "")
end, { desc = "Copilot Accept", noremap = true, silent = true })

map("n", "sh", ":split<CR>", { desc = "Split Horizontal", noremap = true, silent = true })
map("n", "sv", ":vsplit<CR>", { desc = "Split Vertical", noremap = true, silent = true })

-- refresh tree when focus
map("n", "<leader>e", function()
  vim.cmd "NvimTreeFocus"
  vim.cmd "NvimTreeRefresh"
end, { desc = "nvimtree focus window" })

map({ "n", "x" }, "<leader>oa", function() require("opencode").ask("@this: ", { submit = true }) end,
  { desc = "Ask opencode…" })
map({ "n", "x" }, "<leader>ox", function() require("opencode").select() end, { desc = "Execute opencode action…" })
map({ "n", "t" }, "<leader>ot", function() require("opencode").toggle() end, { desc = "Toggle opencode" })

map("n", "<leader>ou", function() require("opencode").command("session.half.page.up") end, { desc = "Scroll opencode up" })
map("n", "<leader>od", function() require("opencode").command("session.half.page.down") end,
  { desc = "Scroll opencode down" })

