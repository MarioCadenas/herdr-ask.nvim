-- herdr-ask annotations: collect ref+note pairs across files, then flush the
-- batch to a Herdr agent. State persists per project under stdpath("state").

local A = {}

local ns = vim.api.nvim_create_namespace("herdr-ask-annotations")
local group = vim.api.nvim_create_augroup("herdr-ask-annotations", { clear = true })

-- items: { relpath, lnum, end_lnum, note, filetype }; _buf/_mark track a loaded
-- buffer's extmark and are not persisted.
local state = { items = {}, path = nil, ready = false }

local function core()
  return require("herdr-ask")._internal
end
local function acfg()
  return require("herdr-ask").config.annotations or {}
end

local function notify(msg, level)
  core().notify(msg, level)
end

local function range_str(lnum, end_lnum)
  return lnum == end_lnum and ("L" .. lnum) or ("L" .. lnum .. "-" .. end_lnum)
end

-- Project-relative path of a buffer (matches stored item.relpath).
local function buf_relpath(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return nil
  end
  return vim.fn.fnamemodify(name, ":.")
end

local function project_root()
  local cwd = vim.uv.cwd()
  return vim.fs.root(cwd, ".git") or cwd
end

local function resolve_path()
  local dir = vim.fn.stdpath("state") .. "/herdr-ask"
  vim.fn.mkdir(dir, "p")
  return dir .. "/" .. vim.fn.sha256(project_root()) .. ".json"
end

local function save()
  local plain = {}
  for _, it in ipairs(state.items) do
    plain[#plain + 1] = {
      relpath = it.relpath,
      lnum = it.lnum,
      end_lnum = it.end_lnum,
      note = it.note,
      filetype = it.filetype,
    }
  end
  vim.fn.writefile({ vim.json.encode({ items = plain }) }, state.path)
end

local function load()
  if vim.fn.filereadable(state.path) == 0 then
    return
  end
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(state.path), "\n"))
  if ok and type(decoded) == "table" and type(decoded.items) == "table" then
    state.items = decoded.items
  end
end

local function virt_label(note)
  local first = vim.split(note or "", "\n")[1] or ""
  if vim.fn.strchars(first) > 40 then
    first = vim.fn.strcharpart(first, 0, 40) .. "…"
  end
  return "″ " .. first
end

-- Extmark tracks the item's range (always); decorate only when signs enabled.
local function mark_item(buf, it)
  local last = vim.api.nvim_buf_line_count(buf)
  local srow = math.min(it.lnum, last) - 1
  local erow = math.min(it.end_lnum, last) - 1
  local opts = { end_row = erow, right_gravity = false, end_right_gravity = true }
  if acfg().signs ~= false then
    opts.sign_text = "●"
    opts.sign_hl_group = "HerdrAskSign"
    opts.virt_text = { { virt_label(it.note), "HerdrAskVirtText" } }
    opts.virt_text_pos = "eol"
    opts.hl_mode = "combine"
  end
  it._buf = buf
  it._mark = vim.api.nvim_buf_set_extmark(buf, ns, srow, 0, opts)
end

local function place_marks(buf)
  local rel = buf_relpath(buf)
  if not rel then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, it in ipairs(state.items) do
    if it.relpath == rel then
      mark_item(buf, it)
    end
  end
end

-- Pull current extmark positions back into the stored line numbers.
local function refresh_from_marks(buf)
  for _, it in ipairs(state.items) do
    if it._buf == buf and it._mark and vim.api.nvim_buf_is_loaded(buf) then
      local pos = vim.api.nvim_buf_get_extmark_by_id(buf, ns, it._mark, { details = true })
      if pos[1] then
        it.lnum = pos[1] + 1
        it.end_lnum = (pos[3] and pos[3].end_row or pos[1]) + 1
      end
    end
  end
end

local function refresh_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      refresh_from_marks(buf)
    end
  end
end

local function unmark(it)
  if it._buf and it._mark and vim.api.nvim_buf_is_loaded(it._buf) then
    vim.api.nvim_buf_del_extmark(it._buf, ns, it._mark)
  end
  it._buf, it._mark = nil, nil
end

function A.setup()
  if state.ready then
    return
  end
  state.ready = true
  state.path = resolve_path()
  load()

  vim.api.nvim_set_hl(0, "HerdrAskSign", { default = true, link = "DiagnosticSignInfo" })
  vim.api.nvim_set_hl(0, "HerdrAskVirtText", { default = true, link = "Comment" })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(ev)
      place_marks(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(ev)
      refresh_from_marks(ev.buf)
      save()
    end,
  })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      place_marks(buf)
    end
  end
