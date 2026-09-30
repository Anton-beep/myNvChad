return {
  "zaldih/themery.nvim",
  -- theme picker with live preview. VimEnter on purpose: setup() re-applies the theme saved in
  -- stdpath("data")/themery/state.json, which has to happen after options.lua picked the startup
  -- colourscheme (a lazy = false plugin is set up during lazy.setup, i.e. before options.lua).
  event = "VimEnter",
  -- :Themery is defined by the plugin; also reachable before VimEnter (e.g. from -c commands)
  cmd = { "Themery" },
  -- setup() is called from a scheduled callback instead of by lazy.nvim directly: restoring the
  -- saved theme runs `:colorscheme`, and a colourscheme applied from inside an autocommand fires no
  -- ColorScheme event (nested autocommands are suppressed while lazy.nvim handles VimEnter). Hooks
  -- that re-apply theme-derived colours would then keep the pre-restore state -- nvim-web-devicons
  -- showed it as colourless file icons until the next :colorscheme. Scheduled, the event is
  -- delivered like any interactive switch.
  config = function()
    vim.schedule(function()
      require("themery").setup {
        -- every colourscheme nvim can load right now: the base16 collection plus the builtins.
        -- themery normalizes each string to { name = <scheme>, colorscheme = <scheme> }
        themes = vim.fn.getcompletion("", "color"),
        livePreview = true,
      }
    end)
  end,
}
