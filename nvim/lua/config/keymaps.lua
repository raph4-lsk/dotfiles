-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Recenter after a jump: the match lands in the middle, not stuck at the bottom
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result (centered)" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Prev search result (centered)" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centered)" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centered)" })

-- Keep the selection after indenting, so it can be repeated
vim.keymap.set("v", "<", "<gv", { desc = "Indent left, keep selection" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right, keep selection" })

-- Paste over a selection without overwriting the clipboard
vim.keymap.set("v", "<leader>p", '"_dP', { desc = "Paste without losing the yank" })

-- Quit with a single <leader>q. LazyVim binds <leader>qq, which has to go first:
-- with both mapped, vim would wait 'timeoutlen' on every <leader>q to see
-- whether a second q follows. The session commands move to <leader>Q, in
-- lua/plugins/session.lua.
pcall(vim.keymap.del, "n", "<leader>qq")
vim.keymap.set("n", "<leader>q", "<cmd>qa<cr>", { desc = "Quit all" })

vim.keymap.set("n", "q", function()
  return vim.fn.reg_recording() ~= "" and "q" or "<cmd>qa<cr>"
end, { expr = true, desc = "Quit all" })
vim.keymap.set("n", "<leader>m", "q", { desc = "Record macro" })

-- Close the buffer with a single Q. Buffers are walked with H and L, so closing
-- one belongs on the same shift+letter row. Q's default is Ex mode, never used,
-- and autocmds.lua auto-saves, so a stray press costs nothing. <leader>bd still
-- works for the LazyVim muscle memory.
vim.keymap.set("n", "Q", function()
  Snacks.bufdelete()
end, { desc = "Close buffer" })

vim.keymap.set("n", "<M-BS>", '"_db', { desc = "Delete previous word" })
vim.keymap.set("i", "<M-BS>", "<C-w>", { desc = "Delete previous word" })
vim.keymap.set("n", "<M-d>", '"_dw', { desc = "Delete next word" })
vim.keymap.set("i", "<M-d>", '<C-o>"_dw', { desc = "Delete next word" })
vim.keymap.set({ "n", "x", "o" }, "<M-b>", "b", { desc = "Previous word" })
vim.keymap.set({ "n", "x", "o" }, "<M-f>", "w", { desc = "Next word" })
vim.keymap.set({ "n", "x", "o" }, "<M-{>", "{", { desc = "Previous paragraph" })
vim.keymap.set({ "n", "x", "o" }, "<M-}>", "}", { desc = "Next paragraph" })