end

-- Floating scratch note buffer: `:w` commits (cb(text)), close cancels (cb(nil)).
local function edit_note(initial, cb)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_name(buf, "herdr-ask://note-" .. buf)
  if initial and initial ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(initial, "\n"))
  end

  local width = math.min(72, vim.o.columns - 4)
  local height = math.min(10, math.max(3, vim.o.lines - 6))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Annotate ▸ :w save · :q cancel ",
  })
  vim.wo[win].wrap = true
  if not initial or initial == "" then
    vim.cmd.startinsert()
  end

  local done = false
  local function finish(text)
    if done then
      return
    end
    done = true
    cb(text)
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      vim.bo[buf].modified = false
      local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      finish(text)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function()
      finish(nil)
    end,
  })
end

--- Annotate the current visual selection: capture the ref, prompt for a note.
function A.add()
  A.setup()
  local sel = core().capture_selection()
  if not sel then
    return
  end
  if not sel.relpath or sel.relpath == "" then
    notify("annotate: buffer has no file", vim.log.levels.WARN)
    return
  end
  vim.schedule(function()
    edit_note(nil, function(note)
      if not note or vim.trim(note) == "" then
        notify("annotation cancelled (empty note)", vim.log.levels.WARN)
        return
      end
      local it = {
        relpath = sel.relpath,
        lnum = sel.lnum,
        end_lnum = sel.end_lnum,
        note = note,
        filetype = sel.filetype,
      }
      state.items[#state.items + 1] = it
      local buf = vim.api.nvim_get_current_buf()
      if buf_relpath(buf) == it.relpath then
        mark_item(buf, it)
      end
      save()
      notify(("annotated %s (%d pending)"):format(range_str(it.lnum, it.end_lnum), #state.items))
    end)
  end)
end

local function remove_item(it)
  unmark(it)
  for i, x in ipairs(state.items) do
    if x == it then
      table.remove(state.items, i)
      break
    end
  end
  save()
end

function A.clear()
  for _, it in ipairs(state.items) do
    unmark(it)
  end
  state.items = {}
  save()
end

local function read_code(it)
  if it._buf and vim.api.nvim_buf_is_loaded(it._buf) then
    return table.concat(vim.api.nvim_buf_get_lines(it._buf, it.lnum - 1, it.end_lnum, false), "\n")
  end
  if vim.fn.filereadable(it.relpath) == 1 then
    local lines = vim.fn.readfile(it.relpath)
    return table.concat(vim.list_slice(lines, it.lnum, it.end_lnum), "\n")
  end
  return nil
end

-- Grouped by file; each bullet keeps the full @ref so Herdr resolves it
-- regardless of the header.
local function build_message(items, instruction)
  local by_file = {}
  local order = {}
  for _, it in ipairs(items) do
    if not by_file[it.relpath] then
      by_file[it.relpath] = {}
      order[#order + 1] = it.relpath
    end
    table.insert(by_file[it.relpath], it)
  end
  table.sort(order)

  local include_code = acfg().include_code
  local format_ref = require("herdr-ask").config.format_ref
  local parts = {}
  if instruction and instruction ~= "" then
    parts[#parts + 1] = instruction
  end
  for _, rel in ipairs(order) do
    local file_items = by_file[rel]
    table.sort(file_items, function(a, b)
      return a.lnum < b.lnum
    end)
    local lines = { "## " .. rel }
    for _, it in ipairs(file_items) do
      local ref = format_ref(it.relpath, range_str(it.lnum, it.end_lnum))
      local note = it.note:gsub("\n", "\n  ")
      lines[#lines + 1] = ("- %s — %s"):format(ref, note)
      if include_code then
        local code = read_code(it)
        if code then
          lines[#lines + 1] = ("```%s\n%s\n```"):format(it.filetype or "", code)
        end
      end
    end
    parts[#parts + 1] = table.concat(lines, "\n")
  end
  return table.concat(parts, "\n\n")
end

-- Pick an agent and submit `items` with `instruction` as the top line; on
-- success call on_ok(count).
local function deliver(items, global, instruction, on_ok)
  core().pick_agent(global, function(pane, agent)
    if agent and agent.agent_status == "working" then
      notify("target agent is busy (working) — sending anyway", vim.log.levels.WARN)
    end
    local msg = build_message(items, instruction)
    local res = core().herdr({ "agent", "prompt", pane, msg })
    if res.code ~= 0 then
      notify("`herdr agent prompt` failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
      return
    end
    core().focus(pane)
    on_ok(#items)
  end)
end

--- Preview the batch in a float, edit the top instruction line, <CR> to send.
function A.send(global)
  A.setup()
  if #state.items == 0 then
    notify("no annotations to send", vim.log.levels.WARN)
    return
  end
  refresh_all()

  local instruction = acfg().default_instruction or ""
  local lines = { instruction, "", "── batch preview ──" }
  vim.list_extend(lines, vim.split(build_message(state.items, nil), "\n"))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_name(buf, "herdr-ask://send-" .. buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines + 1, math.max(6, vim.o.lines - 6))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Send batch ▸ <CR> send · <Esc> cancel ",
  })
  vim.wo[win].wrap = true
  vim.cmd("startinsert!")

  local done = false
  local function finish(send)
    if done then
      return
    end
    done = true
    local instr = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if send then
      deliver(state.items, global, instr, function(n)
        if acfg().clear_after_send ~= false then
          A.clear()
        end
        notify(("sent %d annotation%s"):format(n, n == 1 and "" or "s"))
      end)
    end
  end

  vim.keymap.set({ "n", "i" }, "<CR>", function() finish(true) end, { buffer = buf })
  vim.keymap.set("n", "<Esc>", function() finish(false) end, { buffer = buf })
  vim.keymap.set("n", "q", function() finish(false) end, { buffer = buf })
end

-- Send a single annotation to the current workspace, then drop it from the batch.
local function send_one(it)
  refresh_all()
  deliver({ it }, false, acfg().default_instruction or "", function()
    remove_item(it)
    notify(("sent 1 annotation (%d pending)"):format(#state.items))
  end)
end

local function jump_to(it)
  vim.cmd.edit(vim.fn.fnameescape(it.relpath))
  local last = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, { math.min(it.lnum, last), 0 })
end

local function item_actions(it)
  local actions = { "Jump to code", "Edit note", "Send now", "Remove", "Cancel" }
  vim.ui.select(actions, { prompt = "Annotation" }, function(choice)
    if choice == "Jump to code" then
      jump_to(it)
    elseif choice == "Send now" then
      send_one(it)
    elseif choice == "Edit note" then
      edit_note(it.note, function(note)
        if note and vim.trim(note) ~= "" then
          it.note = note
          if it._buf and vim.api.nvim_buf_is_loaded(it._buf) then
            unmark(it)
            mark_item(it._buf, it)
          end
          save()
        end
      end)
    elseif choice == "Remove" then
      remove_item(it)
      notify(("removed (%d pending)"):format(#state.items))
    end
  end)
end

--- Open the batch menu: send (either scope), clear, or act on an annotation.
function A.menu()
  A.setup()
  refresh_all()
  if #state.items == 0 then
    notify("no annotations yet", vim.log.levels.WARN)
    return
  end
  local n = #state.items
  local entries = {
    { kind = "send", global = false, label = ("▸ Send batch — this workspace (%d)"):format(n) },
    { kind = "send", global = true, label = ("▸ Send batch — any pane (%d)"):format(n) },
    { kind = "clear", label = "▸ Clear batch" },
  }
  for _, it in ipairs(state.items) do
    entries[#entries + 1] = {
      kind = "item",
      item = it,
      label = ("%s %s — %s"):format(it.relpath, range_str(it.lnum, it.end_lnum), vim.split(it.note, "\n")[1]),
    }
  end
  vim.ui.select(entries, {
    prompt = ("herdr-ask (%d pending)"):format(n),
    format_item = function(e)
      return e.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    if choice.kind == "send" then
      A.send(choice.global)
    elseif choice.kind == "clear" then
      vim.ui.select({ "Yes", "No" }, { prompt = "Clear all annotations?" }, function(yn)
        if yn == "Yes" then
          A.clear()
          notify("cleared")
        end
      end)
    elseif choice.kind == "item" then
      item_actions(choice.item)
    end
  end)
end

-- Read-only view for :checkhealth.
function A.info()
  return { path = state.path or resolve_path(), count = #state.items }
end

return A
