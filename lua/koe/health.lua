local M = {}

function M.check()
  local health = vim.health
  health.start("koe")

  if vim.fn.has("mac") == 0 then
    health.error("koe.nvim supports macOS only")
    return
  end

  local ver = vim.trim(vim.fn.system("sw_vers -productVersion"))
  local major = tonumber(ver:match("^(%d+)")) or 0
  if major >= 26 then
    health.ok("macOS " .. ver)
  else
    health.error("macOS 26 or later is required for SpeechTranscriber")
  end

  local cmd = require("koe").helper_cmd()
  if vim.fn.executable(cmd) == 1 then
    health.ok("helper: " .. cmd)
  else
    health.error("bundled helper is unavailable: " .. cmd, { "Reinstall the macOS 26 / Apple silicon release" })
  end

  if vim.env.TMUX then
    health.warn("tmux may prevent the macOS permission prompt from appearing (unverified)")
  end

  local term = vim.env.TERM_PROGRAM or "unknown"
  health.info("terminal: " .. term)
  health.info("microphone permission belongs to the app running Neovim")
end

return M
