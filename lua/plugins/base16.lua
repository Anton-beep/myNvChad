return {
  "RRethy/base16-nvim",
  -- theme collection: ships colors/base16-*.vim, so `:colorscheme base16-*` only finds them
  -- while the plugin is on the runtimepath (an unloaded lazy spec is not there). Loaded first
  -- so the UI plugins that read the colourscheme while they set up see it settle.
  lazy = false,
  priority = 1000,
}
