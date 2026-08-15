-- herdr-ask.nvim: send a visual selection to a Herdr agent pane over the
-- `herdr` CLI. See M.ask (submit question + code) and M.send_ref (stage a ref).

local M = {}

M.config = {
  -- Path to the herdr binary.
  herdr_bin = "herdr",
  -- Focus the target pane after sending.
  focus_after_send = true,
  -- Restrict to these agent kinds (e.g. {"claude","codex"}); nil = any.
  agent_kinds = nil,
  -- Prompt shown by the ask input.
  prompt = "Ask agent ▸ ",
  -- Build the file reference. `range` is "L4" or "L4-10".
  format_ref = function(relpath, range)
    return ("@%s#%s"):format(relpath, range)
  end,
  -- Build the message submitted by `ask`.
  format_message = function(question, ref, filetype, code)
    return ("%s\n\n%s\n```%s\n%s\n```"):format(question, ref, filetype, code)
  end,
  -- Annotations: collect ref+note pairs across files, flush as one batch.
  annotations = {
    clear_after_send = true,          -- clear the batch after a successful send
    include_code = false,             -- fence the referenced code under each bullet
    signs = true,                     -- gutter sign + virtual-text note on annotated lines
    default_instruction = "Review these annotations.",
  },
  -- Keymaps; set an entry (or the whole table) to false to skip.
  keymaps = {
    ask = "<leader>ai",
    ask_global = "<leader>aI",
    ref = "<leader>ar",
    ref_global = "<leader>aR",
    annotate = "<leader>aa",
    menu = "<leader>al",
  },
}

local function notify(msg, level)
  vim.notify("herdr-ask: " .. msg, level or vim.log.levels.INFO)
end

-- vim.system throws on spawn failure (ENOENT / bad path); normalize to a result.
local function herdr(args)
  local cmd = { M.config.herdr_bin }
  vim.list_extend(cmd, args)
  local ok, handle = pcall(vim.system, cmd, { text = true })
  if not ok then
    return { code = -1, stdout = "", stderr = tostring(handle) }
  end
  return handle:wait()
end

-- Whole-line capture. In visual mode the '<,'> marks aren't set yet, so read the
-- live `v`/`.` positions; after visual ends (which-key, :range) fall back to marks.
local function capture_selection()
  local mode = vim.fn.mode()
  local l1, l2
  if mode == "v" or mode == "V" or mode == "\22" then
    l1, l2 = vim.fn.line("v"), vim.fn.line(".")
  else
    l1, l2 = vim.fn.line("'<"), vim.fn.line("'>")
  end
  if l1 == 0 or l2 == 0 then
    notify("no selection marks", vim.log.levels.WARN)
    return nil
  end
  if l1 > l2 then
    l1, l2 = l2, l1
  end
  return {
    text = table.concat(vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false), "\n"),
    relpath = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":."),
    filetype = vim.bo.filetype or "",
    range = (l1 == l2) and ("L" .. l1) or ("L" .. l1 .. "-" .. l2),
    lnum = l1,
    end_lnum = l2,
  }
end

