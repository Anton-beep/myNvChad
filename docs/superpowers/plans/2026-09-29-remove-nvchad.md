# Remove NvChad Dependency — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every nvchad-origin plugin (NvChad starter, nvchad/ui, base46, volt, menu, minty) from this config, replacing load-bearing pieces with standalone plugins or inlined code. Visual details may change; core editing behavior must survive.

**Architecture:** Five incrementally-bootable tasks. First make the user's `configs/` fragments self-contained (LSP, cmp) while NvChad still boots, then add replacement plugin specs (theme, statusline, bufferline, terminals, telescope, gitsigns, …), then do the one big cutover commit that deletes `nvchad.plugins` import + `chadrc.lua`, and finally regenerate `lazy-lock.json` and verify headlessly. Every commit leaves `nvim --headless +qa` clean.

**Tech Stack:** Neovim 0.12.5, lazy.nvim (stable), nvim-cmp, nvim-lspconfig (vim.lsp.config API), nvim-treesitter **main branch (2025 rewrite — `setup()` only accepts `install_dir`; old `auto_install`/`highlight` opts are silently ignored)**, lualine, bufferline.nvim, toggleterm.nvim, echasnovski/neovim-ayu.

**Spec:** User decision from conversation (2026-09-29): "Just remove current dependency on nvchad completely, so that nvim config may change, maybe even lose some functionality. For this change create a separate branch from main and do the work there." Branch `remove-nvchad` already created from `main`.

## Global Constraints

- Work ONLY on branch `remove-nvchad` (already checked out).
- After every task, `nvim --headless +qa 2>&1` must print nothing (no errors).
- Final state: `grep -rn -e nvchad -e base46 -e chadrc -e nvconfig init.lua lua/` returns zero hits.
- Preserve user's own behavior: `<CR>` confirm `select = false`, `preselect = None`, Tab fallback (do NOT luasnip-jump on Tab), semanticTokens re-enabled, `relativenumber`, neovide settings, all `lua/plugins/*` specs the user wrote, `configs/lazyInstallLsps.lua`, `configs/lspServers.lua`, `configs/fixDockerComposeFiletype.lua`, `configs/pendulumConfig.lua`, opencode mappings.
- Do not touch `lazy-lock.json` by hand — regenerate via nvim.
- `vim.treesitter.start` must keep being hooked on FileType (this, not treesitter opts, is what enables highlighting with the rewrite).

## Verified inventory (what NvChad actually supplies here)

From reading `~/.local/share/nvim/lazy/NvChad/lua/nvchad/` (v2.5, commit d042cc97):

- `nvchad.plugins` — default spec list: plenary, base46, ui, volt, menu, minty, nvim-web-devicons (with `nvchad.icons.devicons` override), indent-blankline, nvim-tree, which-key, conform (stylua), gitsigns, mason, nvim-lspconfig, nvim-cmp (+ LuaSnip, friendly-snippets, nvim-autopairs, cmp_luasnip, cmp-nvim-lua, cmp-nvim-lsp, cmp-buffer, cmp-async-path), telescope, nvim-treesitter.
- `nvchad.options` (~57 lines), `nvchad.mappings` (~109 lines), `nvchad.autocmds` (User `FilePost` event, FileType→`vim.treesitter.start`, `TSInstallAll` cmd, editorconfig shim).
- `nvchad.configs.{cmp,lspconfig,telescope,treesitter,mason,luasnip,nvimtree,gitsigns}` — opts tables.
- From `nvchad/ui`: statusline, tabufline, NvDash (NOT enabled — `load_on_startup` commented out in chadrc and defaults to false), NvCheatsheet, term system, theme switcher, NvRenamer, `nvchad.lsp.diagnostic_config`, `nvconfig` (reads `chadrc.lua`), `colors/nvchad.lua`, telescope extensions `themes`/`terms`.
- Already-dead code (verified): `nvchad.configs.lspconfig.defaults()` is fully shadowed by user's `configs/lspconfig.lua` (its `lua_ls` workspace settings and semanticTokens-disabling `on_init` never ran); telescope `extensions_list` is consumed by nothing; treesitter `auto_install/highlight/indent` opts are ignored by the main-branch rewrite.

## Known, accepted behavior changes (user approved losing functionality)

