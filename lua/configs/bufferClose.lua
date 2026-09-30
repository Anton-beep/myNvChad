-- Close a buffer without letting Neovim close the window that showed it.
--
-- `:bdelete` closes every window displaying the deleted buffer as long as another window is
-- left in the tabpage (`:h :bdelete`, "Any windows for this buffer are closed"). With the
-- explorer in its own window, closing the last file buffer therefore closes the editor
-- window and leaves the explorer filling the tabpage while the remaining tabs stay hidden.
-- So: show a sibling buffer in the windows displaying the target first, then delete it.
-- The windows keep their place in the layout and `:bdelete` finds no window to close.

local M = {}

---Buffers that may take the place of a closed one, in the order the user sees them: the
---bufferline order first, then buffer number for anything the tabline does not show.
---Plain file buffers come before terminal buffers; the explorer's buffer is unlisted and so
---is never a candidate.
---@return integer[]
local function ordered_candidates()
  local seen, files, terminals = {}, {}, {}

  local function add(buf)
    if seen[buf] or not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted then
      return
    end
    local buftype = vim.bo[buf].buftype
    if buftype == "" then
      files[#files + 1] = buf
    elseif buftype == "terminal" then
      terminals[#terminals + 1] = buf
    else
      return
    end
    seen[buf] = true
  end

  local ok, bufferline = pcall(require, "bufferline")
  if ok then
    local ok_elements, elements = pcall(bufferline.get_elements)
    if ok_elements and elements and elements.elements then
      for _, element in ipairs(elements.elements) do
        add(element.id)
      end
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    add(buf)
  end

  return vim.list_extend(files, terminals)
end

---The buffer that should take the place of `closed`: the next one in the tabline order,
---falling back to the previous one (like closing a browser tab: the tab to the right, or the
---tab to the left when it was the last). nil when nothing else is open.
---@param closed integer
---@return integer|nil
function M.replacement(closed)
  local candidates = ordered_candidates()
  local index
  for i, buf in ipairs(candidates) do
    if buf == closed then
      index = i
      break
    end
  end

  if not index then
    return candidates[1]
  end
  return candidates[index + 1] or candidates[index - 1]
end

---Close `bufnr` (default: the current buffer) and keep the windows that showed it alive.
---@param bufnr integer|nil
---@param force boolean|nil discard unsaved changes (same as `:bdelete!`)
---@return boolean closed
function M.close(bufnr, force)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local bang = force and "!" or ""

  -- Non-file buffers (the explorer, prompts, ...) keep Neovim's own behaviour.
  if not vim.bo[bufnr].buflisted or vim.bo[bufnr].buftype ~= "" then
    local ok, err = pcall(vim.cmd, "bdelete" .. bang .. " " .. bufnr)
    if not ok then
      vim.api.nvim_err_writeln(err)
    end
    return ok
  end

  -- `:bdelete` refuses to discard changes; check before touching any window so that a
  -- refusal leaves the layout exactly as it was.
  if not force and vim.bo[bufnr].modified then
    vim.api.nvim_err_writeln(("E89: No write since last change for buffer %d (add ! to override)"):format(bufnr))
    return false
  end

  local replacement = M.replacement(bufnr)
  local empty
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      if replacement then
        pcall(vim.api.nvim_win_set_buf, win, replacement)
      else
        -- nothing left to show: leave an empty buffer so the window survives
        empty = empty or vim.api.nvim_create_buf(true, false)
        pcall(vim.api.nvim_win_set_buf, win, empty)
      end
    end
    -- floating windows are skipped: `:bdelete` closing them is the desired outcome
  end

  local ok, err = pcall(vim.cmd, "bdelete" .. bang .. " " .. bufnr)
  if not ok then
    vim.api.nvim_err_writeln(err)
  end
  return ok
end

---Entry point for bufferline's close icon / right click. bufferline runs those handlers
---while the tabline is drawn, so the layout work is deferred (as bufferline itself does for
---string commands), and unsaved changes are discarded like its default `bdelete! %d` did.
---@param bufnr integer
function M.close_tab(bufnr)
  vim.schedule(function()
    M.close(bufnr, true)
  end)
end

return M
