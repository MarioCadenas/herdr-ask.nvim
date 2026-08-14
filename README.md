# herdr-ask.nvim

Send a Neovim visual selection to a [Herdr](https://herdr.dev)-managed **agent
pane** — claude, codex, cursor, gemini, or any agent Herdr recognizes — over the
`herdr` CLI. Ask a question about the code, or drop a file reference into an
agent's input to build a prompt around.

Two actions, each scoped to the **current workspace** or **any pane**:

- **Ask** — prompt for a question, then *submit* `question + @ref + the selected
  code` as one turn to a chosen agent.
- **Ref** — *stage* just the `@file#L…` reference into a chosen agent's input
  (no submit), so you type your own prompt around it.

When there's a single candidate the target is chosen automatically; otherwise you
pick from a list. It's transport-only (`herdr agent prompt` / `pane send-text`),
so it works with **any** agent kind and needs no IDE/WebSocket connection.

## Requirements

- Neovim **≥ 0.10** (uses `vim.system`)
- [Herdr](https://herdr.dev) with the `herdr` binary on `PATH`
- Neovim must be **running inside a Herdr pane** (so `HERDR_ENV` /
  `HERDR_WORKSPACE_ID` are set)

Run `:checkhealth herdr-ask` to verify.

## Install

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "MarioCadenas/herdr-ask.nvim",
  event = "VeryLazy",
  opts = {}, -- see Configuration; {} ships the default keymaps
}
```

## Default keymaps (visual mode)

| Key          | Action | Scope             |
| ------------ | ------ | ----------------- |
| `<leader>ai` | Ask    | current workspace |
| `<leader>aI` | Ask    | any pane          |
| `<leader>ar` | Ref    | current workspace |
| `<leader>aR` | Ref    | any pane          |

## Configuration

Defaults:

```lua
require("herdr-ask").setup({
  herdr_bin = "herdr",       -- path to the herdr binary
  focus_after_send = true,   -- focus the target pane after sending
  agent_kinds = nil,         -- e.g. { "claude", "codex" }; nil = any kind
  prompt = "Ask agent ▸ ",   -- ask input prompt
  -- reference string; `range` is "L4" or "L4-10"
  format_ref = function(relpath, range)
    return ("@%s#%s"):format(relpath, range)
  end,
  -- message submitted by Ask
  format_message = function(question, ref, filetype, code)
    return ("%s\n\n%s\n```%s\n%s\n```"):format(question, ref, filetype, code)
  end,
  keymaps = {
    ask = "<leader>ai",
    ask_global = "<leader>aI",
    ref = "<leader>ar",
    ref_global = "<leader>aR",
  },
})
```

Remap one, drop one, or define none:

```lua
opts = { keymaps = { ask = "<leader>ca" } }        -- remap Ask
opts = { keymaps = { ref = false, ref_global = false } } -- drop the Ref maps
opts = { keymaps = false }                         -- no keymaps; map it yourself:
--   vim.keymap.set("v", "<leader>ca", function() require("herdr-ask").ask({ global = false }) end)
```

## Commands

Work without `setup()`; `!` targets any pane.

- `:'<,'>HerdrAsk` / `:'<,'>HerdrAsk!`
- `:'<,'>HerdrRef` / `:'<,'>HerdrRef!`

## How it works

`herdr agent list` → filter to the scope (current workspace or all) → auto-pick
the lone candidate or `vim.ui.select` → `herdr agent prompt <pane>` (Ask) or
`herdr pane send-text <pane>` (Ref) → `herdr agent focus <pane>`.

The selection is captured as **whole lines** from the `'<,'>` marks. When a
mapping fires through a `<leader>`/which-key sequence the live visual state is
unreliable, but the line marks stay correct — so charwise/blockwise column
precision is intentionally traded for robust whole-line capture.

## Pairs well with

For the native at-mention path (send a selection to the *IDE-connected* claude
over the WebSocket protocol), run [`coder/claudecode.nvim`](https://github.com/coder/claudecode.nvim)
with `terminal.provider = "none"` and connect the Herdr claude with `/ide`.
`herdr-ask` is complementary and independent — it never touches the IDE protocol.

## License

MIT
