return {
  "zaldih/themery.nvim",
  -- theme picker with live preview. VimEnter on purpose: setup() re-applies the theme saved in
  -- stdpath("data")/themery/state.json, which has to happen after options.lua picked the startup
  -- colourscheme (a lazy = false plugin is set up during lazy.setup, i.e. before options.lua).
  event = "VimEnter",
  -- :Themery is defined by the plugin; also reachable before VimEnter (e.g. from -c commands)
  cmd = { "Themery" },
  opts = function()
    return {
      -- every colourscheme nvim can load right now: the base16 collection plus the builtins.
      -- themery normalizes each string to { name = <scheme>, colorscheme = <scheme> }
      themes = vim.fn.getcompletion("", "color"),
      livePreview = true,
    }
  end,
}
