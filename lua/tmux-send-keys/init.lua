local M = {}

M.config = {
  -- Default keymaps to open prompt buffer
  keymaps = {
    open_prompt = "<leader>tp",
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
  -- Floating window options
  float = {
    width = 0.8,   -- 80% of editor width
    height = 0.4,  -- 40% of editor height
    border = "rounded",
    title = " Tmux Send Keys ",
  },
  -- Focus the target pane after sending
  focus_after_send = true,
}

-- State
local state = {
  buf = nil,
  win = nil,
}

-- Custom completion function for @path
local function complete_at_path(findstart, base)
  if findstart == 1 then
    -- Find the start of the word (look for @)
    local line = vim.fn.getline(".")
    local col = vim.fn.col(".") - 1

    while col > 0 do
      local char = line:sub(col, col)
      if char == "@" then
        return col - 1  -- Return 0-indexed position before @
      elseif char:match("%s") then
        break
      end
      col = col - 1
    end
    return -3  -- No @ found, use default completion
  else
    -- Return matches
    if not base:match("^@") then
      return {}
    end

    local pattern = base:sub(2)  -- Remove @ prefix
    local cwd = vim.fn.getcwd()
    local matches = {}

    -- Use glob to find files/directories
    local glob_pattern = cwd .. "/" .. pattern .. "*"
    local files = vim.fn.glob(glob_pattern, false, true)

    for _, file in ipairs(files) do
      local relative = file:sub(#cwd + 2)  -- Remove cwd prefix and /
      local is_dir = vim.fn.isdirectory(file) == 1
      table.insert(matches, {
        word = "@" .. relative .. (is_dir and "/" or ""),
        abbr = relative .. (is_dir and "/" or ""),
        kind = is_dir and "[Dir]" or "[File]",
      })
    end

    return matches
  end
end

-- Expose for completefunc
_G._tmux_send_keys_complete = complete_at_path

-- Check if running inside tmux
local function is_tmux()
  return vim.env.TMUX ~= nil
end

-- Get visually selected text
local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  local lines = vim.fn.getline(start_line, end_line)

  if #lines == 0 then
    return {}
  end

  local mode = vim.fn.visualmode()

  if mode == "v" then
    if #lines == 1 then
      lines[1] = string.sub(lines[1], start_col, end_col)
    else
      lines[1] = string.sub(lines[1], start_col)
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
  elseif mode == "\22" then
    local new_lines = {}
    for _, line in ipairs(lines) do
      table.insert(new_lines, string.sub(line, start_col, end_col))
    end
    lines = new_lines
  end

  return lines
end

-- Calculate floating window dimensions
local function calc_float_opts()
  local width = math.floor(vim.o.columns * M.config.float.width)
  local height = math.floor(vim.o.lines * M.config.float.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  return {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = M.config.float.border,
    title = M.config.float.title,
    title_pos = "center",
  }
end

-- Close the prompt buffer
local function close_prompt()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.win = nil
  state.buf = nil
end

-- Find pane in direction using position calculation
local function find_pane_in_direction(direction)
  -- Get current pane info
  local current_handle = io.popen("tmux display-message -p '#{pane_id} #{pane_top} #{pane_bottom} #{pane_left} #{pane_right}' 2>/dev/null")
  if not current_handle then return nil end
  local current_info = current_handle:read("*a")
  current_handle:close()
  if not current_info then return nil end
  current_info = current_info:gsub("%s+$", "")

  local cur_id, cur_top, cur_bottom, cur_left, cur_right = current_info:match("(%S+) (%d+) (%d+) (%d+) (%d+)")
  if not cur_id then return nil end
  cur_top, cur_bottom, cur_left, cur_right = tonumber(cur_top), tonumber(cur_bottom), tonumber(cur_left), tonumber(cur_right)

  -- Get all panes
  local panes_handle = io.popen("tmux list-panes -F '#{pane_id} #{pane_top} #{pane_bottom} #{pane_left} #{pane_right}' 2>/dev/null")
  if not panes_handle then return nil end
  local panes_output = panes_handle:read("*a")
  panes_handle:close()
  if not panes_output then return nil end

  local best_pane = nil
  local best_distance = math.huge

  for line in panes_output:gmatch("[^\n]+") do
    local pane_id, top, bottom, left, right = line:match("(%S+) (%d+) (%d+) (%d+) (%d+)")
    if pane_id and pane_id ~= cur_id then
      top, bottom, left, right = tonumber(top), tonumber(bottom), tonumber(left), tonumber(right)

      local is_valid = false
      local distance = math.huge

      if direction == "up" then
        -- Pane is above: its bottom edge is at or above our top edge, and horizontally overlaps
        if bottom <= cur_top and not (right < cur_left or left > cur_right) then
          is_valid = true
          distance = cur_top - bottom
        end
      elseif direction == "down" then
        -- Pane is below: its top edge is at or below our bottom edge, and horizontally overlaps
        if top >= cur_bottom and not (right < cur_left or left > cur_right) then
          is_valid = true
          distance = top - cur_bottom
        end
      elseif direction == "left" then
        -- Pane is left: its right edge is at or left of our left edge, and vertically overlaps
        if right <= cur_left and not (bottom < cur_top or top > cur_bottom) then
          is_valid = true
          distance = cur_left - right
        end
      elseif direction == "right" then
        -- Pane is right: its left edge is at or right of our right edge, and vertically overlaps
        if left >= cur_right and not (bottom < cur_top or top > cur_bottom) then
          is_valid = true
          distance = left - cur_right
        end
      end

      if is_valid and distance < best_distance then
        best_distance = distance
        best_pane = pane_id
      end
    end
  end

  return best_pane
end

-- Send buffer content to tmux pane
local function send_to_pane(direction)
  if not is_tmux() then
    vim.notify("Not running inside tmux", vim.log.levels.ERROR)
    return
  end

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    vim.notify("No prompt buffer open", vim.log.levels.ERROR)
    return
  end

  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local text = table.concat(lines, "\n")

  if text:gsub("%s+", "") == "" then
    vim.notify("Cannot send empty buffer", vim.log.levels.WARN)
    return
  end

  -- Find target pane by position
  local pane_id = find_pane_in_direction(direction)
  if not pane_id then
    vim.notify("No pane found in direction: " .. direction, vim.log.levels.WARN)
    return
  end

  -- Use temp file for reliable text transfer
  local tmpfile = vim.fn.tempname()
  local f = io.open(tmpfile, "w")
  if not f then
    vim.notify("Failed to create temp file", vim.log.levels.ERROR)
    return
  end

  local write_ok, write_err = f:write(text)
  f:close()

  if not write_ok then
    os.remove(tmpfile)
    vim.notify("Failed to write temp file: " .. tostring(write_err), vim.log.levels.ERROR)
    return
  end

  local load_cmd = "tmux load-buffer " .. vim.fn.shellescape(tmpfile)
  local paste_cmd = "tmux paste-buffer -t " .. vim.fn.shellescape(pane_id)

  local ok, result = pcall(os.execute, load_cmd .. " && " .. paste_cmd)
  os.remove(tmpfile)  -- Always clean up temp file

  if not ok or result ~= 0 then
    vim.notify("Failed to send text to tmux pane", vim.log.levels.ERROR)
    return
  end

  -- Close buffer first
  close_prompt()

  -- Focus target pane if configured
  if M.config.focus_after_send then
    os.execute("tmux select-pane -t " .. vim.fn.shellescape(pane_id))
  end

  vim.notify(string.format("Sent to %s pane", direction), vim.log.levels.INFO)
end

-- Setup keymaps for the prompt buffer
local function setup_buffer_keymaps(buf)
  local km = M.config.prompt_keymaps

  -- Send keymaps
  if km.send_up then
    vim.keymap.set("n", km.send_up, function() send_to_pane("up") end, { buffer = buf, desc = "Send to pane above" })
  end
  if km.send_down then
    vim.keymap.set("n", km.send_down, function() send_to_pane("down") end, { buffer = buf, desc = "Send to pane below" })
  end
  if km.send_left then
    vim.keymap.set("n", km.send_left, function() send_to_pane("left") end, { buffer = buf, desc = "Send to pane left" })
  end
  if km.send_right then
    vim.keymap.set("n", km.send_right, function() send_to_pane("right") end, { buffer = buf, desc = "Send to pane right" })
  end

  -- Close keymaps
  if km.close then
    vim.keymap.set("n", km.close, close_prompt, { buffer = buf, desc = "Close prompt" })
  end
  if km.close_q then
    vim.keymap.set("n", km.close_q, close_prompt, { buffer = buf, desc = "Close prompt" })
  end

  -- Tab completion for @path
  vim.keymap.set("i", "<Tab>", function()
    local line = vim.fn.getline(".")
    local col = vim.fn.col(".")
    local before_cursor = line:sub(1, col - 1)
    if before_cursor:match("@[^%s]*$") then
      return "<C-x><C-u>"
    else
      return "<Tab>"
    end
  end, { buffer = buf, expr = true, desc = "Complete @path or insert tab" })

  -- Buffer-local commands
  vim.api.nvim_buf_create_user_command(buf, "TmuxSendUp", function() send_to_pane("up") end, {})
  vim.api.nvim_buf_create_user_command(buf, "TmuxSendDown", function() send_to_pane("down") end, {})
  vim.api.nvim_buf_create_user_command(buf, "TmuxSendLeft", function() send_to_pane("left") end, {})
  vim.api.nvim_buf_create_user_command(buf, "TmuxSendRight", function() send_to_pane("right") end, {})
end

-- Open the prompt buffer
function M.open_prompt(opts)
  opts = opts or {}

  -- Close existing if open
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    close_prompt()
  end

  -- Create buffer
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].filetype = "markdown"
  vim.bo[state.buf].completefunc = "v:lua._tmux_send_keys_complete"

  -- Set initial content if provided
  if opts.initial_lines and #opts.initial_lines > 0 then
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, opts.initial_lines)
  end

  -- Create floating window
  local float_opts = calc_float_opts()
  state.win = vim.api.nvim_open_win(state.buf, true, float_opts)

  -- Window options
  vim.wo[state.win].wrap = true
  vim.wo[state.win].linebreak = true

  -- Setup keymaps
  setup_buffer_keymaps(state.buf)

  -- Start in insert mode
  vim.cmd("startinsert")
end

-- Open prompt with visual selection
function M.open_prompt_with_selection()
  -- Exit visual mode first
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  local lines = get_visual_selection()
  M.open_prompt({ initial_lines = lines })
end

-- Setup keymaps
local function setup_global_keymaps()
  local km = M.config.keymaps

  if km.open_prompt then
    vim.keymap.set("n", km.open_prompt, M.open_prompt, { desc = "Open tmux send prompt" })
    vim.keymap.set("v", km.open_prompt, M.open_prompt_with_selection, { desc = "Open tmux send prompt with selection" })
  end
end

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  setup_global_keymaps()
end

-- Expose for commands
M.send_to_pane = send_to_pane
M.close_prompt = close_prompt

return M
