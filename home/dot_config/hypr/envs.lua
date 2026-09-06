-- XDG Base Directories, set explicitly here (added 2026-09-06) rather than
-- left for each app to assume its own default. `hl.env(...)` is Hyprland's
-- Lua-config equivalent of the classic `env = VAR,VALUE` hyprland.conf
-- directive (see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
-- and the real precedent already in this repo: monitors.lua's
-- `hl.env("GDK_SCALE", ...)` call). Grouping all four together here, up
-- front in the require() order below `hyprland.lua`, follows the standard
-- recommendation to set XDG vars before anything else Hyprland launches.
--
-- Why this exists alongside `dot_bash_exports`'s own `XDG_CONFIG_HOME`
-- export (added the same day, see CHEZMOI-GUIDE.md's XDG_CONFIG_HOME
-- section): that export only reaches bash-launched processes. Anything
-- Hyprland spawns *directly* - the app launcher, keybinding `exec`
-- commands, autostart entries, a GTK/Qt app that isn't going through a
-- bash shell at all - never sourced `dot_bash_exports` and so never saw
-- it. Setting the vars here, in Hyprland's own process environment, means
-- every child process Hyprland forks inherits them, bash-launched or not.
-- This is what resolves the "known limitation, not currently load-bearing"
-- previously flagged in `dot_bash_exports`'s own comment. The bash-level
-- export is kept too (harmless - setting the same value twice is a no-op),
-- since it's still the only one of the two that reaches a bash shell
-- opened outside Hyprland entirely (SSH into this machine, a bare TTY
-- login, cron).
--
-- Two things confirmed directly from Hyprland's own sources before writing
-- this, not assumed:
--
-- 1. `hl.env()` does NOT do shell-style `$VAR` expansion the way the
--    classic `env = VAR,VALUE` hyprland.conf directive does - confirmed
--    directly by Hyprland's maintainer (vaxry) on the official forum:
--    https://forum.hypr.land/t/lua-config-hl-env-doesn-t-do-parameter-expansion/1568
--    HyprLang (the old `.conf` format) has built-in `$VAR` expansion; Lua
--    has none. So this file resolves `$HOME` itself via `os.getenv("HOME")`
--    below, rather than passing the literal string "$HOME/.config" - which
--    would otherwise set XDG_CONFIG_HOME to four literal characters
--    ("$HOME") followed by "/.config", not an expanded path.
-- 2. `env` values only take effect on a *fresh* Hyprland session start
--    (log out/in, or a full compositor restart) - `hyprctl reload`
--    re-parses the rest of the config but does not re-apply already-set
--    env vars to the already-running compositor process. Confirmed via
--    https://github.com/hyprwm/Hyprland/issues/8403 (closed "not planned" -
--    this is intentional upstream behavior, not a bug to work around).
--    After editing this file, log out and back in (or reboot) rather than
--    expecting `hyprctl reload` alone to pick it up.

local home = os.getenv("HOME")

hl.env("XDG_CONFIG_HOME", home .. "/.config")
hl.env("XDG_CACHE_HOME", home .. "/.cache")
hl.env("XDG_DATA_HOME", home .. "/.local/share")
hl.env("XDG_STATE_HOME", home .. "/.local/state")
