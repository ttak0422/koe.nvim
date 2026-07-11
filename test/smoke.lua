-- headless check of the NDJSON -> insert path using a fake helper
vim.opt.rtp:prepend(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))))

local koe = require("koe")
koe.setup({ cmd = "test/fake-helper.sh" })
koe.start()

vim.wait(2000, function()
  return vim.fn.getline(1):find("こんにちは、世界。") ~= nil
end)

assert(vim.fn.getline(1):find("こんにちは、世界。"), "expected final text, got: " .. vim.fn.getline(1))
print("OK")
