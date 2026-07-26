# tmux-send-keys.nvim

A Neovim plugin to send text to adjacent tmux panes via a floating prompt buffer. Useful for interacting with CLI coding agents (Claude Code, Codex, etc.).

## Requirements

- Neovim 0.7+
- tmux

## Installation

### lazy.nvim

```lua
{
  "KEY60228/tmux-send-keys.nvim",
  config = function()
    require("tmux-send-keys").setup()
  end,
}
```

## Usage

1. Press `<leader>tp` to open the floating prompt buffer
   - In Visual mode, selected text is pre-filled into the prompt
2. Edit the text as needed (supports `@path` completion with Tab)
3. Press `<C-h/j/k/l>` to send to the adjacent pane in that direction

### Default Keymaps

**Global:**

| Key | Mode | Action |
|-----|------|--------|
| `<leader>tp` | Normal | Open prompt buffer |
| `<leader>tp` | Visual | Open prompt with selection |

**Inside Prompt Buffer:**

| Key | Action |
|-----|--------|
| `<C-k>` | Send to pane above |
| `<C-j>` | Send to pane below |
| `<C-h>` | Send to pane on the left |
| `<C-l>` | Send to pane on the right |
| `<Esc>` | Stop prompt (saves draft) |
| `q` | Stop prompt (saves draft) |
| `<Tab>` | Complete `@path` |

### Commands

- `:TmuxPrompt` - Open prompt buffer
- `:TmuxPromptClose` - Close prompt buffer

Inside the prompt buffer:
- `:TmuxSendUp` - Send to pane above
- `:TmuxSendDown` - Send to pane below
- `:TmuxSendLeft` - Send to pane on the left
- `:TmuxSendRight` - Send to pane on the right

Draft management:
- `:TmuxDraftClear` - Discard the saved draft

## Draft (stop & resume)

The prompt buffer keeps its content as a **draft**. Closing the prompt
(`<Esc>` / `q` / `:TmuxPromptClose`) *stops* it without losing the text — reopen
with `<leader>tp` to *resume* exactly where you left off.

Only the **last draft** is kept:

1. Write a draft, press `<Esc>` to stop (the draft is saved)
2. Press `<leader>tp` later to resume it
3. Run `:TmuxDraftClear` to start fresh

> The draft is held **in memory** for the current Neovim instance. A successful
> send clears it (configurable via `draft.clear_on_send`), and the draft is not
> persisted across Neovim restarts.

## Configuration

```lua
require("tmux-send-keys").setup({
  -- Global keymaps
  keymaps = {
    open_prompt = "<leader>tp",  -- Set to false to disable
  },
  -- Keymaps inside the prompt buffer
  prompt_keymaps = {
    send_up = "<C-k>",
    send_down = "<C-j>",
    send_left = "<C-h>",
    send_right = "<C-l>",
    close = "<Esc>",
    close_q = "q",
  },
  -- Draft behavior
  draft = {
    -- Keep the last draft when closing so it can be resumed later
    persist = true,
    -- Clear the draft after a successful send
    clear_on_send = true,
  },
  -- Floating window settings
  float = {
    width = 0.8,        -- 80% of editor width
    height = 0.4,       -- 40% of editor height
    border = "rounded", -- none, single, double, rounded, solid, shadow
    title = " Tmux Send Keys ",
  },
  -- Focus target pane after sending (default: true)
  focus_after_send = true,
})
```

## Features

- **Floating prompt buffer** - Edit text before sending with full Neovim editing capabilities
- **Visual selection support** - Selected text is automatically loaded into the prompt
- **`@path` completion** - Type `@` followed by a path and press `<Tab>` to autocomplete file/directory names
- **Directional sending** - Send to any adjacent tmux pane (up/down/left/right)
- **Draft (stop & resume)** - Closing keeps the last draft so you can resume it later
- **Auto-focus** - Optionally focus the target pane after sending

## Example Usage

```
+------------------+------------------+
|                  |                  |
|    Neovim        |   Claude Code    |
|                  |                  |
|  (edit code)     |   (CLI agent)    |
|                  |                  |
+------------------+------------------+

1. Select code in Neovim
2. Press <leader>tp to open the prompt with selection
3. Edit the prompt if needed
4. Press <C-l> to send to the right pane
5. Text is sent and focus moves to the Claude Code pane
```

## License

MIT
