require("autoclose").setup({})

require("gruvbox").setup({
  terminal_colors = true,
  transparent_mode = true,
})
vim.cmd("colorscheme gruvbox")

-- fix for airline colors after neovim v0.11 upgrade
vim.cmd("highlight StatusLine cterm=NONE gui=NONE")
vim.cmd("highlight TabLine cterm=NONE gui=NONE")
vim.cmd("highlight WinBar cterm=NONE gui=NONE")
