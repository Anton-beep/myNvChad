# Remove NvChad Dependency — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every nvchad-origin repo (NvChad starter, nvchad/ui, base46, volt, menu, minty) from this config with NO replacement plugins. nvim must stay fully functioning; features provided by nvchad/ui are simply lost; appearance changes (builtin colorscheme, builtin statusline). Standalone third-party plugins the user already uses (telescope, gitsigns, indent-blankline, which-key, nvim-web-devicons, plenary) are kept by adopting their specs into `lua/plugins/` — they are not nvchad components and not new additions.

**Architecture:** Five incrementally-bootable tasks. First make the user's `configs/` fragments self-contained (LSP, cmp) while NvChad still boots, then adopt the specs of orphaned standalone plugins (previously injected by `nvchad.plugins`), then do the cutover commit that deletes the `nvchad.plugins` import + `chadrc.lua` + all base46 cache dofiles, and finally regenerate `lazy-lock.json` and verify headlessly. Every commit leaves `nvim --headless +qa` clean.

**Tech Stack:** Neovim 0.12.5, lazy.nvim (stable), nvim-cmp, nvim-lspconfig (vim.lsp.config API), nvim-treesitter **main branch (2025 rewrite — `setup()` only accepts `install_dir`; old `auto_install`/`highlight` opts are silently ignored)**, telescope, gitsigns, indent-blankline, which-key. Colorscheme after cutover: builtin `habamax`.

**Spec:** User decisions from conversation (2026-09-29): (1) "Just remove current dependency on nvchad completely, so that nvim config may change, maybe even lose some functionality. For this change create a separate branch from main and do the work there." (2) "don't even add replacements now, just remove the nvchad components, so that nvim still will be functioning, but maybe with less features, not same appearance." Branch `remove-nvchad` already created from `main`.

## Global Constraints

- Work ONLY on branch `remove-nvchad` (already checked out).
- **Do not add any plugin that is not already in `lazy-lock.json` at the branch point.** No lualine, no bufferline, no toggleterm, no ayu theme, nothing new.
- Remove only nvchad-origin repos: `NvChad/NvChad`, `nvchad/ui`, `nvchad/base46`, `nvzone/volt`, `nvzone/menu`, `nvzone/minty`.
- After every task, `nvim --headless +qa 2>&1` must print nothing (no errors).
- Final state: `grep -rn -e nvchad -e base46 -e chadrc -e nvconfig init.lua lua/` returns zero hits.
- Preserve user's own behavior: `<CR>` confirm `select = false`, `preselect = None`, Tab fallback (do NOT luasnip-jump on Tab), semanticTokens re-enabled, `relativenumber`, neovide settings, all `lua/plugins/*` specs the user wrote (except the rewrites/modifications explicitly listed in Tasks 2–3), `configs/lazyInstallLsps.lua`, `configs/lspServers.lua`, `configs/fixDockerComposeFiletype.lua`, `configs/pendulumConfig.lua`, opencode mappings (kept verbatim even though no opencode plugin is installed — pre-existing state, out of scope).
- Do not touch `lazy-lock.json` by hand — regenerate via nvim.
- `vim.treesitter.start` must keep being hooked on FileType (this, not treesitter opts, is what enables highlighting with the rewrite).
- Pre-existing quirks left as-is (do NOT "fix" them): `conform` and `pendulum-nvim` specs have no lazy-load handler under `defaults.lazy=true`, so their `opts`/`config` never ran before the purge either; the specs are untouched, so whatever their load behavior is today is preserved exactly.

## Verified inventory (what NvChad actually supplies here)

From reading `~/.local/share/nvim/lazy/NvChad/lua/nvchad/` (v2.5, commit d042cc97):

