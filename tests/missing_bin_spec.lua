local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local ha = require("herdr-ask")
H.project({ ["x.lua"] = { "hello" } })
ha.setup({
  focus_after_send = false,
  herdr_bin = "/tmp/herdr-ask-missing-bin-for-tests",
})
local notes = H.capture_notifications()

-- Force the workspace check to pass so we reach `herdr agent list` (CI has no
-- HERDR_WORKSPACE_ID); the missing binary then surfaces there.
vim.env.HERDR_WORKSPACE_ID = "w-test"

vim.cmd("edit x.lua")
local b = vim.api.nvim_get_current_buf()
vim.fn.setpos("'<", { b, 1, 1, 0 })
vim.fn.setpos("'>", { b, 1, 1, 0 })

local ok = pcall(function()
  ha.send_ref({ global = true })
  vim.wait(400)
end)
H.ok(ok, "send_ref must not throw when herdr binary is missing")

local notified = false
for _, m in ipairs(notes) do
  if type(m.msg) == "string" and m.msg:find("herdr agent list") then
    notified = true
  end
end
H.ok(notified, "missing binary surfaces as a notify error")
H.pass()
