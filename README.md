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

# Checks
Deprecated Nvim APIs are caught by the two tools that actually know about them — nothing here keeps
its own list of deprecated functions:

- `scripts/check.sh` runs both and prints what they report:
  1. `lua-language-server --check` over this repo with the Nvim runtime as a workspace library
     (`.luarc.json`). The runtime's `@deprecated` annotations are the source of truth, so declared
     deprecations and APIs removed from Nvim (reported as undefined fields) show up with their
     replacements. `--level=Hint` widens the report to hints; the default is Warning, where
     deprecations live.
  2. this config in a headless Nvim, then `:checkhealth vim.deprecated` — Nvim's own detector for
     deprecated functions, which also catches calls no type information covers (`vim.highlight`, the
     old `vim.validate{...}` form) and prints a traceback for each. Exits 1 when either pass reports
     something.
  What neither can see, because Nvim only documents it as prose in `:h deprecated`: module aliases
  that are never warned about (`vim.loop`), renamed table keys (keymap's `buffer`), and APIs removed
  without a shim (`vim.pretty_print` is nil now, so calling it errors).
- While editing, lua_ls marks deprecated APIs (`configs/lspconfig.lua` points it at
  `$VIMRUNTIME/lua`, so it knows the runtime's annotations).
- `<leader>hd` → `:checkhealth vim.deprecated` shows what the current session has used.

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