- `nvchad.plugins` — default spec list: plenary, base46, ui, volt, menu, minty, nvim-web-devicons (with `nvchad.icons.devicons` override), indent-blankline, nvim-tree, which-key, conform (stylua), gitsigns, mason, nvim-lspconfig, nvim-cmp (+ LuaSnip, friendly-snippets, nvim-autopairs, cmp_luasnip, cmp-nvim-lua, cmp-nvim-lsp, cmp-buffer, cmp-async-path), telescope, nvim-treesitter.
- `nvchad.options` (~57 lines), `nvchad.mappings` (~109 lines), `nvchad.autocmds` (User `FilePost` event, FileType→`vim.treesitter.start`, `TSInstallAll` cmd, editorconfig shim — redundant, nvim 0.12 handles editorconfig natively).
- `nvchad.configs.{cmp,lspconfig,telescope,treesitter,mason,luasnip,nvimtree,gitsigns}` — opts tables.
- From `nvchad/ui`: statusline, tabufline, NvDash (NOT enabled — `load_on_startup` commented out in chadrc, defaults false), NvCheatsheet, term system, theme switcher, NvRenamer, `nvchad.lsp.diagnostic_config`, `nvconfig` (reads `chadrc.lua`), `colors/nvchad.lua`, telescope extensions `themes`/`terms`.
- Already-dead code (verified): `nvchad.configs.lspconfig.defaults()` is fully shadowed by user's `configs/lspconfig.lua` (its `lua_ls` workspace settings and semanticTokens-disabling `on_init` never ran); telescope `extensions_list` is consumed by nothing; treesitter `auto_install/highlight/indent` opts are ignored by the main-branch rewrite.
- Load-graph facts that shape the plan: nvim-lspconfig today loads via NvChad's `event = "User FilePost"`; gitsigns and indent-blankline also lazy-load on `User FilePost` (an event that disappears with NvChad — Task 3 must re-home them on real events); cmp loads on NvChad's `event = "InsertEnter"` (Task 2 preserves it); `plenary` is required at runtime by telescope, lazygit (declares it itself), and none-ls (does NOT declare it) — after the purge it must stay referenced somewhere or `:Lazy! sync` prunes it and none-ls breaks (Task 3 declares it as a telescope dependency).

## Known, accepted losses (user approved: "less features, not same appearance")

