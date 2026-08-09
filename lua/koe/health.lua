local M = {}

function M.check()
  local health = vim.health
  health.start("koe")

  if vim.fn.has("mac") == 0 then
    health.error("macOS のみ対応")
    return
  end

  local ver = vim.trim(vim.fn.system("sw_vers -productVersion"))
  local major = tonumber(ver:match("^(%d+)")) or 0
  if major >= 26 then
    health.ok("macOS " .. ver)
  else
    health.error("macOS 26+ が必要 (SpeechTranscriber)", { "macOS 15 なら hear ラッパを検討" })
  end

  local cmd = require("koe").helper_cmd()
  if vim.fn.executable(cmd) == 1 then
    health.ok("helper: " .. cmd)
  else
    health.error("同梱 helper が利用できません: " .. cmd, { "macOS 26 / Apple silicon 版を再インストールしてください" })
  end

  if vim.env.TMUX then
    health.warn("tmux 配下: TCC プロンプトが表示されない可能性あり(未検証)")
  end

  local term = vim.env.TERM_PROGRAM or "unknown"
  health.info("terminal: " .. term .. "(マイク TCC はターミナルアプリに帰属)")
end

return M
