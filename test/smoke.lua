-- headless check of the NDJSON -> insert path using a fake helper
vim.opt.rtp:prepend(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))))

local koe = require("koe")
koe.setup({ cmd = "test/fake-helper.sh" })
koe.start()

vim.wait(2000, function()
  return vim.fn.getline(2):find("次の行です。") ~= nil
end)

assert(vim.fn.getline(1) == "こんにちは、世界。", "unexpected first line: " .. vim.fn.getline(1))
assert(vim.fn.getline(2) == "次の行です。", "unexpected second line: " .. vim.fn.getline(2))

local ns = vim.api.nvim_get_namespaces().koe
local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
assert(#marks == 1, "expected a listening extmark")
assert(vim.inspect(marks[1][4].virt_text):find("Listening", 1, true), "expected listening status")

koe.stop()
vim.wait(2000, function()
  return #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) == 0
end)
assert(#vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) == 0, "expected listening extmark to clear")

koe.start()
assert(koe.is_running(), "expected helper to restart")
vim.api.nvim_exec_autocmds("VimLeavePre", {})
assert(not koe.is_running(), "expected VimLeavePre to stop the helper")
print("OK")