- base46 theming / `ayu_dark` → builtin `habamax`. No transparency, no theme_toggle, no nvchad theme switcher (`<leader>th` becomes `Telescope colorscheme` over builtin schemes).
- nvchad statusline → nvim builtin statusline (`laststatus = 3` keeps the single global line).
- nvchad tabufline → nothing; `<tab>`/`<S-tab>` remap to builtin `:bnext`/`:bprevious`, `<leader>x` to `:bdelete` (builtin commands, no plugin).
- nvchad toggleable terminals (`<A-i>`, `<A-h>`, `<A-v>`, `<leader>h`, `<leader>v`) → gone; builtin `:terminal` remains. The `t` `<C-x>` escape mapping stays.
- Telescope `terms` picker (`<leader>pt`) → gone (extension lived in nvchad/ui).
- NvCheatsheet grid (`<leader>ch`) → `:WhichKey` (which-key is kept).
- NvRenamer popup (`<leader>ra`) → native `vim.lsp.buf.rename`.
- Auto-popup LSP signature help (nvchad/ui) → gone; `vim.lsp.buf.signature_help` still available on demand (no mapping).
- cmp entry icons (ui's `nvchad.cmp` formatting) → plain text entries.
- `TSInstallAll` command → gone (use `:TSInstall`).
- Treesitter `auto_install` no longer exists in the rewrite (the old setting was silently ignored anyway) — a base parser set installs explicitly, others via `:TSInstall`.

## Kept (existing standalone plugins — specs adopted in Task 3, nothing new installed)

telescope.nvim (+ plenary), gitsigns.nvim, indent-blankline.nvim, which-key.nvim, nvim-web-devicons — plus everything the user already specced: nvim-tree, conform, mason/mason-lspconfig/nvim-lspconfig, nvim-cmp stack, none-ls + cspell, dressing, lazygit, pendulum-nvim, rainbow-delimiters, nvim-treesitter.

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
- Produces: nvim-cmp spec loading on `InsertEnter` with LuaSnip (vscode loaders + #258 fix, inlined from `nvchad.configs.luasnip`), nvim-autopairs wired to cmp `confirm_done`, and sources `nvim_lsp, luasnip, buffer, nvim_lua, async_path`. All plugins already in `lazy-lock.json` — nothing new installed.

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

### Task 3: Adopt orphaned standalone plugins (NO new plugins)

These plugins already exist in `lazy-lock.json` and the user already uses them via mappings; only their specs were injected by `nvchad.plugins`. This task re-homes those specs into `lua/plugins/`. It also re-homes lazy-load triggers that referenced NvChad's `User FilePost` event (which disappears in Task 4) onto real Neovim events, and declares `plenary` explicitly so `:Lazy! sync` in Task 5 does not prune it (none-ls requires it at runtime but never declared it).

**Files:**
- Create: `lua/plugins/telescope.lua`
- Create: `lua/plugins/gitsigns.lua`
- Create: `lua/plugins/indentBlankline.lua`
- Create: `lua/plugins/whichkey.lua`
- Create: `lua/plugins/devicons.lua`
- Modify: `lua/plugins/mason-lspconfig.lua` (add mason opts inlined from `nvchad.configs.mason`)
- Modify: `lua/plugins/treeSitter.lua` (rewrite for the nvim-treesitter main-branch API; carries the FileType→`vim.treesitter.start` hook that `nvchad.autocmds` used to provide)
- Modify: `lua/plugins/init.lua` (give nvim-lspconfig an explicit event — it previously loaded via NvChad's `User FilePost`)

**Interfaces:**
- Consumes: nothing new.
- Produces: plugin specs named `nvim-telescope/telescope.nvim` (with `nvim-lua/plenary.nvim` dependency; command `Telescope` used by Task 4 mappings), `lewis6991/gitsigns.nvim`, `lukas-reineke/indent-blankline.nvim` (`main = "ibl"`), `folke/which-key.nvim` (commands `WhichKey` used by Task 4 mappings), `nvim-tree/nvim-web-devicons`.

Note: during this task the NvChad import is still active; lazy.nvim merges same-name specs (ours wins), so behavior is unchanged — only trigger sources are duplicated harmlessly.

- [ ] **Step 1: Create `lua/plugins/telescope.lua`** (defaults inlined from `nvchad.configs.telescope`; `extensions_list` dropped — nothing consumed it, and the `themes`/`terms` extensions lived in nvchad/ui; opts as a function so `require("telescope.actions")` resolves only after telescope is in rtp; plenary declared so it survives Task 5's sync-prune)

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

- [ ] **Step 2: Create `lua/plugins/gitsigns.lua`** (was `event = "User FilePost"` from NvChad — re-homed on real events; opts inlined from `nvchad.configs.gitsigns`; glyph signs render fine without base46)

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

- [ ] **Step 3: Create `lua/plugins/indentBlankline.lua`** (was `event = "User FilePost"`; base46-specific `IblChar`/`IblScopeChar` highlights and the hide-first-space hook dropped — ibl defines its own defaults)

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

- [ ] **Step 4: Create `lua/plugins/whichkey.lua`** (trigger list from NvChad's spec)

```lua
return {
  "folke/which-key.nvim",
  keys = { "<leader>", "<c-w>", "\"", "'", "`", "c", "v", "g" },
  cmd = "WhichKey",
  opts = {},
}
```

- [ ] **Step 5: Create `lua/plugins/devicons.lua`** (plain; the `nvchad.icons.devicons` override is gone. Needed by nvim-tree and telescope for icons — without it they fall back to text glyphs)

```lua
return {
  "nvim-tree/nvim-web-devicons",
  opts = {},
}
```

- [ ] **Step 6: Rewrite `lua/plugins/mason-lspconfig.lua`** (mason opts inlined from `nvchad.configs.mason`; `PATH = "skip"` is safe because Task 4's options.lua prepends mason/bin to PATH)

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

- [ ] **Step 7: Rewrite `lua/plugins/treeSitter.lua`** (main-branch rewrite API: `setup{}` accepts only `install_dir`; highlighting comes from `vim.treesitter.start` on FileType, previously provided by `nvchad.autocmds`; explicit base parser install replaces the dead `auto_install` opt; drops the base46 dofile calls)

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
    -- (replaces the FileType hook that nvchad.autocmds provided)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "*",
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
```

- [ ] **Step 8: In `lua/plugins/init.lua`, add an explicit event to the nvim-lspconfig spec** (it previously loaded via NvChad's `User FilePost` event; make the trigger ours). Replace the lspconfig block so the file reads:

```lua
return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require "configs.lspconfig"
    end,
  },
}
```

(Delete the commented-out treesitter example block at the bottom while here — it documents the old master-branch opts API that no longer exists.)

- [ ] **Step 9: Verify**

Run: `nvim --headless +qa 2>&1`
Expected: empty (no cloning — every plugin is already installed).

Run: `nvim --headless "+lua print(vim.fn.exists(':Telescope') .. vim.fn.exists(':WhichKey') .. tostring(require('lazy.core.config').plugins['gitsigns.nvim'] ~= nil))" +qa`
Expected: `22true` (`exists(':Cmd')` returns 2 for user commands; gitsigns is event-lazy so it is checked via lazy's spec registry, not a command).

- [ ] **Step 10: Commit**

```bash
git add lua/plugins/telescope.lua lua/plugins/gitsigns.lua lua/plugins/indentBlankline.lua lua/plugins/whichkey.lua lua/plugins/devicons.lua lua/plugins/mason-lspconfig.lua lua/plugins/treeSitter.lua lua/plugins/init.lua
git commit -m "plugins: adopt orphaned standalone specs (telescope+plenary, gitsigns, ibl, which-key, devicons); treesitter main-branch API"
```

---

### Task 4: The cutover — drop NvChad entirely

**Files:**
- Modify: `init.lua` (full rewrite)
- Modify: `lua/options.lua` (inline `nvchad.options`; set builtin colorscheme)
- Modify: `lua/mappings.lua` (inline `nvchad.mappings`, drop nvchad-feature maps, use builtin buffer commands)
- Modify: `lua/configs/lazy.lua` (install colorscheme)
- Modify: `lua/configs/nvimtree.lua` (drop base46 dofile)
- Delete: `lua/chadrc.lua`

**Interfaces:**
- Consumes: `Telescope`, `WhichKey`, `NvimTreeToggle/Focus/Refresh` commands from kept plugins.
- Produces: a config whose only plugin source is `{ import = "plugins" }`; no `nvchad.*`, `base46`, `chadrc`, `nvconfig` references anywhere; colorscheme is builtin `habamax`.

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

- [ ] **Step 2: Rewrite `lua/options.lua`** with exactly (nvchad.options inlined; builtin colorscheme since base46 is gone):

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

-- builtin colorscheme (base46 removed)
vim.cmd "colorscheme habamax"

if vim.g.neovide == true then
  vim.g.neovide_cursor_vfx_mode = "torpedo"
  vim.g.neovide_refresh_rate = 144
  vim.g.neovide_opacity = 0.96
  o.guifont = "JetBrainsMono Nerd Font"
end

require "configs.fixDockerComposeFiletype"
require "configs.pendulumConfig"
```

- [ ] **Step 3: Rewrite `lua/mappings.lua`** with exactly (nvchad.mappings inlined; nvchad-specific targets replaced with builtin commands or kept plugins: buffer cycling → builtin `:bnext`/`:bprevious`, buffer close → `:bdelete`, theme switcher → `Telescope colorscheme`, NvCheatsheet → `:WhichKey`, NvRenamer → handled in Task 1's lspconfig; nvchad terminal maps and `<leader>pt` terms picker DROPPED; user maps kept verbatim):

```lua
-- inlined from nvchad.mappings, with nvchad-only targets replaced or dropped
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

-- buffers (builtin commands; was nvchad tabufline)
map("n", "<leader>b", "<cmd>enew<CR>", { desc = "buffer new" })
map("n", "<tab>", "<cmd>bnext<CR>", { desc = "buffer goto next" })
map("n", "<S-tab>", "<cmd>bprevious<CR>", { desc = "buffer goto prev" })
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

-- was nvchad theme switcher; now builtin schemes via telescope
map("n", "<leader>th", "<cmd>Telescope colorscheme<CR>", { desc = "pick colorscheme" })

map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "telescope find files" })
map(
  "n",
  "<leader>fa",
  "<cmd>Telescope find_files follow=true no_ignore=true hidden=true<CR>",
  { desc = "telescope find all files" }
)

-- terminal (nvchad term maps dropped; builtin :terminal remains)
map("t", "<C-x>", "<C-\\><C-N>", { desc = "terminal escape terminal mode" })

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

- [ ] **Step 4: In `lua/configs/lazy.lua` change** `install = { colorscheme = { "nvchad" } },` **to** `install = { colorscheme = { "habamax" } },` (builtin scheme — used by lazy only during fresh installs).

- [ ] **Step 5: In `lua/configs/nvimtree.lua` delete line 1** (`dofile(vim.g.base46_cache .. "nvimtree")`).

- [ ] **Step 6: Delete `lua/chadrc.lua`** (`git rm lua/chadrc.lua`).

- [ ] **Step 7: Verify the purge is complete and nvim boots**

Run: `grep -rn -e nvchad -e base46 -e chadrc -e nvconfig init.lua lua/ || echo CLEAN`
Expected: `CLEAN`.

Run: `nvim --headless +qa 2>&1`
Expected: empty (first boot without NvChad).

Run: `nvim --headless "+lua print(vim.g.colors_name)" +qa`
Expected: prints `habamax`.

Run: `nvim --headless "+lua print(vim.fn.maparg('<leader>x', 'n') ~= '' and vim.fn.maparg('<tab>', 'n') ~= '')" +qa`
Expected: prints `true` (buffer close + cycle maps exist).

Run: `nvim --headless "+lua print(vim.fn.exists(':Telescope') .. vim.fn.exists(':NvimTreeToggle'))" +qa`
Expected: `22`.

- [ ] **Step 8: Commit**

```bash
git add init.lua lua/options.lua lua/mappings.lua lua/configs/lazy.lua lua/configs/nvimtree.lua
git rm lua/chadrc.lua
git commit -m "cutover: drop NvChad import, base46 caches and chadrc; builtin colorscheme/statusline; inline options/mappings"
```

---

### Task 5: Lockfile regeneration, README, final verification

**Files:**
- Modify: `lazy-lock.json` (regenerated by lazy, not hand-edited)
- Modify: `README.md`

**Interfaces:** none.

- [ ] **Step 1: Regenerate the lockfile (this PRUNES the nvchad repos from `~/.local/share/nvim/lazy/`)**

Run: `nvim --headless "+Lazy! sync" +qa 2>&1`
Expected: completes silently. Then `git diff --stat lazy-lock.json` must show changes and `grep -c "NvChad\|base46\|\"ui\"\|\"volt\"\|\"menu\"\|\"minty\"" lazy-lock.json` must return `0`, while `grep -c "\"telescope.nvim\"\|\"gitsigns.nvim\"\|\"which-key.nvim\"\|\"plenary.nvim\"" lazy-lock.json` must return `4` (kept plugins survived the prune).

- [ ] **Step 2: Update `README.md`** — replace the title/intro so it no longer presents this as a myNvChad install (clone URLs stay valid). Result should read:

````markdown
# my nvim config

Standalone Neovim config (NvChad removed): lazy.nvim, mason + nvim-lspconfig,
nvim-cmp, treesitter (main branch), telescope, nvim-tree, gitsigns,
indent-blankline, which-key, conform, none-ls (cspell). Builtin colorscheme
(habamax) and statusline.

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
nvim --headless "+lua print(vim.g.colors_name)" +qa       # [habamax]
grep -rn -e nvchad -e base46 -e chadrc -e nvconfig init.lua lua/ # [no hits]
grep -c "NvChad\|base46" lazy-lock.json                   # [0]
git status --short                                        # [only README/lazy-lock staged or clean]
```

Then an interactive smoke test by the user: open a Lua file (treesitter highlighting, cmp completion, `gd`/`K`/`<leader>ra` via lua_ls), `<C-n>` tree, `<leader>ff` telescope, `<tab>`/`<S-tab>` buffer cycling, `<leader>x` buffer close, gitsigns gutter in a git repo.

- [ ] **Step 4: Commit**

```bash
git add lazy-lock.json README.md
git commit -m "post-purge: regenerate lazy-lock, update README"
```

---

## Rollback

Branch `remove-nvchad` only; `main` is untouched. Any broken intermediate state: `git checkout -- .` or `git switch main`. Note: Task 5's `:Lazy! sync` deletes the NvChad plugin dirs from `~/.local/share/nvim/lazy/` — to restore them after switching back to `main`, run `nvim --headless "+Lazy! sync" +qa` there (and `nvim --headless "+Lazy! restore" +qa` if the lockfile drifted).
