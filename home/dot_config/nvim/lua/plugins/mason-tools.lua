-- mason.nvim ensure_installed - previously defined inside example.lua,
-- which starts with `if true then return {} end` and never executes, so
-- these were never actually being installed. Moved here so they're live.
return {
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "stylua",
        "shellcheck",
        "shfmt",
        "flake8",
      },
    },
  },
}
