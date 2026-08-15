local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local ha = require("herdr-ask")
H.project({ ["f.lua"] = { "a", "b", "c", "d" } })
ha.setup({ focus_after_send = false })
local cap = H.stub_transport(ha)
local A = require("herdr-ask.annotations")

-- Menu -> first annotation entry; action sub-menu -> "Send now".
vim.ui.select = function(items, _, cb)
  for _, x in ipairs(items) do
    if x == "Send now" then return cb("Send now") end
  end
  for _, x in ipairs(items) do
    if type(x) == "table" and x.kind == "item" then return cb(x) end
  end
  return cb(items[1])
end

H.annotate(ha, "f.lua", 1, 1, "first")
H.annotate(ha, "f.lua", 3, 3, "second")
H.eq(A.info().count, 2, "two pending")

A.menu()
vim.wait(300)
H.ok(cap.args ~= nil, "single send did not fire")
local msg = cap.args[4]
H.ok(msg:find("@f%.lua#L1 — first"), "sent the picked annotation")
H.ok(not msg:find("second"), "did not send the other annotation")
H.eq(A.info().count, 1, "picked annotation removed from batch")
H.pass()
