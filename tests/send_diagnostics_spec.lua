-- Same class as note_diagnostics: the markdown send/compose float can attract
-- linter diagnostics that must not outlive the wiped buffer.
local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local ha = require("herdr-ask")
H.project({ ["a.lua"] = { "x", "y", "z" } })
ha.setup({ focus_after_send = false })
H.stub_transport(ha)

H.annotate(ha, "a.lua", 1, 2, "note")
require("herdr-ask.annotations").send(false)
H.ok(vim.wait(2000, function()
  return vim.api.nvim_buf_get_name(0):match("herdr%-ask://send") ~= nil
end, 20), "compose float opened")

local send_buf = vim.api.nvim_get_current_buf()
local ns = vim.api.nvim_create_namespace("fake-linter")
vim.diagnostic.set(ns, send_buf, { { lnum = 0, col = 0, message = "MD", severity = 1 } })
H.ok(#vim.diagnostic.get(send_buf) >= 1, "diagnostic attached to send buffer")

vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
vim.wait(300)
H.ok(not vim.api.nvim_buf_is_valid(send_buf), "send buffer wiped after send")
for _, d in ipairs(vim.diagnostic.get()) do
  H.ok(d.bufnr ~= send_buf, "no diagnostic left pointing at the wiped send buffer")
end
H.pass()