- Theme: base46 `ayu_dark` → neovim-ayu `ayu-dark` (close palette, not identical). No transparency, no theme_toggle.
- Statusline/tabufline → lualine + bufferline.nvim (different look). Tabufline's smart `close_buffer` → plain `:bdelete`.
- NvCheatsheet grid → `:WhichKey`; NvRenamer popup → native `vim.lsp.buf.rename`.
- Toggleable terminals → toggleterm.nvim; telescope `terms` picker dropped.
- cmp entry icons (ui's `nvchad.cmp` formatting) → plain text.
- Signature help: Neovim 0.11+ ships builtin `lsp_signature` runtime plugin — nothing to configure (verify in Task 5).
- editorconfig: handled natively by 0.12; NvChad's manual shim was redundant.
- Treesitter `auto_install` no longer exists in the rewrite (the old setting was silently ignored anyway) — a base parser set installs explicitly, others via `:TSInstall`.

---

### Task 1: Standalone LSP config

**Files:**
- Modify: `lua/configs/lspconfig.lua` (full rewrite)

**Interfaces:**
- Consumes: `configs.lspServers` (unchanged), `vim.lsp.config`/`vim.lsp.enable` (0.11+ API).
- Produces: `configs.lspconfig` module with zero nvchad requires. `on_attach` maps `gD gd <leader>wa <leader>wr <leader>wl <leader>D <leader>ra` (ra now native rename); capabilities table incl. user's semanticTokens override; inlined `nvchad.lsp.diagnostic_config` body; `lua_ls` workspace settings (newly effective — they were dead before).

- [ ] **Step 1: Rewrite `lua/configs/lspconfig.lua`** with exactly:

```lua
local servers = require "configs.lspServers"
local map = vim.keymap.set

-- diagnostic display (inlined from nvchad.lsp.diagnostic_config)
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
    return { buffer = bufnr, desc = "LSP " .. desc }
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

capabilities.textDocument.semanticTokens = {
  dynamicRegistration = false,
  tokenTypes = vim.lsp.protocol.SemanticTokenTypes,
  tokenModifiers = vim.lsp.protocol.SemanticTokenModifiers,
}

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    on_attach(_, args.buf)
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
for _, lspServers in ipairs(servers) do
  for _, lsp in ipairs(lspServers) do
    vim.lsp.config(lsp, {
      on_attach = on_attach,
      capabilities = capabilities,
    })

    vim.lsp.enable(lsp)
  end
end
```

- [ ] **Step 2: Verify headless boot is still clean**

Run: `nvim --headless +qa 2>&1`
Expected: empty output (NvChad still present; this file no longer requires it).

Run: `nvim --headless "+lua print(vim.lsp.config['lua_ls'] ~= nil)" +qa`
Expected: prints `true`.

- [ ] **Step 3: Commit**

```bash
git add lua/configs/lspconfig.lua
git commit -m "lsp: make configs/lspconfig.lua standalone (no nvchad.configs.lspconfig)"
```

---

### Task 2: Standalone cmp config + full completion spec

**Files:**
- Modify: `lua/configs/nvimCmp.lua` (full rewrite — merges nvchad.configs.cmp defaults with the user's CR/Tab/preselect overrides)
- Modify: `lua/plugins/nvimCmp.lua` (full spec with dependencies, previously supplied by `nvchad.plugins`)

**Interfaces:**
- Consumes: `configs.nvimCmp` returns the nvim-cmp opts table.
- Produces: nvim-cmp spec loading on `InsertEnter` with LuaSnip (vscode loaders + #258 fix, inlined from `nvchad.configs.luasnip`), nvim-autopairs wired to cmp `confirm_done`, and sources `nvim_lsp, luasnip, buffer, nvim_lua, async_path`.

- [ ] **Step 1: Rewrite `lua/configs/nvimCmp.lua`** with exactly:

```lua
local cmp = require "cmp"

local config = {
  completion = {
    completeopt = "menu,menuone,noselect",
  },

  snippet = {
    expand = function(args)
      require("luasnip").lsp_expand(args.body)
    end,
  },

  mapping = {
    ["<C-p>"] = cmp.mapping.select_prev_item(),
    ["<C-n>"] = cmp.mapping.select_next_item(),
    ["<C-d>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.close(),

    ["<CR>"] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Insert,
      select = false,
    },

    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif require("luasnip").expand_or_jumpable() then
        -- require("luasnip").expand_or_jump() For some reason this things breaks normal tabs in insert mode
        fallback()
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif require("luasnip").jumpable(-1) then
        require("luasnip").jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  },

  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "buffer" },
    { name = "nvim_lua" },
    { name = "async_path" },
  },

  preselect = cmp.PreselectMode.None,
}

return config
```

- [ ] **Step 2: Rewrite `lua/plugins/nvimCmp.lua`** with exactly:

```lua
return {
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = {
    {
      "L3MON4D3/LuaSnip",
      dependencies = "rafamadriz/friendly-snippets",
      opts = { history = true, updateevents = "TextChanged,TextChangedI" },
      config = function(_, opts)
        require("luasnip").config.set_config(opts)

        -- vscode-format snippets (inlined from nvchad.configs.luasnip)
        require("luasnip.loaders.from_vscode").lazy_load {}

        -- fix luasnip #258
        vim.api.nvim_create_autocmd("InsertLeave", {
          callback = function()
            if
              require("luasnip").session.current_nodes[vim.api.nvim_get_current_buf()]
              and not require("luasnip").session.jump_active
            then
              require("luasnip").unlink_current()
            end
          end,
        })
      end,
    },

    {
      "windwp/nvim-autopairs",
      opts = {
        fast_wrap = {},
        disable_filetype = { "TelescopePrompt", "vim" },
      },
      config = function(_, opts)
        require("nvim-autopairs").setup(opts)

        -- setup cmp for autopairs
        local cmp_autopairs = require "nvim-autopairs.completion.cmp"
        require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
      end,
    },

    "saadparwaiz1/cmp_luasnip",
    "hrsh7th/cmp-nvim-lua",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "https://codeberg.org/FelipeLema/cmp-async-path.git",
  },
  opts = function()
    return require "configs.nvimCmp"
  end,
}
```

- [ ] **Step 3: Verify**

Run: `nvim --headless +qa 2>&1`
Expected: empty.

Run: `nvim --headless "+lua vim.api.nvim_exec_autocmds('InsertEnter', {}); print(require('cmp').get_config().preselect)" +qa`
Expected: prints `None` (the string value of cmp.PreselectMode.None).

- [ ] **Step 4: Commit**

```bash
git add lua/configs/nvimCmp.lua lua/plugins/nvimCmp.lua
git commit -m "cmp: standalone nvim-cmp spec and config, drop nvchad.configs.cmp"
```

---

### Task 3: Add replacement plugin specs

**Files:**
- Create: `lua/plugins/ayu.lua`
- Create: `lua/plugins/lualine.lua`
- Create: `lua/plugins/bufferline.lua`
- Create: `lua/plugins/toggleterm.lua`
- Create: `lua/plugins/telescope.lua`
- Create: `lua/plugins/gitsigns.lua`
- Create: `lua/plugins/indentBlankline.lua`
- Create: `lua/plugins/whichkey.lua`
- Create: `lua/plugins/devicons.lua`
- Modify: `lua/plugins/mason-lspconfig.lua` (add mason opts inlined from `nvchad.configs.mason`)
- Modify: `lua/plugins/treeSitter.lua` (rewrite for the nvim-treesitter main-branch API; carries the FileType→`vim.treesitter.start` hook that `nvchad.autocmds` used to provide)

**Interfaces:**
- Consumes: nothing new.
- Produces: plugin specs named `echasnovski/neovim-ayu` (colorscheme `ayu-dark`), `nvim-lualine/lualine.nvim`, `akinsho/bufferline.nvim` (commands `BufferLineCycleNext/Prev` used by Task 4 mappings), `akinsho/toggleterm.nvim` (command `ToggleTerm` with `direction=` used by Task 4 mappings), `nvim-telescope/telescope.nvim`, `lewis6991/gitsigns.nvim`, `lukas-reineke/indent-blankline.nvim`, `folke/which-key.nvim`, `nvim-tree/nvim-web-devicons`.

Note: during this task the NvChad import is still active; lazy.nvim merges same-name specs (ours wins), and the new specs simply coexist. Theme will be transiently mixed (base46 highlights re-applied after setup) — accepted transitional state, resolved in Task 4.

- [ ] **Step 1: Create `lua/plugins/ayu.lua`**

```lua
return {
  "echasnovski/neovim-ayu",
  lazy = false,
  priority = 1000,
  config = function()
    require("ayu").setup {
      mirage = false,
      terminal = true,
      overrides = {},
    }
    vim.cmd "colorscheme ayu-dark"
  end,
}
```

- [ ] **Step 2: Create `lua/plugins/lualine.lua`**

```lua
return {
  "nvim-lualine/lualine.nvim",
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = {
      theme = "ayu",
      globalstatus = true,
    },
  },
}
```

- [ ] **Step 3: Create `lua/plugins/bufferline.lua`**

```lua
return {
  "akinsho/bufferline.nvim",
  version = "*",
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = {
      mode = "buffers",
      offsets = {
        {
          filetype = "NvimTree",
          text = "File Explorer",
          text_align = "center",
          separator = true,
        },
      },
    },
  },
}
```

- [ ] **Step 4: Create `lua/plugins/toggleterm.lua`**

```lua
return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = { "ToggleTerm", "ToggleTermToggleAll" },
  opts = {
    open_mapping = false, -- mapped manually in lua/mappings.lua
    direction = "float",
    float_opts = { border = "single" },
  },
}
```

- [ ] **Step 5: Create `lua/plugins/telescope.lua`** (defaults inlined from `nvchad.configs.telescope`; `extensions_list` dropped — nothing consumed it; opts as a function so `require("telescope.actions")` resolves only after telescope is in rtp)

```lua
return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = function()
    return {
      defaults = {
        prompt_prefix = "  ",
        selection_caret = " ",
        entry_prefix = " ",
        sorting_strategy = "ascending",
        layout_config = {
          horizontal = {
            prompt_position = "top",
            preview_width = 0.55,
          },
          width = 0.87,
          height = 0.80,
        },
        mappings = {
          n = { ["q"] = require("telescope.actions").close },
        },
      },
    }
  end,
}
```

- [ ] **Step 6: Create `lua/plugins/gitsigns.lua`** (replaces lazy-loading on NvChad's `User FilePost` with real events; opts inlined from `nvchad.configs.gitsigns`)

```lua
return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    signs = {
      delete = { text = "󰍵" },
      changedelete = { text = "󱕖" },
    },
  },
}
```

- [ ] **Step 7: Create `lua/plugins/indentBlankline.lua`** (base46-specific `IblChar`/`IblScopeChar` highlights dropped — ibl defines its own defaults)

```lua
return {
  "lukas-reineke/indent-blankline.nvim",
  event = { "BufReadPost", "BufNewFile" },
  main = "ibl",
  opts = {
    indent = { char = "│" },
    scope = { char = "│" },
  },
}
```

- [ ] **Step 8: Create `lua/plugins/whichkey.lua`**

```lua
return {
  "folke/which-key.nvim",
  keys = { "<leader>", "<c-w>", "\"", "'", "`", "c", "v", "g" },
  cmd = "WhichKey",
  opts = {},
}
```

- [ ] **Step 9: Create `lua/plugins/devicons.lua`** (plain; the `nvchad.icons.devicons` override is gone)

```lua
return {
  "nvim-tree/nvim-web-devicons",
  opts = {},
}
```

- [ ] **Step 10: Rewrite `lua/plugins/mason-lspconfig.lua`** (mason opts inlined from `nvchad.configs.mason`; `PATH = "skip"` is safe because Task 4's options.lua prepends mason/bin to PATH)

```lua
return {
  "mason-org/mason-lspconfig.nvim",
  opts = {
    ensure_installed = require("configs.alwaysInstalledLspServers"),
  },
  dependencies = {
    {
      "mason-org/mason.nvim",
      opts = {
        PATH = "skip",
        ui = {
          icons = {
            package_pending = " ",
            package_installed = " ",
            package_uninstalled = " ",
          },
        },
        max_concurrent_installers = 10,
      },
    },
    "neovim/nvim-lspconfig",
  },
  lazy = false,
}
```

- [ ] **Step 11: Rewrite `lua/plugins/treeSitter.lua`** (main-branch rewrite API: `setup{}` accepts only `install_dir`; highlighting comes from `vim.treesitter.start` on FileType, previously provided by `nvchad.autocmds`; explicit base parser install replaces the dead `auto_install` opt)

```lua
return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  branch = "main",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup {}

    -- base parser set (nvchad's list); more via :TSInstall
    require("nvim-treesitter").install { "lua", "luadoc", "printf", "vim", "vimdoc" }

    -- enable highlighting when a parser is available
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "*",
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
```

- [ ] **Step 12: Verify**

Run: `nvim --headless +qa 2>&1`
Expected: empty (first run clones the new plugins — needs network; if a clone fails, fix the spec, do not proceed).

Run: `nvim --headless "+lua print(vim.fn.exists(':ToggleTerm') .. vim.fn.exists(':BufferLineCycleNext') .. vim.fn.exists(':Telescope'))" +qa`
Expected: `222` (`exists(':Cmd')` returns 2 for user commands).

- [ ] **Step 13: Commit**

```bash
git add lua/plugins/ayu.lua lua/plugins/lualine.lua lua/plugins/bufferline.lua lua/plugins/toggleterm.lua lua/plugins/telescope.lua lua/plugins/gitsigns.lua lua/plugins/indentBlankline.lua lua/plugins/whichkey.lua lua/plugins/devicons.lua lua/plugins/mason-lspconfig.lua lua/plugins/treeSitter.lua
git commit -m "plugins: add standalone replacements (ayu, lualine, bufferline, toggleterm, telescope, gitsigns, ibl, which-key, devicons); treesitter main-branch API"
```

---

### Task 4: The cutover — drop NvChad entirely

**Files:**
- Modify: `init.lua` (full rewrite)
- Modify: `lua/options.lua` (inline `nvchad.options`)
- Modify: `lua/mappings.lua` (inline `nvchad.mappings` with rewrites)
- Modify: `lua/configs/lazy.lua` (install colorscheme)
- Modify: `lua/configs/nvimtree.lua` (drop base46 dofile)
- Delete: `lua/chadrc.lua`

**Interfaces:**
- Consumes: `BufferLineCycleNext/Prev`, `ToggleTerm` commands and `WhichKey` from Task 3.
- Produces: a config whose only plugin source is `{ import = "plugins" }`; no `nvchad.*`, `base46`, `chadrc`, `nvconfig` references anywhere.

- [ ] **Step 1: Rewrite `init.lua`** with exactly:

```lua
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

-- load plugins
require("lazy").setup({
  { import = "plugins" },
}, require "configs.lazy")

require "options"

vim.schedule(function()
  require "mappings"
end)

-- lazy download lsps
require "configs.lazyInstallLsps"
```

- [ ] **Step 2: Rewrite `lua/options.lua`** with exactly:

```lua
local opt = vim.opt
local o = vim.o
local g = vim.g

-- inlined from nvchad.options
o.laststatus = 3
o.showmode = false
o.splitkeep = "screen"

o.clipboard = "unnamedplus"
o.cursorline = true
o.cursorlineopt = "number"

-- Indenting
o.expandtab = true
o.shiftwidth = 2
o.smartindent = true
o.tabstop = 2
o.softtabstop = 2

opt.fillchars = { eob = " " }
o.ignorecase = true
o.smartcase = true
o.mouse = "a"

-- Numbers
o.number = true
o.numberwidth = 2
o.ruler = false

-- disable nvim intro
opt.shortmess:append "sI"

o.signcolumn = "yes"
o.splitbelow = true
o.splitright = true
o.timeoutlen = 400
o.undofile = true

-- interval for writing swap file to disk, also used by gitsigns
o.updatetime = 250

-- go to previous/next line with h,l,left arrow and right arrow
opt.whichwrap:append "<>[]hl"

-- disable some default providers
g.loaded_node_provider = 0
g.loaded_python3_provider = 0
g.loaded_perl_provider = 0
g.loaded_ruby_provider = 0

-- add binaries installed by mason.nvim to path
local is_windows = vim.fn.has "win32" ~= 0
local sep = is_windows and "\\" or "/"
local delim = is_windows and ";" or ":"
vim.env.PATH = table.concat({ vim.fn.stdpath "data", "mason", "bin" }, sep) .. delim .. vim.env.PATH

-- user options
o.relativenumber = true

if vim.g.neovide == true then
  vim.g.neovide_cursor_vfx_mode = "torpedo"
  vim.g.neovide_refresh_rate = 144
  vim.g.neovide_opacity = 0.96
  o.guifont = "JetBrainsMono Nerd Font"
end

require "configs.fixDockerComposeFiletype"
require "configs.pendulumConfig"
```

- [ ] **Step 3: Rewrite `lua/mappings.lua`** with exactly (nvchad.mappings inlined; `tabufline` → bufferline commands, `nvchad.term` → ToggleTerm, `nvchad.themes` → telescope colorscheme, NvCheatsheet → WhichKey; user maps kept; `<leader>pt` telescope-terms dropped):

```lua
-- inlined from nvchad.mappings, with nvchad-specific targets replaced
local map = vim.keymap.set

map("i", "<C-b>", "<ESC>^i", { desc = "move beginning of line" })
map("i", "<C-e>", "<End>", { desc = "move end of line" })
map("i", "<C-h>", "<Left>", { desc = "move left" })
map("i", "<C-l>", "<Right>", { desc = "move right" })
map("i", "<C-j>", "<Down>", { desc = "move down" })
map("i", "<C-k>", "<Up>", { desc = "move up" })

map("n", "<C-h>", "<C-w>h", { desc = "switch window left" })
map("n", "<C-l>", "<C-w>l", { desc = "switch window right" })
map("n", "<C-j>", "<C-w>j", { desc = "switch window down" })
map("n", "<C-k>", "<C-w>k", { desc = "switch window up" })

map("n", "<Esc>", "<cmd>noh<CR>", { desc = "general clear highlights" })

map("n", "<C-s>", "<cmd>w<CR>", { desc = "general save file" })
map("n", "<C-c>", "<cmd>%y+<CR>", { desc = "general copy whole file" })

map("n", "<leader>n", "<cmd>set nu!<CR>", { desc = "toggle line number" })
map("n", "<leader>rn", "<cmd>set rnu!<CR>", { desc = "toggle relative number" })
map("n", "<leader>ch", "<cmd>WhichKey<CR>", { desc = "whichkey all keymaps" })

map({ "n", "x" }, "<leader>fm", function()
  require("conform").format { lsp_fallback = true }
end, { desc = "general format file" })

-- global lsp mappings
map("n", "<leader>ds", vim.diagnostic.setloclist, { desc = "LSP diagnostic loclist" })

-- buffers (bufferline.nvim; was nvchad tabufline)
map("n", "<leader>b", "<cmd>enew<CR>", { desc = "buffer new" })
map("n", "<tab>", "<cmd>BufferLineCycleNext<CR>", { desc = "buffer goto next" })
map("n", "<S-tab>", "<cmd>BufferLineCyclePrev<CR>", { desc = "buffer goto prev" })
map("n", "<leader>x", "<cmd>bdelete<CR>", { desc = "buffer close" })

-- Comment (built-in since nvim 0.10)
map("n", "<leader>/", "gcc", { desc = "toggle comment", remap = true })
map("v", "<leader>/", "gc", { desc = "toggle comment", remap = true })

-- nvimtree
map("n", "<C-n>", "<cmd>NvimTreeToggle<CR>", { desc = "nvimtree toggle window" })

-- telescope
map("n", "<leader>fw", "<cmd>Telescope live_grep<CR>", { desc = "telescope live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "telescope find buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "telescope help page" })
map("n", "<leader>ma", "<cmd>Telescope marks<CR>", { desc = "telescope find marks" })
map("n", "<leader>fo", "<cmd>Telescope oldfiles<CR>", { desc = "telescope find oldfiles" })
map("n", "<leader>fz", "<cmd>Telescope current_buffer_fuzzy_find<CR>", { desc = "telescope find in current buffer" })
map("n", "<leader>cm", "<cmd>Telescope git_commits<CR>", { desc = "telescope git commits" })
map("n", "<leader>gt", "<cmd>Telescope git_status<CR>", { desc = "telescope git status" })

-- was nvchad theme switcher
map("n", "<leader>th", "<cmd>Telescope colorscheme<CR>", { desc = "pick colorscheme" })

map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "telescope find files" })
map(
  "n",
  "<leader>fa",
  "<cmd>Telescope find_files follow=true no_ignore=true hidden=true<CR>",
  { desc = "telescope find all files" }
)

-- terminal (toggleterm.nvim; was nvchad.term)
map("t", "<C-x>", "<C-\\><C-N>", { desc = "terminal escape terminal mode" })

map("n", "<leader>h", "<cmd>ToggleTerm direction=horizontal<CR>", { desc = "terminal new horizontal term" })
map("n", "<leader>v", "<cmd>ToggleTerm direction=vertical<CR>", { desc = "terminal new vertical term" })

map({ "n", "t" }, "<A-v>", "<cmd>ToggleTerm direction=vertical<CR>", { desc = "terminal toggleable vertical term" })
map({ "n", "t" }, "<A-h>", "<cmd>ToggleTerm direction=horizontal<CR>", { desc = "terminal toggleable horizontal term" })
map({ "n", "t" }, "<A-i>", "<cmd>ToggleTerm direction=float<CR>", { desc = "terminal toggle floating term" })

-- whichkey
map("n", "<leader>wK", "<cmd>WhichKey <CR>", { desc = "whichkey all keymaps" })

map("n", "<leader>wk", function()
  vim.cmd("WhichKey " .. vim.fn.input "WhichKey: ")
end, { desc = "whichkey query lookup" })

-- user additions
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

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
```

- [ ] **Step 4: In `lua/configs/lazy.lua` change** `install = { colorscheme = { "nvchad" } },` **to** `install = { colorscheme = { "ayu-dark" } },`

- [ ] **Step 5: In `lua/configs/nvimtree.lua` delete line 1** (`dofile(vim.g.base46_cache .. "nvimtree")`).

- [ ] **Step 6: Delete `lua/chadrc.lua`** (`git rm lua/chadrc.lua`).

- [ ] **Step 7: Verify the purge is complete and nvim boots**

Run: `grep -rn -e nvchad -e base46 -e chadrc -e nvconfig init.lua lua/ || echo CLEAN`
Expected: `CLEAN`.

Run: `nvim --headless +qa 2>&1`
Expected: empty (first boot without NvChad; lazy may reinstall/repair — must not error).

Run: `nvim --headless "+lua print(vim.g.colors_name)" +qa`
Expected: prints `ayu-dark` (or another `ayu*` value — record what prints; assert it is not empty and not `default`).

Run: `nvim --headless "+lua print(vim.fn.maparg('<leader>x', 'n'))" +qa`
Expected: output contains `bdelete`.

- [ ] **Step 8: Commit**

```bash
git add init.lua lua/options.lua lua/mappings.lua lua/configs/lazy.lua lua/configs/nvimtree.lua
git rm lua/chadrc.lua
git commit -m "cutover: drop NvChad import, base46 caches and chadrc; inline options/mappings"
```

---

### Task 5: Lockfile regeneration, README, final verification

**Files:**
- Modify: `lazy-lock.json` (regenerated by lazy, not hand-edited)
- Modify: `README.md`

**Interfaces:** none.

- [ ] **Step 1: Regenerate the lockfile**

Run: `nvim --headless "+Lazy! sync" +qa 2>&1`
Expected: completes silently. Then `git diff --stat lazy-lock.json` must show changes and `grep -c "NvChad\|base46\|\"ui\"\|volt\|menu\|minty" lazy-lock.json` must return `0`.

- [ ] **Step 2: Update `README.md`** — replace the title/intro so it no longer presents this as a myNvChad install (clone URLs stay valid). Result should read:

````markdown
# my nvim config

Standalone Neovim config (no NvChad): lazy.nvim, nvim-lspconfig + mason, nvim-cmp,
treesitter (main branch), telescope, nvim-tree, lualine + bufferline, toggleterm,
conform, gitsigns, ayu theme.

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
````

(Keep the existing LICENSE and .stylua.toml untouched.)

- [ ] **Step 3: Final verification sweep**

Run each; expected in brackets:

```bash
nvim --headless +qa 2>&1                                  # [empty]
nvim --headless "+Lazy! check" +qa 2>&1                   # [no errors about our specs]
nvim --headless "+lua print(vim.g.colors_name)" +qa       # [ayu*]
grep -rn -e nvchad -e base46 -e chadrc -e nvconfig init.lua lua/ # [no hits]
grep -c "NvChad\|base46" lazy-lock.json                   # [0]
git status --short                                        # [only README/lazy-lock staged or clean]
```

Then an interactive smoke test by the user: open a file (treesitter colors, gitsigns gutter), `<C-n>` tree, `<leader>ff` telescope, `<A-i>` floating term, `<leader>x` buffer close, edit a Lua file for cmp + lua_ls hover/rename.

- [ ] **Step 4: Commit**

```bash
git add lazy-lock.json README.md
git commit -m "post-purge: regenerate lazy-lock, update README"
```

---

## Rollback

Branch `remove-nvchad` only; `main` is untouched. Any broken intermediate state: `git checkout -- .` or `git switch main`. NvChad plugin dirs stay in `~/.local/share/nvim/lazy/` until lazy prunes them — if the transitional states bother you, `:Lazy clean` removes unused plugins (run only after Task 4).
