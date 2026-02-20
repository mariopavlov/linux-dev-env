-- Keymaps loaded on the VeryLazy event.
-- LazyVim's defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- Save with Ctrl+S (works in normal and insert mode)
map({ "n", "i" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })

-- Better escape from insert mode
map("i", "jk", "<Esc>", { desc = "Escape insert mode" })

-- Move selected lines up/down in visual mode
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Keep cursor centred when jumping search results / half-pages
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centred)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centred)" })
map("n", "n",     "nzzzv",   { desc = "Next search result (centred)" })
map("n", "N",     "Nzzzv",   { desc = "Prev search result (centred)" })

-- Paste without overwriting the unnamed register
map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })

-- System clipboard
map({ "n", "v" }, "<leader>y", [["+y]],  { desc = "Yank to system clipboard" })
map("n",          "<leader>Y", [["+Y]],  { desc = "Yank line to system clipboard" })
