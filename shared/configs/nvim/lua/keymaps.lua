local map = vim.keymap.set

vim.g.mapleader = " "

-- Paneles
map("n", "<C-h>", "<C-w>h")
map("n", "<C-l>", "<C-w>l")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")

-- Edición visual
map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

-- Archivo
map("n", "<leader>w", ":w<CR>")
map("n", "<leader>q", ":q<CR>")

-- Splits
map("n", "<leader>sv", ":vsplit<CR>")
map("n", "<leader>sh", ":split<CR>")
map("n", "<leader>sx", "<C-w>q")
map("n", "<leader>se", "<C-w>=")

-- Redimensionar
map("n", "<C-Up>",    ":resize +2<CR>")
map("n", "<C-Down>",  ":resize -2<CR>")
map("n", "<C-Right>", ":vertical resize +2<CR>")
map("n", "<C-Left>",  ":vertical resize -2<CR>")

-- Buffers
map("n", "<leader>bn", ":bnext<CR>")
map("n", "<leader>bp", ":bprev<CR>")
map("n", "<leader>bd", function()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  if #bufs > 1 then vim.cmd("bp|bd #") else vim.cmd("bd") end
end)

map("n", "<Esc>", ":nohlsearch<CR>")

-- Telescope
map("n", "<leader>ff", ":Telescope find_files<CR>")
map("n", "<leader>fg", ":Telescope live_grep<CR>")
map("n", "<leader>fb", ":Telescope buffers<CR>")

-- Árbol de archivos
map("n", "<leader>e",  ":NvimTreeToggle<CR>")
map("n", "<leader>ef", ":NvimTreeFocus<CR>")

-- LazyGit
map("n", "<leader>gg", ":LazyGit<CR>")
