return {
  "amansingh-afk/milli.nvim",
  -- animated ASCII splash on startup. Loaded eagerly because the animation is driven by the
  -- plugin's own VimEnter hook, and wired through the raw VimEnter preset since this config has
  -- no dashboard plugin (dashboard/alpha/snacks/mini.starter presets exist for those).
  lazy = false,
  config = function()
    require("milli").vimenter { splash = "lights", loop = true }
  end,
}
