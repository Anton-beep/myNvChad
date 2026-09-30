return {
  "amansingh-afk/milli.nvim",
  lazy = false,
  config = function()
    require("milli").vimenter { splash = "lights", loop = true }
  end,
}
