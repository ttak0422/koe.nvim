local M = {}

M.config = {
  cmd = nil, -- helper path; nil resolves to bin/koe-helper in this repo
  locale = "ja-JP",
  hl = "Comment", -- highlight group for ghost text
}

local ns = vim.api.nvim_create_namespace("koe")
local state = { job = nil, extmark = nil, buf = nil, pending = "", inserted = false }

function M.helper_cmd()
  if M.config.cmd then
    return M.config.cmd
  end
  local src = debug.getinfo(1, "S").source:sub(2)
  local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(src)))
  return root .. "/bin/koe-helper"
end

local function clear_ghost()
  if state.extmark and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_del_extmark(state.buf, ns, state.extmark)
  end
  state.extmark = nil
end

local function show_ghost(text)
  clear_ghost()
  if text == "" then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  state.buf = buf
  state.extmark = vim.api.nvim_buf_set_extmark(buf, ns, row - 1, col, {
    virt_text = { { text, M.config.hl } },
    virt_text_pos = "inline",
  })
end

local function insert_text(text)
  clear_ghost()
  if text == "" then
    return
  end
  if state.inserted then
    pcall(vim.cmd.undojoin) -- keep one dictation session as a single undo unit
  end
  vim.api.nvim_paste(text, false, -1)
  state.inserted = true
end

local function handle(line)
  local ok, ev = pcall(vim.json.decode, line)
  if not ok or type(ev) ~= "table" then
    return
  end
  if ev.e == "volatile" then
    show_ghost(ev.text or "")
  elseif ev.e == "final" then
    insert_text(ev.text or "")
  elseif ev.e == "ready" then
    vim.notify("koe: listening (" .. M.config.locale .. ")")
  elseif ev.e == "error" then
    vim.notify("koe: " .. (ev.message or "error"), vim.log.levels.ERROR)
  end
end

local function on_stdout(_, data)
  -- channel-lines: first entry continues the previous partial line, last entry is incomplete
  data[1] = state.pending .. data[1]
  state.pending = table.remove(data)
  for _, line in ipairs(data) do
    if line ~= "" then
      vim.schedule(function()
        handle(line)
      end)
    end
  end
end

function M.start()
  if state.job then
    return
  end
  state.pending, state.inserted = "", false
  local cmd = M.helper_cmd()
  local job = vim.fn.jobstart({ cmd, "--locale", M.config.locale }, {
    on_stdout = on_stdout,
    on_exit = vim.schedule_wrap(function(_, code)
      state.job = nil
      clear_ghost()
      if code ~= 0 then
        vim.notify("koe: helper exited with " .. code, vim.log.levels.WARN)
      else
        vim.notify("koe: stopped")
      end
    end),
  })
  if job <= 0 then
    vim.notify("koe: failed to start " .. cmd, vim.log.levels.ERROR)
    return
  end
  state.job = job
end

function M.stop()
  if not state.job then
    return
  end
  -- closing stdin makes the helper finalize and exit 0 (graceful stop)
  pcall(vim.fn.chanclose, state.job, "stdin")
end

function M.toggle()
  if state.job then
    M.stop()
  else
    M.start()
  end
end

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = vim.api.nvim_create_augroup("koe", {}),
    callback = clear_ghost,
  })
end

return M
