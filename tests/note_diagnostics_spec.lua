-- A linter (markdownlint) can attach diagnostics to the markdown note float.
-- When the float is wiped they must not outlive it, or consumers that scan
-- vim.diagnostic.get() by bufnr (snacks explorer) hit an invalid buffer id.
local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local ha = require("herdr-ask")
H.project({ ["a.lua"] = { "l1", "l2", "l3" } })
ha.setup({})

vim.cmd("edit a.lua")
local b = vim.api.nvim_get_current_buf()
vim.fn.setpos("'<", { b, 1, 1, 0 }); vim.fn.setpos("'>", { b, 2, 1, 0 })
ha.annotate()
H.ok(vim.wait(2000, function()
  return vim.api.nvim_buf_get_name(0):match("herdr%-ask://note") ~= nil
end, 20), "note float opened")

local note_buf = vim.api.nvim_get_current_buf()
local ns = vim.api.nvim_create_namespace("fake-linter")
vim.diagnostic.set(ns, note_buf, {
  { lnum = 0, col = 0, message = "MD041", severity = vim.diagnostic.severity.WARN },
})
H.ok(#vim.diagnostic.get(note_buf) >= 1, "diagnostic attached to note buffer")

-- Commit the note -> buffer is wiped.
vim.api.nvim_buf_set_lines(note_buf, 0, -1, false, { "a note" })
vim.cmd("silent write"); vim.wait(200)
H.ok(not vim.api.nvim_buf_is_valid(note_buf), "note buffer wiped after commit")

-- The wiped bufnr must not appear in any diagnostic (this is what broke snacks).
for _, d in ipairs(vim.diagnostic.get()) do
  H.ok(d.bufnr ~= note_buf, "no diagnostic left pointing at the wiped note buffer")
end
H.eq(require("herdr-ask.annotations").info().count, 1, "annotation still committed")
H.pass()
