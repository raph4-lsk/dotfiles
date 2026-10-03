local function toggle(flag)
  return function()
    local on = unpack(require("grug-far").get_instance(0):toggle_flags({ flag }))
    vim.notify(flag .. (on and " ON" or " OFF"))
  end
end

local function open()
  require("grug-far").open({ transient = true })
end

return {
  "MagicDuck/grug-far.nvim",
  keys = {
    { "<leader>sr", open, mode = { "n", "x" }, desc = "Search and Replace" },
  },
  opts = {
    windowCreationCommand = "topleft 70vsplit",
    prefills = { flags = "--ignore-case --fixed-strings" },
    openTargetWindow = { preferredLocation = "right" },
    keymaps = {
      replace = { n = "<M-a>", i = "<M-a>" },
      nextInput = { n = "<tab>", i = "<tab>" },
      prevInput = { n = "<s-tab>", i = "<s-tab>" },
    },
  },
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "grug-far",
      callback = function(ev)
        local map = function(lhs, flag)
          vim.keymap.set({ "n", "i" }, lhs, toggle(flag), { buffer = ev.buf })
        end
        map("<M-c>", "--ignore-case")
        map("<M-w>", "--word-regexp")
        map("<M-r>", "--fixed-strings")
      end,
    })
  end,
}
