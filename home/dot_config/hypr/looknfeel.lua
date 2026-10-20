-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
 hl.config({
   general = {
     -- No gaps between windows or borders.
     gaps_in = 10,
     gaps_out = 10,
     border_size = 2,
     -- Change to niri-like side-scrolling layout.
     layout = "scrolling",
   },
 })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
 hl.config({
   decoration = {
     -- Use round window corners.
     rounding = 8,
     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
     dim_inactive = true,
     dim_strength = 0.5,
   },
 })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })
hl.config({
    layout = {
        single_window_aspect_ratio = { 1, 1 },
        single_window_aspect_ratio_tolerance = 0.0
    },
    scrolling = {
        fullscreen_on_one_column = true,
        focus_fit_method = 0,
        column_width = 1,
    }
})

-- column_width above is this process-wide default (applies before any
-- monitor event has fired, e.g. the very first config load) - everything
-- below re-derives a better value per monitor at runtime.
--
-- scrolling:column_width is a single global fraction (0.1-1.0) of the
-- FOCUSED monitor's width, not a per-monitor setting - Hyprland has no
-- native override for it (confirmed against wiki.hypr.land's
-- scrolling-layout docs: only `direction` has a per-workspace rule,
-- column_width does not). So the standard way to get a different "feel"
-- on a laptop panel vs. a wider external monitor is reacting to monitor
-- focus/topology changes and re-applying hl.config() live.
--
-- NOTE on how this is applied: `hyprctl keyword scrolling:column_width
-- ...` does NOT work on this build ("keyword can't work with non-legacy
-- parsers. Use eval.") - this config is Lua-native (the "non-legacy"
-- parser), not the classic keyword-based one. Confirmed instead, live via
-- `hyprctl repl`, that hl.config() and hl.get_active_monitor() both work
-- when called from inside a plain Lua function at runtime, not just at
-- config-load time - same as this file's own window-history feature
-- (bindings.lua) already relies on for hl.dispatch() inside hl.on().
-- So this calls hl.config() directly, no shell-out/external script
-- needed.
--
-- Tune WIDE_THRESHOLD/WIDE_COLUMN_WIDTH below to taste. WIDE_THRESHOLD is
-- in logical (post-scale) pixels - the same units column_width's fraction
-- is measured against. 1600 safely separates this laptop panel (2880x1800
-- @ scale 2 -> 1440 logical) from any 1080p/1440p/wider external monitor
-- at scale 1; adjust if your actual external monitor's logical width
-- lands close to that line (check with `hyprctl monitors` while docked -
-- divide width by scale).
local WIDE_THRESHOLD = 1600
local WIDE_COLUMN_WIDTH = 0.65
local NARROW_COLUMN_WIDTH = 1.0

local function apply_column_width()
  local mon = hl.get_active_monitor()
  if not mon then return end

  local logical_width = mon.width / mon.scale
  local width = (logical_width > WIDE_THRESHOLD) and WIDE_COLUMN_WIDTH or NARROW_COLUMN_WIDTH
  hl.config({ scrolling = { column_width = width } })
end

-- monitor.focused: covers moving focus between an already-connected
-- laptop panel and external monitor (the "occasionally want both" case).
-- monitor.added/monitor.removed: covers docking/undocking even when focus
-- doesn't itself change (e.g. plugging in a second monitor while already
-- focused on the one that stays focused).
hl.on("monitor.focused", apply_column_width)
hl.on("monitor.added", apply_column_width)
hl.on("monitor.removed", apply_column_width)

