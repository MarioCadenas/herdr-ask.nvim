local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local ha = require("herdr-ask")
H.project({ ["z.lua"] = { "a", "b", "c" } })
ha.setup({ focus_after_send = false })
local sent = false
ha._internal.pick_agent = function(_, cb) sent = true; cb("p") end
ha._internal.herdr = function() return { code = 0 } end
ha._internal.focus = function() end
local A = require("herdr-ask.annotations")

H.annotate(ha, "z.lua", 1, 2, "n")
A.send(false)
H.confirm_send(false) -- <Esc> cancels
H.ok(not sent, "<Esc> must not send")
H.eq(A.info().count, 1, "batch intact after cancel")
H.ok(not (vim.api.nvim_buf_get_name(0):match("herdr%-ask://send")), "compose float closed")
H.pass()
