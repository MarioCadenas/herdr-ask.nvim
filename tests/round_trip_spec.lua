-- await_reply: after sending, wait for the agent then show its reply in a split.
local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local ha = require("herdr-ask")
H.project({ ["a.lua"] = { "x", "y", "z" } })
ha.setup({ focus_after_send = false, annotations = { await_reply = true } })
H.stub_transport(ha)
-- Stub the async CLI: `agent read` returns the reply; `agent wait` returns ok.
ha._internal.herdr_async = function(args, cb)
  if table.concat(args, " "):find("read") then
    cb({ code = 0, stdout = "AGENT REPLY HERE\nsecond line" })
  else
    cb({ code = 0, stdout = "" })
  end
end

local A = require("herdr-ask.annotations")
H.annotate(ha, "a.lua", 1, 2, "note")
A.send(false)
H.confirm_send(true)

local function reply_buf()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b):match("herdr%-ask://reply") then return b end
  end
end
H.ok(vim.wait(4000, reply_buf, 50), "reply split opened") -- defer(1500)+async
local rb = reply_buf()
local content = table.concat(vim.api.nvim_buf_get_lines(rb, 0, -1, false), "\n")
H.ok(content:find("AGENT REPLY HERE"), "reply content shown")
H.eq(vim.bo[rb].modifiable, false, "reply buffer read-only")
H.pass()
