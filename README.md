# herdr-ask.nvim

Send a Neovim visual selection to a [Herdr](https://herdr.dev)-managed **agent
pane** — claude, codex, cursor, gemini, or any agent Herdr recognizes — over the
`herdr` CLI. Ask a question about the code, or drop a file reference into an
agent's input to build a prompt around.

Two one-shot actions, each scoped to the **current workspace** or **any pane**:

- **Ask** — prompt for a question, then *submit* `question + @ref + the selected
  code` as one turn to a chosen agent.
- **Ref** — *stage* just the `@file#L…` reference into a chosen agent's input
  (no submit), so you type your own prompt around it.

When there's a single candidate the target is chosen automatically; otherwise you
pick from a list. It's transport-only (`herdr agent prompt` / `pane send-text`),
so it works with **any** agent kind and needs no IDE/WebSocket connection.

## Annotations (batch review)

Collect `@ref + note` pairs across one or many files, review them, then flush the
whole set to one agent as a single message — a lightweight way to hand an agent a
guided review.

- **Annotate** (`<leader>aa`, visual) — capture the selection's ref, then type a
  (multi-line) note in a scratch float; `:w` saves, `:q` cancels.
- **Menu** (`<leader>al`, normal) — a picker to **send** the batch (this
  workspace / any pane), **clear** it, or act on one annotation (jump / edit note
  / remove).

Annotated lines get a gutter sign and a dimmed end-of-line note. The pending
batch **persists per project** (git root, else cwd) under
`stdpath("state")/herdr-ask/`, so a half-built batch survives a restart. While a
buffer is open, ranges track your edits via extmarks and the saved positions
update on write.

On send you get an editable default instruction, then the batch goes out grouped
by file:

```
Review these annotations.

## src/db.lua
- @src/db.lua#L4-10 — leaks a connection under retry
- @src/db.lua#L30 — unchecked nil

## src/api.lua
- @src/api.lua#L88 — should this be awaited?
```

Set `annotations.include_code = true` to fence the (freshly re-read) code under
each bullet.

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

## Tutorial

Two ways to use it:

- **One-shot** — select code, send it right away (Ask/Ref).
- **Batch** — annotate code across files, then send the whole set at once.

### One-shot

| Do this | Result |
| ------- | ------ |
| Select lines → `<leader>ai`, type a question | Sends `question + @ref + code` to an agent |
| Select lines → `<leader>ar` | Drops `@file#Lx` into the agent's input to prompt around |

### Batch annotations

| Step | Do this | Result |
| ---- | ------- | ------ |
| 1 | Select lines → `<leader>aa` | Note float opens (`:w` save · `:q` cancel) |
| 2 | Type a note → `:w` | Gutter `●` + note shown; "1 pending" |
| 3 | Repeat across lines / files | Batch grows; persists across restarts |
| 4 | `<leader>al` → **Send batch — this workspace** | Editable instruction prompt |
| 5 | Press Enter | Grouped-by-file message sent to the agent; batch clears |

The `<leader>al` menu also **clears** the batch or, per annotation, lets you
**jump / edit note / remove**.

Capital variants (`<leader>aI` / `<leader>aR`) target **any pane** instead of
the current workspace. Full keymaps below.

## Default keymaps

| Key          | Mode   | Action           | Scope             |
| ------------ | ------ | ---------------- | ----------------- |
| `<leader>ai` | visual | Ask              | current workspace |
| `<leader>aI` | visual | Ask              | any pane          |
| `<leader>ar` | visual | Ref              | current workspace |
| `<leader>aR` | visual | Ref              | any pane          |
| `<leader>aa` | visual | Annotate         | — (into batch)    |
| `<leader>al` | normal | Annotations menu | send / clear / …  |

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
  annotations = {
    clear_after_send = true,   -- clear the batch after a successful send
    include_code = false,      -- fence the referenced code under each bullet
    signs = true,              -- gutter sign + end-of-line note on annotated lines
    default_instruction = "Review these annotations.",
  },
  keymaps = {
    ask = "<leader>ai",
    ask_global = "<leader>aI",
    ref = "<leader>ar",
    ref_global = "<leader>aR",
    annotate = "<leader>aa",   -- visual: annotate selection into the batch
    menu = "<leader>al",       -- normal: open the annotations menu
  },
})
```

Sign and note highlights link to `DiagnosticSignInfo` / `Comment` by default;
override `HerdrAskSign` / `HerdrAskVirtText` to restyle them.

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
- `:'<,'>HerdrAnnotate` — annotate the selection into the batch
- `:HerdrAnnotations` — open the annotations menu (send / clear / edit)

## How it works

`herdr agent list` → filter to the scope (current workspace or all) → auto-pick
the lone candidate or `vim.ui.select` → `herdr agent prompt <pane>` (Ask) or
`herdr pane send-text <pane>` (Ref) → `herdr agent focus <pane>`.

The selection is captured as **whole lines**. When the keymap callback still
runs in visual mode the `'<,'>` marks aren't set yet, so the live `v`/`.`
positions are used; once visual mode has ended (which-key, or a `:range`
command) it falls back to the marks. Either way charwise/blockwise column
precision is intentionally traded for robust whole-line capture.

## License

MIT
