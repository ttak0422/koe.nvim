-- Health checks must not record audio or request microphone permission.
vim.opt.rtp:prepend(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))))

local messages = {}
for _, level in ipairs({ "start", "ok", "error", "warn", "info" }) do
  vim.health[level] = function(message)
    table.insert(messages, { level = level, text = message })
  end
end
vim.fn.has = function(feature)
  assert(feature == "mac")
  return 1
end
vim.fn.system = function(command)
  assert(command == "sw_vers -productVersion", "unexpected process: " .. command)
  return "26.5\n"
end
vim.fn.executable = function()
  return 1
end
vim.env.TMUX = nil

local function check(version, expected_level)
  messages = {}
  vim.g.neovide = true
  vim.g.neovide_version = version
  require("koe.health").check()
  local neovide
  for _, message in ipairs(messages) do
    assert(message.level ~= "error", message.text)
    if message.text:find("Neovide", 1, true) then
      assert(not neovide, "duplicate Neovide diagnostic")
      neovide = message
    end
  end
  assert(neovide and neovide.level == expected_level, "unexpected diagnostic for " .. tostring(version))
  if expected_level == "warn" then
    assert(neovide.text:find("official macOS builds lack", 1, true))
  else
    assert(neovide.text:find("verify that this build includes", 1, true))
  end
end

check("0.15.1", "warn")
check("0.16.2", "warn")
check("0.16.3", "info")
check("0.17.0", "info")
check("nightly-111+g4f76517", "info")
check("0.16.2-dirty", "info")
check("unknown", "info")
check(nil, "info")

messages = {}
vim.g.neovide = nil
require("koe.health").check()
for _, message in ipairs(messages) do
  assert(not message.text:find("Neovide", 1, true), "Neovide diagnostic outside Neovide")
end
print("OK: health diagnostics")