-- All live Herdr agents (optionally filtered by kind), current workspace first.
local function list_agents(ws)
  local res = herdr({ "agent", "list" })
  if res.code ~= 0 then
    notify("`herdr agent list` failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
    return {}
  end
  local ok, decoded = pcall(vim.json.decode, res.stdout)
  if not ok then
    notify("could not parse `herdr agent list` output", vim.log.levels.ERROR)
    return {}
  end
  local agents = (decoded.result or {}).agents or {}
  if M.config.agent_kinds then
    local keep = {}
    for _, k in ipairs(M.config.agent_kinds) do
      keep[k] = true
    end
    agents = vim.tbl_filter(function(a)
      return keep[a.agent]
    end, agents)
  end
  table.sort(agents, function(a, b)
    local aw, bw = a.workspace_id == ws, b.workspace_id == ws
    if aw ~= bw then
      return aw -- current-workspace agents sort to the top
    end
    return (a.pane_id or "") < (b.pane_id or "")
  end)
  return agents
end

local function agent_label(a)
  local title = a.terminal_title_stripped or a.terminal_title or a.workspace_id or "?"
  return ("%s · %s · %s [%s]"):format(a.agent or "?", title, a.pane_id or "?", a.agent_status or "?")
end

-- Pick a target and call cb(pane_id, agent); global=false limits to current workspace.
local function pick_agent(global, cb)
  local ws = vim.env.HERDR_WORKSPACE_ID
  if ws == nil then
    notify("not inside a Herdr pane (HERDR_WORKSPACE_ID unset)", vim.log.levels.ERROR)
    return
  end
  local agents = list_agents(ws)
  local candidates = global and agents
    or vim.tbl_filter(function(a)
      return a.workspace_id == ws
    end, agents)
  if #candidates == 0 then
    notify("no agents to send to in " .. (global and "any workspace" or "this workspace"), vim.log.levels.ERROR)
    return
  end
  if #candidates == 1 then
    cb(candidates[1].pane_id, candidates[1])
    return
  end
  vim.ui.select(candidates, { prompt = "Send to agent", format_item = agent_label }, function(choice)
    if choice then
      cb(choice.pane_id, choice)
    end
  end)
end

local function focus(pane)
  if M.config.focus_after_send then
    herdr({ "agent", "focus", pane })
  end
end

--- Prompt for a question, then submit it with the selection ref + code to a pane.
--- @param o table|nil { global = boolean }
function M.ask(o)
  local sel = capture_selection()
  if not sel then
    return
  end
  local global = o and o.global or false
  -- Defer so the input float opens cleanly on the next tick.
  vim.schedule(function()
    vim.ui.input({ prompt = M.config.prompt }, function(input)
      if not input or input == "" then
        return
      end
      pick_agent(global, function(pane)
        local ref = M.config.format_ref(sel.relpath, sel.range)
        local msg = M.config.format_message(input, ref, sel.filetype, sel.text)
        local res = herdr({ "agent", "prompt", pane, msg })
        if res.code ~= 0 then
          notify("`herdr agent prompt` failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
          return
        end
        focus(pane)
      end)
    end)
  end)
end

--- Stage just the selection reference in a chosen pane's input (no submit).
--- @param o table|nil { global = boolean }
function M.send_ref(o)
  local sel = capture_selection()
  if not sel then
    return
  end
  local global = o and o.global or false
  local ref = M.config.format_ref(sel.relpath, sel.range) .. " "
  vim.schedule(function()
    pick_agent(global, function(pane)
      local res = herdr({ "pane", "send-text", pane, ref })
      if res.code ~= 0 then
        notify("`herdr pane send-text` failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
        return
      end
      focus(pane)
    end)
  end)
end

--- Annotate the current visual selection (ref + a note) into the batch.
function M.annotate()
  require("herdr-ask.annotations").add()
end

--- Open the annotations batch menu (review / send / clear).
function M.annotations_menu()
  require("herdr-ask.annotations").menu()
end

-- Helpers shared with the annotations module.
M._internal = {
  notify = notify,
  herdr = herdr,
  capture_selection = capture_selection,
  pick_agent = pick_agent,
  focus = focus,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  require("herdr-ask.annotations").setup()
  local km = M.config.keymaps
  if not km then
    return
  end
  local defs = {
    { km.ask, function() M.ask({ global = false }) end, "Ask agent about selection (this workspace)" },
    { km.ask_global, function() M.ask({ global = true }) end, "Ask agent about selection (any pane)" },
    { km.ref, function() M.send_ref({ global = false }) end, "Send selection ref to agent input (this workspace)" },
    { km.ref_global, function() M.send_ref({ global = true }) end, "Send selection ref to agent input (any pane)" },
    { km.annotate, function() M.annotate() end, "Annotate selection into batch", "v" },
    { km.menu, function() M.annotations_menu() end, "Open annotations batch menu", "n" },
  }
  for _, d in ipairs(defs) do
    if d[1] then
      vim.keymap.set(d[4] or "v", d[1], d[2], { silent = true, desc = d[3] })
    end
  end
end

return M
