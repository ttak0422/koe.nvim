local M = {}

M.config = {
  cmd = nil, -- helper path override; nil resolves to the bundled binary
  locale = "ja-JP",
  hl = "Comment", -- highlight group for listening status and preview text
  listening_text = "● Listening…",
  shutdown_timeout_ms = 2000,
}

local ns = vim.api.nvim_create_namespace("koe")
local state = { job = nil, extmark = nil, buf = nil, pending = "", inserted = false, stopping = false }

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

local function show_status(text)
  clear_ghost()
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local status = state.stopping and "● Stopping…" or M.config.listening_text
  if text ~= "" then
    status = status .. " " .. text
  end
  state.buf = buf
  state.extmark = vim.api.nvim_buf_set_extmark(buf, ns, row - 1, col, {
    virt_text = { { status, M.config.hl } },
    virt_text_pos = "inline",
  })
end

local function insert_text(text)
  clear_ghost()
  if text == "" then
    show_status("")
    return
  end
  if state.inserted then
    pcall(vim.cmd.undojoin) -- keep one dictation session as a single undo unit
  end
  vim.api.nvim_paste(text .. "\n", false, -1)
  state.inserted = true
  show_status("")
end

local function handle(line)
  local ok, ev = pcall(vim.json.decode, line)
  if not ok or type(ev) ~= "table" then
    return
  end
  if ev.e == "volatile" then
    show_status(ev.text or "")
  elseif ev.e == "final" then
    insert_text(ev.text or "")
  elseif ev.e == "ready" then
    show_status("")
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
  state.pending, state.inserted, state.stopping = "", false, false
  local cmd = M.helper_cmd()
  if vim.fn.executable(cmd) ~= 1 then
    vim.notify("koe: bundled helper is unavailable: " .. cmd, vim.log.levels.ERROR)
    return
  end
  local job = vim.fn.jobstart({ cmd, "--locale", M.config.locale }, {
    on_stdout = on_stdout,
    on_exit = vim.schedule_wrap(function(_, code)
      state.job = nil
      state.stopping = false
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
  show_status("")
end

function M.stop()
  if not state.job then
    return
  end
  state.stopping = true
  show_status("")
  -- closing stdin makes the helper finalize and exit 0 (graceful stop)
  pcall(vim.fn.chanclose, state.job, "stdin")
end

local function shutdown()
  if not state.job then
    return
  end

  local job = state.job
  state.stopping = true
  pcall(vim.fn.chanclose, job, "stdin")

  local result = vim.fn.jobwait({ job }, M.config.shutdown_timeout_ms)[1]
  if result == -1 then
    pcall(vim.fn.jobstop, job)
    vim.fn.jobwait({ job }, 200)
  end

  state.job = nil
  state.stopping = false
  clear_ghost()
end

function M.toggle()
  if state.job then
    M.stop()
  else
    M.start()
  end
end

function M.is_running()
  return state.job ~= nil
end

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
  local group = vim.api.nvim_create_augroup("koe", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = shutdown,
    desc = "Gracefully stop koe before Neovim exits",
  })
end

return M
