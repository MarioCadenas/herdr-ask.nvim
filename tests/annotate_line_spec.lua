-- Normal-mode annotate captures the current line (no visual selection).
local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local ha = require("herdr-ask")
H.project({ ["a.lua"] = { "one", "two", "three" } })
ha.setup({})
H.stub_transport(ha)
local A = require("herdr-ask.annotations")

vim.cmd("edit a.lua")
vim.api.nvim_win_set_cursor(0, { 2, 0 }) -- cursor on line 2
ha.annotate({ line = true })
H.ok(vim.wait(2000, function()
  return vim.api.nvim_buf_get_name(0):match("herdr%-ask://note") ~= nil
end, 20), "note float opened")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "line note" })
vim.cmd("silent write"); vim.wait(150)

H.eq(A.info().count, 1, "one annotation")
local item = vim.json.decode(table.concat(vim.fn.readfile(A.info().path), "\n")).items[1]
H.eq(item.lnum, 2, "captured current line lnum")
H.eq(item.end_lnum, 2, "single-line range")
H.pass()
