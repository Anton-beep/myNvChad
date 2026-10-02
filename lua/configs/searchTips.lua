-- Show a rotating search tip when a search with / starts, at most once per
-- minute. noice routes messages containing "Search tip" to a popup window
-- (see plugins/noice.lua); without noice it falls back to native notify.

local tips = {
  [[Search tip — navigation
n / N     next / previous match
2n        skip the match you're on
:noh      clear highlights (<Esc> mapped)]],
  [[Search tip — word under cursor
*  /  #   whole word, forward / backward
g* / g#   same, but allows longer words]],
  [[Search tip — replace
cgn       edit this match, then . on each next
gn        next match as target: dgn, cgn, ygn]],
  [[Search tip — case
smartcase UPPER in pattern = case-sensitive
\c / \C   force insensitive / sensitive now]],
  [[Search tip — history
q/        search history as an editable buffer
<C-f>     same window, while still typing
<Up>      recall an older search]],
}

local last_shown = 0
local index = 0

vim.api.nvim_create_autocmd("CmdlineEnter", {
  pattern = "/",
  callback = function()
    local now = vim.uv.hrtime()
    if now - last_shown < 60 * 1e9 then
      return
    end
    last_shown = now
    index = index % #tips + 1
    vim.notify(tips[index], vim.log.levels.INFO)
  end,
})
