-- Options loaded before lazy.nvim starts.
-- LazyVim's defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Only add overrides here — don't re-set what LazyVim already handles.

local opt = vim.opt

-- Use 4-space indentation (LazyVim defaults to 2)
opt.tabstop     = 4
opt.shiftwidth  = 4
opt.softtabstop = 4

-- Keep more context visible when scrolling
opt.scrolloff   = 8

-- Persistent undo across sessions
opt.undofile    = true

-- Disable line wrapping
opt.wrap        = false

-- Font hint for GUI frontends (Neovide, etc.)
-- vim.o.guifont = "JetBrainsMonoNL Nerd Font Mono:h13"
