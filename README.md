# my nvim config

Standalone Neovim config (NvChad removed): lazy.nvim, mason + nvim-lspconfig,
nvim-cmp, treesitter (main branch), telescope, nvim-tree, gitsigns, diffview
(diffs, merge conflicts, file history),
indent-blankline, which-key, conform, none-ls (cspell), render-markdown (in-place
markdown rendering), noice (cmdline/messages/popupmenu UI), bufferline (tabline of
open buffers), milli (animated ASCII splash on a bare `nvim` start — `lights` from its
community registry), menu (volt-based popup menus, nested, keyboard or mouse).
Theme collection: base16-nvim (`:colorscheme base16-*`) with themery
as the picker (live preview, remembers the last theme). Builtin colorscheme (habamax)
until one is picked; lualine.nvim statusline.

Semantic-token highlighting (`lua/configs/semanticTokens.lua`) gives ten variable
kinds their own colours (locals, const locals, parameters, const parameters, data
members, const members, statics, globals, enum members, template parameters) while
functions, types, macros, strings and comments keep the colorscheme's colours. The
palette is derived from the active colorscheme, so switching themes re-tunes it.

# Install
## Linux
### Removing Existing nvim Config
⚠️**Please remember to save your existing nvim configuration and data if you need it.**
```shell
rm -rf ~/.config/nvim
rm -rf ~/.local/state/nvim
rm -rf ~/.local/share/nvim
```

### Clone This Configuration
```shell
git clone git@github.com:Anton-beep/myNvChad.git ~/.config/nvim
```

## Windows
### Removing Existing nvim Config
⚠️**Please remember to save your existing nvim configuration and data if you need it.**
```shell
rm -Force ~\AppData\Local\nvim
rm -Force ~\AppData\Local\nvim-data
```

### Clone This Configuration
```shell
git clone git@github.com:Anton-beep/myNvChad.git ~\AppData\Local\nvim
```
