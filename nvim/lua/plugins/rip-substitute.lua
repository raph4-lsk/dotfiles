return {
  "chrisgrieser/nvim-rip-substitute",
  keys = {
    {
      "<D-r>",
      function()
        require("rip-substitute").sub()
      end,
      mode = { "n", "x" },
      desc = "Substitute in buffer",
    },
  },
}
