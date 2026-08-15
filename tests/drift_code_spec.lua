local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local ha = require("herdr-ask")
H.project({ ["x.lua"] = { "alpha", "beta", "gamma", "delta", "eps" } })
ha.setup({ focus_after_send = false, annotations = { include_code = true, clear_after_send = false } })
local cap = H.stub_transport(ha)
local A = require("herdr-ask.annotations")

H.annotate(ha, "x.lua", 2, 4, "note here")
local ns = vim.api.nvim_get_namespaces()["herdr-ask-annotations"]
vim.cmd("buffer x.lua")
H.eq(#vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), 1, "one extmark placed")

vim.api.nvim_buf_set_lines(0, 0, 0, false, { "new1", "new2" })
vim.cmd("silent write"); vim.wait(100)
local item = vim.json.decode(table.concat(vim.fn.readfile(A.info().path), "\n")).items[1]
H.eq(item.lnum, 4, "lnum shifted by 2"); H.eq(item.end_lnum, 6, "end_lnum shifted by 2")

A.send(false); H.confirm_send(true)
local msg = cap.args[4]
H.ok(msg:find("@x%.lua#L4%-6 — note here"), "ref uses shifted range")
H.ok(msg:find("```lua\nbeta\ngamma\ndelta\n```"), "fenced current code")
H.pass()
