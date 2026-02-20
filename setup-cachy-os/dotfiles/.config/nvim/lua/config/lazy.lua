-- Bootstrap lazy.nvim
-- https://lazy.folke.io/installation

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local repo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
        "git", "clone", "--filter=blob:none", "--branch=stable", repo, lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "Warn" },
            { "\nPress any key to continue...", "" },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- Leader keys must be set before lazy loads plugins
vim.g.mapleader      = " "
vim.g.maplocalleader = "\\"

require("lazy").setup({
    spec = {
        -- Load the LazyVim distribution with its default plugins
        { "LazyVim/LazyVim", import = "lazyvim.plugins" },

        -- Language extras — uncomment what you need.
        -- Full list: https://www.lazyvim.org/extras
        { import = "lazyvim.plugins.extras.lang.go" },
        { import = "lazyvim.plugins.extras.lang.rust" },
        { import = "lazyvim.plugins.extras.lang.python" },
        { import = "lazyvim.plugins.extras.lang.typescript" },
        { import = "lazyvim.plugins.extras.lang.json" },
        { import = "lazyvim.plugins.extras.lang.yaml" },
        { import = "lazyvim.plugins.extras.lang.docker" },
        -- { import = "lazyvim.plugins.extras.lang.java" },   -- heavyweight, opt-in
        -- { import = "lazyvim.plugins.extras.lang.clangd" }, -- C/C++

        -- Tool extras
        { import = "lazyvim.plugins.extras.editor.telescope" },

        -- Your own plugins / overrides (lua/plugins/*.lua)
        { import = "plugins" },
    },
    defaults = {
        lazy    = false,
        version = false, -- always use latest git commit
    },
    install = {
        -- LazyVim will try these colorschemes during install
        colorscheme = { "catppuccin", "tokyonight", "habamax" },
    },
    checker = {
        enabled = true,  -- check for plugin updates
        notify  = false, -- don't pop up a notification every startup
    },
    performance = {
        rtp = {
            disabled_plugins = {
                "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
            },
        },
    },
})
