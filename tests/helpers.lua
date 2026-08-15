-- Shared test helpers. Loaded via dofile with $HERDR_TEST_ROOT set by run.sh.
local H = {}

function H.fail(m)
  io.stderr:write("ASSERT FAIL: " .. tostring(m) .. "\n")
  vim.cmd("cq")
end
function H.ok(c, m)
  if not c then H.fail(m or "expected truthy") end
end
function H.eq(a, b, m)
  if a ~= b then H.fail((m or "") .. " expected=" .. vim.inspect(b) .. " got=" .. vim.inspect(a)) end
end
function H.pass()
  -- Leading newline: headless vim.notify writes to stdout without one.
  io.stdout:write("\nHERDR_TEST_PASS\n")
  vim.cmd("qa!")
end

-- Fresh temp project; cd into it; write files given as { name = {lines...} }.
function H.project(files)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  vim.cmd("cd " .. dir)
  for name, lines in pairs(files or {}) do
    vim.fn.writefile(lines, dir .. "/" .. name)
  end
  return dir
end

-- Stub the herdr transport; returns a table whose .args holds the last prompt call.
function H.stub_transport(ha, opts)
  opts = opts or {}
  local cap = {}
  ha._internal.pick_agent = function(_, cb) cb(opts.pane or "pane-1", opts.agent) end
  ha._internal.herdr = function(a) cap.args = a; return { code = opts.code or 0, stderr = opts.stderr } end
  ha._internal.focus = function() end
  return cap
end

-- Record every vim.notify call into the returned list.
function H.capture_notifications()
  local notes = {}
  vim.notify = function(msg, level) notes[#notes + 1] = { msg = msg, level = level } end
  return notes
end

-- Drive the real annotate flow: select l1..l2 in `file`, type `note`, :w commit.
function H.annotate(ha, file, l1, l2, note)
  vim.cmd("edit " .. file)
  local b = vim.api.nvim_get_current_buf()
  vim.fn.setpos("'<", { b, l1, 1, 0 })
  vim.fn.setpos("'>", { b, l2, 1, 0 })
  ha.annotate()
  H.ok(vim.wait(2000, function()
    return vim.api.nvim_buf_get_name(0):match("herdr%-ask://note") ~= nil
  end, 20), "note float never opened for " .. file)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(note, "\n"))
  vim.cmd("silent write")
  vim.wait(150)
end

-- Wait for the compose float, then <CR> to send (send=false -> <Esc> cancels).
function H.confirm_send(send)
  H.ok(vim.wait(2000, function()
    return vim.api.nvim_buf_get_name(0):match("herdr%-ask://send") ~= nil
  end, 20), "compose float never opened")
  local key = send == false and "<Esc><Esc>" or "<CR>"
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "x", false)
  vim.wait(300)
end

return H
