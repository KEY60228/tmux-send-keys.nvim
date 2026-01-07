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
| `<Esc>` | Close prompt |
| `q` | Close prompt |
| `<Tab>` | Complete `@path` |

### Commands

- `:TmuxPrompt` - Open prompt buffer
- `:TmuxPromptClose` - Close prompt buffer

Inside the prompt buffer:
- `:TmuxSendUp` - Send to pane above
- `:TmuxSendDown` - Send to pane below
- `:TmuxSendLeft` - Send to pane on the left
- `:TmuxSendRight` - Send to pane on the right

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
