return {
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      transparent = true,
      on_highlights = function(hl, c)
        hl.DiagnosticUnnecessary = { undercurl = true, sp = c.dark3 }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight-night",
    },
  },
}
