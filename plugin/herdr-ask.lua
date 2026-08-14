if vim.g.loaded_herdr_ask then
  return
end
vim.g.loaded_herdr_ask = true

-- Commands work without calling setup(). `!` targets any pane; without it, the
-- current workspace. `range = true` so they operate on the visual selection.
vim.api.nvim_create_user_command("HerdrAsk", function(o)
  require("herdr-ask").ask({ global = o.bang })
end, { range = true, bang = true, desc = "Ask agent about selection (! = any pane)" })

vim.api.nvim_create_user_command("HerdrRef", function(o)
  require("herdr-ask").send_ref({ global = o.bang })
end, { range = true, bang = true, desc = "Send selection ref to agent input (! = any pane)" })
