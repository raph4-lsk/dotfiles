return {
  "kiyoon/python-import.nvim",
  build = "uv tool install . --force --reinstall",
  keys = {
    {
      "<leader>i",
      function()
        require("python_import.api").add_import_current_word_and_move_cursor()
      end,
      mode = "n",
      ft = "python",
      desc = "Add python import",
    },
    {
      "<leader>i",
      function()
        require("python_import.api").add_import_current_selection_and_move_cursor()
      end,
      mode = "x",
      ft = "python",
      desc = "Add python import",
    },
  },
  opts = {},
}
