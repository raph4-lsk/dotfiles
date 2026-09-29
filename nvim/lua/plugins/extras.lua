return {
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = { enabled = false },
      lazygit = {
        theme = {
          activeBorderColor = { fg = "Function", bold = true },
          searchingActiveBorderColor = { fg = "Function", bold = true },
        },
        win = {
          on_buf = function(self)
            vim.b[self.buf].terminal_color_2 = "#7aa2f7"
            vim.b[self.buf].terminal_color_10 = "#7aa2f7"
          end,
        },
      },
      picker = {
        sources = {
          explorer = {
            -- dotfiles stay visible: this is a config repo, .zshrc and
            -- .gitconfig are the files being edited, not noise
            hidden = true,
            -- but gitignored files stay out (.venv, node_modules, ...).
            -- `H` and `I` toggle either one live in the explorer.
            ignored = false,
            win = { list = { keys = { ["q"] = false, ["<esc>"] = false } } },
          },
        },
      },
    },
    keys = {
      {
        "<leader>e",
        function()
          local explorer = Snacks.picker.get({ source = "explorer" })[1]
          if explorer and not explorer.closed then
            explorer:close()
            return
          end

          local root = vim.fs.normalize(vim.fn.getcwd())
          local file = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
          local in_root = file:find(root .. "/", 1, true) == 1
          Snacks.explorer.open({
            cwd = root,
            on_show = function()
              if in_root then
                vim.schedule(function()
                  Snacks.explorer.reveal()
                end)
              end
            end,
          })
        end,
        desc = "Explorer (toggle)",
      },
    },
  },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
}
