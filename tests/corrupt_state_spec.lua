local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local ha = require("herdr-ask")
H.project({ ["f.lua"] = { "a", "b", "c" } })

-- Write corrupt state before setup/load (same path algorithm as the plugin).
local state_dir = vim.fn.stdpath("state") .. "/herdr-ask"
vim.fn.mkdir(state_dir, "p")
local root = vim.fs.root(vim.uv.cwd(), ".git") or vim.uv.cwd()
local path = state_dir .. "/" .. vim.fn.sha256(root) .. ".json"
vim.fn.writefile({
  vim.json.encode({
    items = {
      { relpath = "f.lua", lnum = 0, end_lnum = 0, note = "zero", filetype = "lua" },
      { relpath = "f.lua", lnum = nil, end_lnum = 2, note = "nilnum", filetype = "lua" },
      { relpath = "f.lua", lnum = 1, end_lnum = 1, note = nil, filetype = "lua" },
      { relpath = "f.lua", lnum = 2, end_lnum = 3, note = "keep me", filetype = "lua" },
      "not-a-table",
    },
  }),
}, path)

ha.setup({ focus_after_send = false })
local A = require("herdr-ask.annotations")

local ok_edit = pcall(vim.cmd, "edit f.lua")
H.ok(ok_edit, "BufReadPost place_marks must tolerate corrupt items")

H.eq(A.info().count, 1, "only valid items kept from corrupt state")
H.eq(A.info().path, path, "state path matches")

vim.ui.select = function(_, _, cb)
  cb(nil)
end
local ok_menu = pcall(A.menu)
H.ok(ok_menu, "menu opens with sanitized items")
H.pass()
