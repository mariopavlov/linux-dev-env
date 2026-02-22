-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Python: use pyright as LSP (alternatives: "basedpyright")
vim.g.lazyvim_python_lsp = "pyright"
vim.g.lazyvim_python_ruff = "ruff"

-- Python provider: point to dedicated venv with pynvim (created by install scripts)
vim.g.python3_host_prog = vim.fn.expand("~/.nvim-venv/bin/python")

-- Disable unused providers
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0

-- Use bash for shell commands (fish startup is slow due to SDKMAN init)
vim.opt.shell = "bash"
