local function toggle_diff()
  local closed = false
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    if name:match("^gitsigns://") then
      vim.api.nvim_win_close(win, true)
      closed = true
    end
  end

  if closed then
    vim.cmd("diffoff!")
  else
    require("gitsigns").diffthis()
  end
end

local function toggle_preview()
  local namespace = vim.api.nvim_create_namespace("gitsigns_preview_inline")
  local marks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { limit = 1 })
  if #marks > 0 then
    vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
  else
    require("gitsigns").preview_hunk_inline()
  end
end

local function toggle_line_blame()
  require("gitsigns").toggle_current_line_blame()
end

return {
  "lewis6991/gitsigns.nvim",
  opts = {
    attach_to_untracked = true,
    current_line_blame = true,
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "eol",
      delay = 300,
      ignore_whitespace = false,
    },
    current_line_blame_formatter = "  <author>, <author_time:%R> · <summary>",
  },
  keys = {
    {
      "<leader>uB",
      toggle_line_blame,
      desc = "Toggle inline git blame",
    },
    {
      "gh",
      toggle_preview,
      desc = "Toggle git diff inline",
    },
    {
      "gp",
      toggle_diff,
      desc = "Toggle git diff",
    },
  },
}
