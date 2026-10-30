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

  if vim.g.neovide then
    local version = tostring(vim.g.neovide_version or "unknown")
    -- Nightly/custom versions cannot establish which signing pipeline was used.
    if version:match("^%d+%.%d+%.%d+$") and vim.version.le(version, { 0, 16, 2 }) then
      health.warn(
        "Neovide " .. version .. " official macOS builds lack the com.apple.security.device.audio-input entitlement",
        {
          "Use a build containing the signing fix: https://github.com/neovide/neovide/pull/3585",
          "See README: Neovide on macOS; microphone permission is still required",
        }
      )
    else
      health.info(
        "Neovide " .. version .. ": verify that this build includes the audio-input signing fix (#3585); see README: Neovide on macOS"
      )
    end
  end

  local term = vim.env.TERM_PROGRAM or "unknown"
  health.info("terminal: " .. term)
  health.info("microphone permission belongs to the app running Neovim")
end

return M
