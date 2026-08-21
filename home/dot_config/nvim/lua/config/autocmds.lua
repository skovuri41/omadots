-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Fallback colorscheme if the Omarchy-theme symlink (lua/plugins/theme.lua,
-- pointing at ~/.local/state/omarchy/current/theme/neovim.lua) doesn't
-- resolve - e.g. right after a fresh chezmoi apply, before Omarchy's theme
-- daemon has run once. This file loads on VeryLazy, which is late enough
-- that colors_name is already set if the theme plugin succeeded, so this
-- only kicks in when it didn't.
if not vim.g.colors_name then
  pcall(vim.cmd.colorscheme, "tokyonight")
end
