local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local ha = require("herdr-ask")
H.project({ ["g.lua"] = { "a", "b", "c" } })
ha.setup({ focus_after_send = false })
local cap = H.stub_transport(ha, { agent = { agent_status = "working" } })
local notes = H.capture_notifications()
local A = require("herdr-ask.annotations")

H.annotate(ha, "g.lua", 1, 2, "note")
A.send(false); H.confirm_send(true)
H.ok(cap.args ~= nil, "still sent to a busy agent")
local warned = false
for _, m in ipairs(notes) do
  if type(m.msg) == "string" and m.msg:find("busy") then warned = true end
end
H.ok(warned, "warned that the target agent is busy")
H.pass()
