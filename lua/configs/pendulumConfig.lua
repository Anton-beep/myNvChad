require("pendulum").setup({
  log_file = vim.env.HOME .. "/pendulum-log.csv",
  timeout_len = 180,
  timer_len = 120,
  gen_reports = true,
  top_n = 5,
  hours_n = 10,
  time_format = "12h",
  time_zone = "UTC",   -- Format "America/New_York"
  report_excludes = {
    branch = {},
    directory = {},
    file = {},
    filetype = {},
    project = {},
  },
  report_section_excludes = {},
})
