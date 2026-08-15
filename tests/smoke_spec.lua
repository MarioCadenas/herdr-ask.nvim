local H = dofile(assert(os.getenv("HERDR_TEST_ROOT")) .. "/tests/helpers.lua")
require("herdr-ask").setup({})

local function has_desc(mode, desc)
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    if m.desc == desc then return true end
  end
  return false
end
H.ok(has_desc("v", "Annotate selection into batch"), "annotate keymap registered")
H.ok(has_desc("n", "Open annotations batch menu"), "menu keymap registered")

local cmds = vim.api.nvim_get_commands({})
H.ok(cmds.HerdrAnnotate ~= nil, "HerdrAnnotate command")
H.ok(cmds.HerdrAnnotations ~= nil, "HerdrAnnotations command")
H.ok(pcall(require("herdr-ask.health").check), "health.check runs clean")
H.ok(pcall(require("herdr-ask.annotations").menu), "empty menu is a no-op")
H.pass()
