local M = {}

function M.check()
  vim.health.start("herdr-ask")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim >= 0.10")
  else
    vim.health.error("Neovim >= 0.10 required (uses vim.system)")
  end

  local bin = require("herdr-ask").config.herdr_bin
  if vim.fn.executable(bin) == 1 then
    vim.health.ok(("`%s` found on PATH"):format(bin))
  else
    vim.health.error(("`%s` not found on PATH"):format(bin))
  end

  if vim.env.HERDR_ENV == "1" then
    vim.health.ok("running inside a Herdr pane (HERDR_ENV=1)")
  else
    vim.health.warn("not inside a Herdr pane (HERDR_ENV unset); mappings error until nvim runs inside Herdr")
  end

  local info = require("herdr-ask.annotations").info()
  vim.health.ok(("annotations: %d pending · %s"):format(info.count, info.path))
end

return M
