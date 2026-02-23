-- Seamless navigation between nvim splits and zellij panes
return {
  "swaits/zellij-nav.nvim",
  lazy = true,
  event = "VeryLazy",
  keys = {
    { "<C-h>", "<cmd>ZellijNavigateLeftTab<cr>", desc = "Navigate Left (Zellij/nvim)" },
    { "<C-j>", "<cmd>ZellijNavigateDown<cr>", desc = "Navigate Down (Zellij/nvim)" },
    { "<C-k>", "<cmd>ZellijNavigateUp<cr>", desc = "Navigate Up (Zellij/nvim)" },
    { "<C-l>", "<cmd>ZellijNavigateRightTab<cr>", desc = "Navigate Right (Zellij/nvim)" },
  },
  opts = {},
}
