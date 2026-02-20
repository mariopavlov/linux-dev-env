-- Additional Mason tools and treesitter parsers not covered by language extras

return {
  -- Extra Mason tools
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, {
        "stylua",
        "shellcheck",
        "shfmt",
      })
    end,
  },

  -- Extra treesitter parsers
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, {
        "bash",
        "diff",
        "html",
        "latex",
        "lua",
        "luadoc",
        "norg",
        "printf",
        "query",
        "regex",
        "vim",
        "vimdoc",
        "xml",
      })
    end,
  },
}
