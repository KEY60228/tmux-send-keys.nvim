-- Prevent loading twice
if vim.g.loaded_tmux_send_keys then
  return
end
vim.g.loaded_tmux_send_keys = true

-- Global commands
vim.api.nvim_create_user_command("TmuxPrompt", function()
  require("tmux-send-keys").open_prompt()
end, { desc = "Open tmux send prompt" })

vim.api.nvim_create_user_command("TmuxPromptClose", function()
  require("tmux-send-keys").close_prompt()
end, { desc = "Close tmux send prompt" })
