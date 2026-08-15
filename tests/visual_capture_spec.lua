local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local cap = require("herdr-ask")._internal.capture_selection
local got
vim.keymap.set("x", "X", function() got = cap() end)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "aa", "bb", "cc", "dd", "ee" })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("Vjj", true, false, true), "x", false)
vim.api.nvim_feedkeys("X", "x", false)
H.ok(got ~= nil, "capture returned nil in visual mode")
H.eq(got.lnum, 2, "start line"); H.eq(got.end_lnum, 4, "end line"); H.eq(got.range, "L2-4", "range string")
H.pass()
