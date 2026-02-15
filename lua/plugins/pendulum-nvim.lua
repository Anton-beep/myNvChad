return {
  "ptdewey/pendulum-nvim",
  config = function()
    require("pendulum").setup({
      gen_reports = false,
    })
  end,
}

