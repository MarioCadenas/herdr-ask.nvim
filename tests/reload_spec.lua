local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
local ha = require("herdr-ask")
H.project({ ["x.lua"] = { "alpha", "beta", "gamma", "delta" } })

-- Pre-write a persisted batch at the path setup() will resolve. Use vim.uv.cwd()
-- (not the tempname) so it matches project_root() after symlink resolution.
local cwd = vim.uv.cwd()
local root = vim.fs.root(cwd, ".git") or cwd
local sdir = vim.fn.stdpath("state") .. "/herdr-ask"
vim.fn.mkdir(sdir, "p")
local path = sdir .. "/" .. vim.fn.sha256(root) .. ".json"
vim.fn.writefile({ vim.json.encode({ items = { { relpath = "x.lua", lnum = 2, end_lnum = 3, note = "persisted" } } }) }, path)

ha.setup({}) -- triggers load()
local A = require("herdr-ask.annotations")
H.eq(A.info().count, 1, "loaded batch from disk")

vim.cmd("edit x.lua")
local ns = vim.api.nvim_get_namespaces()["herdr-ask-annotations"]
local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
H.eq(#marks, 1, "mark placed on reload")
H.eq(marks[1][2], 1, "mark at row 1 (line 2)")

local stale = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_delete(stale, { force = true })
local au = vim.api.nvim_get_autocmds({ group = "herdr-ask-annotations", event = "BufReadPost" })[1]
H.ok(au and pcall(au.callback, { buf = stale }), "BufReadPost tolerates invalid buf")
H.pass()
