require "nvchad.options"

-- add yours here!

-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!
vim.o.relativenumber = true

if vim.g.neovide == true then
	vim.g.neovide_cursor_vfx_mode = "torpedo"
	vim.g.neovide_refresh_rate = 144
	vim.g.neovide_transparency = 0.98
	vim.o.guifont = "JetBrainsMono Nerd Font"
end

